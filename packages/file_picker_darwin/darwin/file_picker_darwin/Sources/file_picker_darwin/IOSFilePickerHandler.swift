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

    private weak var registrar: FlutterPluginRegistrar?

    private var result: FlutterResult?
    private var eventSink: FlutterEventSink?
    private var allowMultipleSelection = false
    private var assetRepresentationMode = PHPickerConfiguration.AssetRepresentationMode.automatic
    private var orderedSelection = true
    private var copyMedia = true
    private var isDirectoryPicker = false
    private var isFileAndDirectoryPicker = false
    private var isSaveFile = false
    private let loader = PickLoader()

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

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
        assetRepresentationMode = resolveAssetRepresentationMode(
            arguments["assetRepresentationMode"] as? String)
        orderedSelection = (arguments["orderedSelection"] as? Bool) ?? true
        copyMedia = (arguments["copyMedia"] as? Bool) ?? true

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

        let preferringCompatible = assetRepresentationMode == .compatible
        // Without a copy, only the photo library identifier is returned, so
        // apps can open the original asset later without duplicating storage.
        if !copyMedia {
            let assets = results.compactMap {
                loader.assetInfo(for: $0, preferringCompatible: preferringCompatible)
            }
            complete(currentResult, pickedCount: results.count, loaded: assets)
            result = nil
            return
        }

        eventSink?(true)
        loader.loadMedia(results, preferringCompatible: preferringCompatible) {
            [weak self] loaded in
            guard let self else {
                return
            }
            eventSink?(false)
            complete(currentResult, pickedCount: results.count, loaded: loaded)
            result = nil
        }
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        finishCurrentRequest(nil)
    }

    func presentationControllerWillDismiss(
        _ presentationController: UIPresentationController
    ) {
        // UIKit calls this as soon as the user starts pulling the sheet down,
        // even if they let it spring back, so finishing right away would
        // report a cancellation while the picker is still open and drop the
        // later selection. Wait for the dismissal to end instead. A fast swipe
        // may never reach presentationControllerDidDismiss, so this still
        // finishes the request when the dismissal completes.
        guard
            let coordinator = presentationController.presentedViewController
                .transitionCoordinator
        else {
            finishCurrentRequest(nil)
            return
        }
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            if !context.isCancelled {
                self?.finishCurrentRequest(nil)
            }
        }
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

        let loaded = loader.loadDocuments(urls)
        complete(currentResult, pickedCount: urls.count, loaded: loaded)
        result = nil
    }

    /// Completes a pick of `pickedCount` items with the ones that could be
    /// `loaded`, following `PickOutcome`.
    private func complete(
        _ currentResult: FlutterResult,
        pickedCount: Int,
        loaded: [[String: Any]]
    ) {
        switch PickOutcome.resolve(pickedCount: pickedCount, loaded: loaded) {
        case .cancelled:
            currentResult(nil)
        case .loaded(let items):
            currentResult(items)
        case .loadFailed:
            currentResult(loadFailedError())
        }
    }

    /// The error for a pick where the user picked at least one item but none
    /// could be loaded, for example photos only stored in iCloud while the
    /// device is offline. Completing with `nil` instead would look like a
    /// cancellation to the app.
    private func loadFailedError() -> FlutterError {
        FlutterError(
            code: "load_failed",
            message: "None of the picked items could be loaded.",
            details: nil)
    }

    private func presentMediaPicker(type: String, allowsMultipleSelection: Bool) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.preferredAssetRepresentationMode = assetRepresentationMode
        configuration.selectionLimit = allowsMultipleSelection ? 0 : 1
        // Ordered selection keeps the results in the order the user picked
        // them, but disables swipe to select, so apps can opt out.
        if orderedSelection, #available(iOS 15.0, *) {
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
    
    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return self.registrar?.viewController?.view.window?.windowScene?.keyWindow
        } else {
            return self.registrar?.viewController?.view.window?.windowScene?.windows
                .filter({ $0.isKeyWindow }).first
        }
    }

    private func topViewController() -> UIViewController? {
        var topController = getKeyWindow()?.rootViewController

        while topController?.presentedViewController != nil {
            topController = topController?.presentedViewController
        }

        return topController
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

extension PHPickerResult: PickedMediaItem {
    var suggestedName: String? {
        itemProvider.suggestedName
    }

    var registeredTypeIdentifiers: [String] {
        itemProvider.registeredTypeIdentifiers
    }

    func loadFile(
        forTypeIdentifier typeIdentifier: String,
        completion: @escaping (URL?) -> Void
    ) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
            completion(url)
        }
    }
}
#endif
