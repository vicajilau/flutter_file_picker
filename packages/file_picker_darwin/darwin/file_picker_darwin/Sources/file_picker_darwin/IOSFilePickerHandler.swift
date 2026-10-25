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

        // Without a copy, only the photo library identifier is returned, so
        // apps can open the original asset later without duplicating storage.
        if !copyMedia {
            let assets = results.compactMap { makeAssetInfo(from: $0) }
            complete(currentResult, pickedCount: results.count, loaded: assets)
            result = nil
            return
        }

        eventSink?(true)
        let group = DispatchGroup()
        var resolved = Array<[String: Any]?>(repeating: nil, count: results.count)
        var failures: [LoadFailure] = []
        let resolvedLock = NSLock()

        for (index, item) in results.enumerated() {
            group.enter()
            // Loading the image or video itself, instead of any
            // representation, keeps a Live Photo from bringing its whole
            // bundle, paired video included (#2260).
            let typeIdentifier = MediaRepresentation.typeIdentifier(
                for: item.itemProvider.registeredTypeIdentifiers,
                preferringCompatible: assetRepresentationMode == .compatible)
            item.itemProvider.loadFileRepresentation(
                forTypeIdentifier: typeIdentifier
            ) { [weak self] url, error in
                defer { group.leave() }
                guard let self else {
                    return
                }
                do {
                    // Should `url` be missing without an error, still report a
                    // failure rather than nothing.
                    guard let sourceURL = url else {
                        throw error ?? CocoaError(.fileReadUnknown)
                    }
                    // iOS deletes this file when the handler returns, so it has
                    // to be copied.
                    let copiedURL = try self.storeInTemporaryDirectory(sourceURL, copying: true)
                    var fileInfo = try self.makeFileInfo(from: copiedURL)
                    if let assetIdentifier = item.assetIdentifier {
                        fileInfo["assetIdentifier"] = assetIdentifier
                    }
                    resolvedLock.lock()
                    resolved[index] = fileInfo
                    resolvedLock.unlock()
                } catch {
                    resolvedLock.lock()
                    failures.append(LoadFailure(index: index, error: error))
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
            complete(
                currentResult,
                pickedCount: results.count,
                loaded: orderedResolved,
                failures: failures)
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

        var resolved: [[String: Any]] = []
        var failures: [LoadFailure] = []

        for (index, sourceURL) in urls.enumerated() {
            do {
                // The picker opens with `asCopy`, so each file is already a
                // copy the app owns, and moving it avoids storing it twice
                // (#2261).
                let movedURL = try storeInTemporaryDirectory(sourceURL, copying: false)
                resolved.append(try makeFileInfo(from: movedURL))
            } catch {
                failures.append(LoadFailure(index: index, error: error))
            }
        }

        complete(currentResult, pickedCount: urls.count, loaded: resolved, failures: failures)
        result = nil
    }

    /// Completes a pick of `pickedCount` items with the ones that could be
    /// `loaded`, following `PickOutcome`. `failures` holds why the others
    /// could not be, where an error was available.
    private func complete(
        _ currentResult: FlutterResult,
        pickedCount: Int,
        loaded: [[String: Any]],
        failures: [LoadFailure] = []
    ) {
        switch PickOutcome.resolve(pickedCount: pickedCount, loaded: loaded) {
        case .cancelled:
            currentResult(nil)
        case .loaded(let items):
            currentResult(items)
        case .loadFailed:
            currentResult(loadFailedError(failures))
        }
    }

    /// The error for a pick where the user picked at least one item but none
    /// could be loaded, for example photos only stored in iCloud while the
    /// device is offline, or a device with no space left for the copy.
    /// Completing with `nil` instead would look like a cancellation to the app.
    ///
    /// `details` lists one `LoadFailure.details` map per item that failed with
    /// an error, in pick order, so the app can tell those causes apart. It is
    /// empty when no error was available, for example with `copyMedia: false`.
    private func loadFailedError(_ failures: [LoadFailure]) -> FlutterError {
        FlutterError(
            code: "load_failed",
            message: "None of the picked items could be loaded.",
            details: failures.sorted { $0.index < $1.index }.map(\.details))
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

    /// Moves a picked item into its own freshly created subdirectory of
    /// `NSTemporaryDirectory()`, or copies it when `copying` is set, for
    /// sources the app does not own.
    ///
    /// The destination used to be `NSTemporaryDirectory()` plus the source's
    /// `lastPathComponent`, which is not unique: two picked assets can share a
    /// file name. Photos edited in the Photos app are exported under a fixed
    /// name, and Live Photos arrive as `.pvt` packages. These copies also run
    /// concurrently, because `loadFileRepresentation` calls its completion
    /// handler on an arbitrary queue, once per selected item. Colliding names
    /// therefore raced:
    ///
    ///     A: fileExists? no  -> starts copying to /tmp/NAME
    ///     B: fileExists? yes -> removes /tmp/NAME, deleting A's in-flight copy
    ///     A: copyItem throws -> returns nil
    ///     B: copyItem throws -> returns nil
    ///
    /// Both items are then dropped by the `compactMap` over `resolved`, and
    /// when every item loses the race the picker calls back with `nil`, which
    /// reaches Dart as an empty list. That is indistinguishable from the user
    /// cancelling, so the failure is silent.
    ///
    /// Giving each item its own directory removes the shared destination, so
    /// the copies can no longer observe or delete each other. The existence
    /// check is gone with it, the directory is new every time.
    ///
    /// Throws the file system error, such as a full disk, so the pick can
    /// report why the item could not be loaded.
    private func storeInTemporaryDirectory(_ sourceURL: URL, copying: Bool) throws -> URL {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destinationURL = directoryURL
            .appendingPathComponent(sourceURL.lastPathComponent)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        if copying {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } else {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        }
        return destinationURL
    }

    /// Describes a picked photo library asset without copying it, by its
    /// `assetIdentifier` and a `ph:///` URI. Returns `nil` for results that do
    /// not come from the photo library and so have no identifier.
    private func makeAssetInfo(from item: PHPickerResult) -> [String: Any]? {
        guard let assetIdentifier = item.assetIdentifier else {
            return nil
        }

        let provider = item.itemProvider
        var name = provider.suggestedName ?? assetIdentifier
        // Use the extension of the first image or video representation. A Live
        // Photo registers its bundle type first, and its suggested name may
        // already end in that bundle's ".pvt" extension, so replace any
        // extension that is not an image or video one.
        let mediaType = MediaRepresentation.mediaType(
            in: provider.registeredTypeIdentifiers,
            preferringCompatible: assetRepresentationMode == .compatible)
        let currentExtension = (name as NSString).pathExtension
        let hasMediaExtension = UTType(filenameExtension: currentExtension)
            .map(MediaRepresentation.isMedia) ?? false
        if !hasMediaExtension, let ext = mediaType?.preferredFilenameExtension {
            if !currentExtension.isEmpty {
                name = (name as NSString).deletingPathExtension
            }
            name += ".\(ext)"
        }

        return [
            // Three slashes keep the identifier out of the URI host, which
            // would be lowercased and stop matching the identifier.
            "uri": "ph:///\(assetIdentifier)",
            "name": name,
            "assetIdentifier": assetIdentifier,
        ]
    }

    private func makeFileInfo(from fileURL: URL) throws -> [String: Any] {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        let size = values.fileSize ?? 0

        return [
            "path": fileURL.path,
            "identifier": fileURL.absoluteString,
            "name": fileURL.lastPathComponent,
            "size": size,
        ]
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
