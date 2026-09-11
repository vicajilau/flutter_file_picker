#if os(iOS)
import AVFoundation
import Flutter
import Foundation
import PhotosUI
import UniformTypeIdentifiers
import UIKit

final class IOSFilePickerHandler: NSObject,
    FlutterStreamHandler,
    PHPickerViewControllerDelegate,
    UIDocumentPickerDelegate,
    UIAdaptivePresentationControllerDelegate {

    private var result: FlutterResult?
    private var eventSink: FlutterEventSink?
    private var allowMultipleSelection = false
    private var loadDataToMemory = false
    private var assetRepresentationMode = PHPickerConfiguration.AssetRepresentationMode.automatic
    private var isDirectoryPicker = false
    private var isFileAndDirectoryPicker = false
    private var isSaveFile = false

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "clear" {
            _ = clearTemporaryFiles()
            result(nil)
            return
        }

        if self.result != nil {
            result(
                FlutterError(
                    code: "multiple_request",
                    message: "Cancelled by a second request",
                    details: nil))
            return
        }

        self.result = result

        if call.method == "dir" {
            isDirectoryPicker = true
            allowMultipleSelection = false
            presentDocumentPicker(
                contentTypes: [.folder],
                allowsMultipleSelection: false,
                asDirectoryPicker: true)
            return
        }

        guard let arguments = call.arguments as? [String: Any] else {
            self.result?(
                FlutterError(
                    code: "invalid_arguments",
                    message: "Expected method arguments as a map.",
                    details: nil))
            self.result = nil
            return
        }

        allowMultipleSelection =
            (arguments["allowMultipleSelection"] as? Bool) ?? false
        loadDataToMemory = (arguments["withData"] as? Bool) ?? false
        assetRepresentationMode = resolveAssetRepresentationMode(
            arguments["assetRepresentationMode"] as? String)

        switch call.method {
        case "any":
            presentDocumentPicker(
                contentTypes: [.item],
                allowsMultipleSelection: allowMultipleSelection,
                asDirectoryPicker: false)
        case "custom":
            let allowed = arguments["allowedExtensions"] as? [String] ?? []
            let contentTypes = resolveCustomContentTypes(allowed)
            if contentTypes.isEmpty {
                self.result?(
                    FlutterError(
                        code: "Unsupported file extension",
                        message:
                            "If you are providing extension filters make sure that you are only using FileType.custom and the extension are provided without the dot, (ie., jpg instead of .jpg).",
                        details: nil))
                self.result = nil
                return
            }
            presentDocumentPicker(
                contentTypes: contentTypes,
                allowsMultipleSelection: allowMultipleSelection,
                asDirectoryPicker: false)
        case "image", "video", "media":
            presentMediaPicker(
                type: call.method,
                allowsMultipleSelection: allowMultipleSelection)
        case "audio":
            presentDocumentPicker(
                contentTypes: [.audio],
                allowsMultipleSelection: allowMultipleSelection,
                asDirectoryPicker: false)
        case "save":
            saveFile(arguments)
        case "pickFileAndDirectoryPaths":
            let allowed = arguments["allowedExtensions"] as? [String] ?? []
            var contentTypes = allowed.isEmpty ? [.item] : resolveCustomContentTypes(allowed)
            if contentTypes.isEmpty {
                contentTypes = [.item]
            }
            contentTypes.append(.folder)
            isFileAndDirectoryPicker = true
            presentDocumentPicker(
                contentTypes: contentTypes,
                allowsMultipleSelection: true,
                asDirectoryPicker: false)
        default:
            result(FlutterMethodNotImplemented)
            self.result = nil
        }
    }

    func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)

        guard let currentResult = result else {
            return
        }

        if results.isEmpty {
            currentResult(nil)
            result = nil
            eventSink?(false)
            return
        }

        eventSink?(true)
        let group = DispatchGroup()
        var resolved = Array<[String: Any]?>(repeating: nil, count: results.count)
        let resolvedLock = NSLock()

        for (index, item) in results.enumerated() {
            group.enter()
            item.itemProvider.loadFileRepresentation(
                forTypeIdentifier: UTType.item.identifier
            ) { [weak self] url, _ in
                defer { group.leave() }
                guard let self, let sourceURL = url,
                      let copiedURL = self.copyToTemporaryDirectory(sourceURL)
                else {
                    return
                }
                if let fileInfo = self.makeFileInfo(from: copiedURL) {
                    resolvedLock.lock()
                    resolved[index] = fileInfo
                    resolvedLock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else {
                return
            }
            eventSink?(false)
            let orderedResolved = resolved.compactMap { $0 }
            currentResult(orderedResolved.isEmpty ? nil : orderedResolved)
            result = nil
        }
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        finishCurrentRequest(nil)
    }

    func presentationControllerWillDismiss(_: UIPresentationController) {
        finishCurrentRequest(nil)
    }

    func presentationControllerDidDismiss(
        _: UIPresentationController
    ) {
        finishCurrentRequest(nil)
    }

    func documentPicker(
        _: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let currentResult = result else {
            return
        }

        if isSaveFile {
            eventSink?(false)
            currentResult(urls.first?.path)
            result = nil
            isSaveFile = false
            return
        }

        if isDirectoryPicker {
            currentResult(urls.first?.path)
            result = nil
            isDirectoryPicker = false
            return
        }

        if isFileAndDirectoryPicker {
            currentResult(urls.map { $0.path })
            result = nil
            isFileAndDirectoryPicker = false
            return
        }

        var resolved: [[String: Any]] = []

        for sourceURL in urls {
            guard let copiedURL = copyToTemporaryDirectory(sourceURL),
                  let fileInfo = makeFileInfo(from: copiedURL)
            else {
                continue
            }
            resolved.append(fileInfo)
        }

        currentResult(resolved.isEmpty ? nil : resolved)
        result = nil
    }

    private func presentMediaPicker(type: String, allowsMultipleSelection: Bool) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.preferredAssetRepresentationMode = assetRepresentationMode
        configuration.selectionLimit = allowsMultipleSelection ? 0 : 1
        if #available(iOS 15.0, *) {
            configuration.selection = .ordered
        }

        switch type {
        case "image":
            configuration.filter = .images
        case "video":
            configuration.filter = .videos
        default:
            configuration.filter = .any(of: [.images, .videos])
        }

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.presentationController?.delegate = self
        topViewController()?.present(picker, animated: true)
    }

    private func presentDocumentPicker(
        contentTypes: [UTType],
        allowsMultipleSelection: Bool,
        asDirectoryPicker: Bool
    ) {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: !asDirectoryPicker)
        picker.delegate = self
        picker.presentationController?.delegate = self
        picker.allowsMultipleSelection = allowsMultipleSelection
        topViewController()?.present(picker, animated: true)
    }

    private func saveFile(_ arguments: [String: Any]) {
        isSaveFile = true
        let fileName = (arguments["fileName"] as? String) ?? ""
        let bytes = arguments["bytes"] as? FlutterStandardTypedData
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(fileName)

        eventSink?(true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: tempFile.path) {
                    try fileManager.removeItem(at: tempFile)
                }
                if let data = bytes?.data {
                    try data.write(to: tempFile, options: .atomic)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.eventSink?(false)
                    self.result?(
                        FlutterError(
                            code: "save_file_error",
                            message: error.localizedDescription,
                            details: nil))
                    self.result = nil
                    self.isSaveFile = false
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let picker = UIDocumentPickerViewController(
                    forExporting: [tempFile],
                    asCopy: true)
                picker.delegate = self
                picker.presentationController?.delegate = self
                self.topViewController()?.present(picker, animated: true)
            }
        }
    }

    private func resolveCustomContentTypes(_ allowedExtensions: [String]) -> [UTType] {
        allowedExtensions.compactMap { ext in
            let sanitized = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
            return UTType(filenameExtension: sanitized)
        }
    }

    private func resolveAssetRepresentationMode(
        _ value: String?
    ) -> PHPickerConfiguration.AssetRepresentationMode {
        switch value {
        case "current":
            return .current
        case "compatible":
            return .compatible
        default:
            return .automatic
        }
    }

    private func clearTemporaryFiles() -> Bool {
        let tmpDirectory = NSTemporaryDirectory()

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: tmpDirectory)
            for file in files {
                let filePath = (tmpDirectory as NSString).appendingPathComponent(file)
                try FileManager.default.removeItem(atPath: filePath)
            }
            return true
        } catch {
            return false
        }
    }

    private func topViewController() -> UIViewController? {
        let window = UIApplication.shared.windows.first { $0.isKeyWindow }
        var topController = window?.rootViewController

        while topController?.presentedViewController != nil {
            topController = topController?.presentedViewController
        }

        return topController
    }

    private func copyToTemporaryDirectory(_ sourceURL: URL) -> URL? {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return resolveActualFile(at: destinationURL)
        } catch {
            return nil
        }
    }

    /// Some `PHPickerResult` items (notably Live Photos, which iOS saves as
    /// `.pvt` packages) resolve to a *directory* rather than a regular file
    /// when loaded via `loadFileRepresentation(forTypeIdentifier: UTType.item...)`.
    /// Reading such a path as a file later fails with "Is a directory" (errno 21).
    /// When that happens, return the still image contained in the package
    /// instead of the package itself.
    private func resolveActualFile(at url: URL) -> URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        guard isDirectory.boolValue else {
            return url
        }

        let imageExtensions = ["jpg", "jpeg", "heic", "heif", "png"]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return contents.first { imageExtensions.contains($0.pathExtension.lowercased()) }
    }

    private func makeFileInfo(from fileURL: URL) -> [String: Any]? {
        do {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let size = values.fileSize ?? 0
            let data = loadDataToMemory ? try Data(contentsOf: fileURL) : nil

            var fileInfo: [String: Any] = [
                "path": fileURL.path,
                "identifier": fileURL.absoluteString,
                "name": fileURL.lastPathComponent,
                "size": size,
            ]

            if let data {
                fileInfo["bytes"] = FlutterStandardTypedData(bytes: data)
            }

            return fileInfo
        } catch {
            return nil
        }
    }

    private func finishCurrentRequest(_ value: Any?) {
        guard let currentResult = result else {
            return
        }

        if isSaveFile {
            eventSink?(false)
            isSaveFile = false
        }

        isDirectoryPicker = false
        isFileAndDirectoryPicker = false
        result = nil
        currentResult(value)
    }
}
#endif
