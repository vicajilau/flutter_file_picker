#if os(macOS) && canImport(FlutterMacOS)
import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

enum EntitlementMode {
    case requireWrite
    case readOrWrite
}

private extension CFString {
    static let securityFilesUserSelectedReadOnly =
        "com.apple.security.files.user-selected.read-only" as CFString
    static let securityFilesUserSelectedReadWrite =
        "com.apple.security.files.user-selected.read-write" as CFString
    static let securityAppSandbox =
        "com.apple.security.app-sandbox" as CFString
}

final class MacOSFilePickerHandler: NSObject, FlutterStreamHandler {
    private let registrar: FlutterPluginRegistrar
    private var skipEntitlementsChecks: Bool = false
    private var eventSink: FlutterEventSink?

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "any", "image", "video", "audio", "custom", "media", "pickFiles":
            handleFileSelection(call, result: result)

        case "dir", "getDirectoryPath":
            handleDirectorySelection(call, result: result)

        case "pickFileAndDirectoryPaths":
            handleFileAndDirectorySelection(call, result: result)

        case "save", "saveFile":
            handleSaveFile(call, result: result)

        case "clear":
            result(nil)

        case "skipEntitlementsChecks":
            skipEntitlementsChecks = true
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Runs `checkEntitlement` on a background queue (Security framework calls are
    /// synchronous and were causing a brief main-thread stall), then hops back to the
    /// main queue: either delivering the entitlement error, or calling
    /// `onEntitlementGranted` to build and present the dialog.
    private func withEntitlementCheck(
        requiredMode: EntitlementMode,
        result: @escaping FlutterResult,
        onEntitlementGranted: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let entitlementError = self.checkEntitlement(requiredMode: requiredMode)

            DispatchQueue.main.async {
                if let entitlementError {
                    result(entitlementError)
                    return
                }
                onEntitlementGranted()
            }
        }
    }

    private func handleFileSelection(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        withEntitlementCheck(requiredMode: .readOrWrite, result: result) { [weak self] in
            guard let self else { return }

            let dialog = NSOpenPanel()
            let args = (call.arguments as? [String: Any]) ?? [:]

            if let initialDirectory = args["initialDirectory"] as? String,
               !initialDirectory.isEmpty {
                dialog.directoryURL = URL(fileURLWithPath: initialDirectory)
            } else if let fallbackDirectory = self.defaultDirectoryURL() {
                dialog.directoryURL = fallbackDirectory
            }
            if let title = args["dialogTitle"] as? String {
                dialog.title = title
                dialog.message = title
            }
            if let acceptLabel = args["acceptLabel"] as? String, !acceptLabel.isEmpty {
                dialog.prompt = acceptLabel
            }
            dialog.showsHiddenFiles = false
            let allowMultiple = (args["allowMultipleSelection"] as? Bool) ?? (args["allowMultiple"] as? Bool) ?? false
            dialog.allowsMultipleSelection = allowMultiple
            dialog.canChooseDirectories = false
            dialog.canChooseFiles = true
            // Bundle-like directories (e.g. .app, .fcpbundle) should be selectable
            // as files, matching how Finder and other native apps present them.
            dialog.treatsFilePackagesAsDirectories = false
            let extensions = args["allowedExtensions"] as? [String] ?? []
            self.applyExtensions(dialog, extensions, method: call.method)

            guard let appWindow = self.getFlutterWindow() else {
                result(nil)
                return
            }

            dialog.beginSheetModal(for: appWindow) { response in
                if response != .OK {
                    result(nil)
                    return
                }

                let fileMaps = dialog.urls.compactMap { url -> [String: Any]? in
                    let path = url.path
                    let name = url.lastPathComponent
                    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
                    return [
                        "path": path,
                        "name": name,
                        "size": size
                    ]
                }

                if fileMaps.isEmpty {
                    result(nil)
                } else {
                    result(fileMaps)
                }
            }
        }
    }

    private func handleFileAndDirectorySelection(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        withEntitlementCheck(requiredMode: .readOrWrite, result: result) { [weak self] in
            guard let self else { return }

            let dialog: NSOpenPanel = NSOpenPanel()
            let args = (call.arguments as? [String: Any]) ?? [:]

            if let initialDirectory = args["initialDirectory"] as? String,
               !initialDirectory.isEmpty {
                dialog.directoryURL = URL(fileURLWithPath: initialDirectory)
            } else if let fallbackDirectory = self.defaultDirectoryURL() {
                dialog.directoryURL = fallbackDirectory
            }
            if let title = args["dialogTitle"] as? String {
                dialog.title = title
                dialog.message = title
            }
            dialog.showsHiddenFiles = false
            dialog.allowsMultipleSelection = true
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = true
            // Bundle-like directories (e.g. .app, .fcpbundle) should be selectable
            // as files, matching how Finder and other native apps present them.
            dialog.treatsFilePackagesAsDirectories = false
            let extensions = args["allowedExtensions"] as? [String] ?? []
            self.applyExtensions(dialog, extensions, method: call.method)

            guard let appWindow: NSWindow = self.getFlutterWindow() else {
                result(nil)
                return
            }

            dialog.beginSheetModal(for: appWindow) { response in
                if response != .OK {
                    result(nil)
                    return
                }

                let pathResult = dialog.urls

                if pathResult.isEmpty {
                    result(nil)
                } else {
                    let paths = pathResult.map { $0.path }
                    result(paths)
                }
            }
        }
    }

    private func handleDirectorySelection(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        withEntitlementCheck(requiredMode: .readOrWrite, result: result) { [weak self] in
            guard let self else { return }

            let dialog = NSOpenPanel()
            let args = (call.arguments as? [String: Any]) ?? [:]

            if let initialDirectory = args["initialDirectory"] as? String,
               !initialDirectory.isEmpty {
                dialog.directoryURL = URL(fileURLWithPath: initialDirectory)
            } else if let fallbackDirectory = self.defaultDirectoryURL() {
                dialog.directoryURL = fallbackDirectory
            }
            if let title = args["dialogTitle"] as? String {
                dialog.title = title
                if #available(macOS 10.10, *) {
                    dialog.titleVisibility = .visible
                    dialog.titlebarAppearsTransparent = false
                }
                dialog.message = title
            }
            dialog.showsHiddenFiles = false
            dialog.allowsMultipleSelection = false
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = false

            guard let appWindow = self.getFlutterWindow() else {
                result(nil)
                return
            }
            dialog.beginSheetModal(for: appWindow) { response in
                if response != .OK {
                    result(nil)
                    return
                }

                if let url = dialog.url {
                    result(url.path)
                    return
                }

                result(nil)
            }
        }
    }

    private func handleSaveFile(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        withEntitlementCheck(requiredMode: .requireWrite, result: result) { [weak self] in
            guard let self else { return }

            let dialog = NSSavePanel()
            let args = (call.arguments as? [String: Any]) ?? [:]

            dialog.title = args["dialogTitle"] as? String ?? ""
            dialog.showsTagField = false
            dialog.showsHiddenFiles = false
            dialog.canCreateDirectories = true
            dialog.isExtensionHidden = true
            dialog.nameFieldStringValue = args["fileName"] as? String ?? ""

            if let initialDirectory = args["initialDirectory"] as? String,
               !initialDirectory.isEmpty {
                dialog.directoryURL = URL(fileURLWithPath: initialDirectory)
            } else if let fallbackDirectory = self.defaultDirectoryURL() {
                dialog.directoryURL = fallbackDirectory
            }

            let extensions = args["allowedExtensions"] as? [String] ?? []
            self.applyExtensions(dialog, extensions, method: call.method)
            if extensions.isEmpty {
                self.applyDefaultExtension(dialog, fileName: args["fileName"] as? String ?? "")
            }

            guard let appWindow = self.getFlutterWindow() else {
                result(nil)
                return
            }
            dialog.beginSheetModal(for: appWindow) { response in
                if response != .OK {
                    result(nil)
                    return
                }

                if let url = dialog.url {
                    result(url.path)
                    return
                }

                result(nil)
            }
        }
    }

    private func checkEntitlement(requiredMode: EntitlementMode) -> FlutterError? {
        if skipEntitlementsChecks {
            return nil
        }

        guard let task = SecTaskCreateFromSelf(nil) else {
            return FlutterError(
                code: "ENTITLEMENT_CHECK_FAILED",
                message: "Failed to verify file_picker entitlements.",
                details: nil)
        }

        let readWriteEntitlement =
            SecTaskCopyValueForEntitlement(
                task,
                .securityFilesUserSelectedReadWrite,
                nil) as? Bool
        let readOnlyEntitlement =
            SecTaskCopyValueForEntitlement(
                task,
                .securityFilesUserSelectedReadOnly,
                nil) as? Bool

        switch requiredMode {
        case .requireWrite:
            if readWriteEntitlement != true {
                return FlutterError(
                    code: "ENTITLEMENT_REQUIRED_WRITE",
                    message:
                        "The Read-Write entitlement is required for this action.",
                    details: nil)
            }

        case .readOrWrite:
            if readWriteEntitlement != true && readOnlyEntitlement != true {
                return FlutterError(
                    code: "ENTITLEMENT_NOT_FOUND",
                    message:
                        "Either the Read-Only or Read-Write entitlement is required for this action.",
                    details: nil)
            }
        }
        return nil
    }

    private func isSandboxed() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }
        return (SecTaskCopyValueForEntitlement(task, .securityAppSandbox, nil) as? Bool) == true
    }

    private func defaultDirectoryURL() -> URL? {
        isSandboxed() ? FileManager.default.homeDirectoryForCurrentUser : nil
    }

    private func applyExtensions(_ dialog: NSSavePanel, _ extensions: [String], method: String = "") {
        if #available(macOS 11.0, *) {
            var contentTypes: [UTType] = []
            switch method {
            case "image":
                contentTypes = [.image]
            case "video":
                contentTypes = [.movie, .video]
            case "audio":
                contentTypes = [.audio]
            case "media":
                contentTypes = [.image, .movie, .video, .audio]
            case "custom":
                contentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
            default:
                if !extensions.isEmpty {
                    contentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
                }
            }
            if !contentTypes.isEmpty {
                dialog.allowedContentTypes = contentTypes
            }
        } else {
            var fileTypes = extensions
            if fileTypes.isEmpty {
                switch method {
                case "image":
                    fileTypes = ["bmp", "gif", "jpeg", "jpg", "png", "webp", "heic"]
                case "video":
                    fileTypes = ["avi", "flv", "mkv", "mov", "mp4", "mpeg", "webm", "wmv"]
                case "audio":
                    fileTypes = ["aac", "midi", "mp3", "ogg", "wav", "m4a", "flac"]
                case "media":
                    fileTypes = ["bmp", "gif", "jpeg", "jpg", "png", "webp", "avi", "flv", "mkv", "mov", "mp4", "mpeg", "webm", "wmv"]
                default:
                    break
                }
            }
            if !fileTypes.isEmpty {
                dialog.allowedFileTypes = fileTypes
            }
        }
    }

    /// `saveFile()` never forwards `allowedExtensions` down to the native save
    /// dialog, so `applyExtensions` has nothing to enforce and `NSSavePanel`
    /// won't append or require any extension. Fall back to the extension of
    /// the suggested file name, so a name like "Report.txt" still enforces
    /// ".txt" even though no explicit extension list reached this call.
    private func applyDefaultExtension(_ dialog: NSSavePanel, fileName: String) {
        let ext = (fileName as NSString).pathExtension
        guard !ext.isEmpty else { return }

        if #available(macOS 11.0, *) {
            if let type = UTType(filenameExtension: ext) {
                dialog.allowedContentTypes = [type]
            }
        } else {
            dialog.allowedFileTypes = [ext]
        }
    }

    private func getFlutterWindow() -> NSWindow? {
        registrar.view?.window
    }
}
#endif
