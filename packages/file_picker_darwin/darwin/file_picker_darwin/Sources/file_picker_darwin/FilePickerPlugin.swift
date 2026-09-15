#if os(iOS)
import Flutter
typealias FilePickerHandler = IOSFilePickerHandler
#elseif os(macOS) && canImport(FlutterMacOS)
import FlutterMacOS
typealias FilePickerHandler = MacOSFilePickerHandler
#endif
import Foundation

#if os(iOS) || (os(macOS) && canImport(FlutterMacOS))
public class FilePickerPlugin: NSObject, FlutterPlugin {
    private let handler: FilePickerHandler

    init(registrar: FlutterPluginRegistrar) {
        handler = FilePickerHandler(registrar: registrar)

        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
#if os(iOS)
        let messenger = registrar.messenger()
#else
        let messenger = registrar.messenger
#endif

        let channel = FlutterMethodChannel(
            name: "miguelruivo.flutter.plugins.filepicker",
            binaryMessenger: messenger
        )

        let eventChannel = FlutterEventChannel(
            name: "miguelruivo.flutter.plugins.filepickerevent",
            binaryMessenger: messenger
        )

        let instance = FilePickerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance.handler)

        #if os(iOS)
        registrar.addSceneDelegate(instance)
        #endif
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        handler.handle(call, result: result)
    }
}

#if os(iOS)
extension FilePickerPlugin: FlutterSceneLifeCycleDelegate {}
#endif

#endif