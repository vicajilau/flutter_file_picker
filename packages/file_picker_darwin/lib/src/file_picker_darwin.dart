import 'dart:async';
import 'dart:io';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'darwin_platform_file.dart';

/// An implementation of [FilePickerPlatform] for Apple platforms (iOS and macOS).
class FilePickerDarwin extends FilePickerPlatform {
  /// Registers this class as the default instance of [FilePickerPlatform].
  static void registerWith() {
    FilePickerPlatform.instance = FilePickerDarwin();
  }

  static const String _tag = 'FilePickerDarwin';

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'miguelruivo.flutter.plugins.filepicker',
    StandardMethodCodec(),
  );

  /// The event channel used to receive real-time updates from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel(
    'miguelruivo.flutter.plugins.filepickerevent',
  );

  static StreamSubscription? _eventSubscription;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final files = await _pickFilesInternal(
      allowMultiple: false,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      compressionQuality: compressionQuality,
      darwinOptions: darwinOptions,
    );
    return files.firstOrNull;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return _pickFilesInternal(
      allowMultiple: true,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      compressionQuality: compressionQuality,
      darwinOptions: darwinOptions,
    );
  }

  Future<List<PlatformFile>> _pickFilesInternal({
    required bool allowMultiple,
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    DarwinOptions darwinOptions = const DarwinOptions(),
  }) async {
    darwinOptions.validate(compressionQuality);

    final String typeName = type.name;

    try {
      if (onFileLoading != null) {
        _eventSubscription = eventChannel.receiveBroadcastStream().listen((
          data,
        ) {
          if (data is! bool) return;
          onFileLoading(
            data ? FilePickerStatus.picking : FilePickerStatus.done,
          );
        }, onError: (error) => throw Exception(error));
      }

      final List<Map<Object?, Object?>>? result = await methodChannel
          .invokeListMethod<Map<Object?, Object?>>(typeName, {
            'allowMultipleSelection': allowMultiple,
            'allowedExtensions': allowedExtensions,
            'compressionQuality': compressionQuality,
            'assetRepresentationMode':
                darwinOptions.assetRepresentationMode.name,
            'acceptLabel': darwinOptions.acceptLabel,
          });

      if (result == null) {
        return [];
      }

      final platformFiles = <PlatformFile>[];
      for (final Map<Object?, Object?> platformFileMap in result) {
        platformFiles.add(DarwinPlatformFile.fromMap(platformFileMap));
      }

      return platformFiles;
    } catch (e) {
      rethrow;
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
    }
  }

  @override
  Future<List<String>> pickFileAndDirectoryPaths({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    try {
      final List<String>? result = await methodChannel
          .invokeListMethod<String>('pickFileAndDirectoryPaths', {
            'dialogTitle': dialogTitle,
            'initialDirectory': initialDirectory,
            'allowedExtensions': allowedExtensions,
          });
      return result ?? [];
    } on PlatformException catch (ex) {
      print(
        '[$_tag] Could not resolve file and directory paths: ${ex.message}',
      );
    }
    return [];
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    try {
      return await methodChannel.invokeMethod<String>('dir');
    } on PlatformException catch (ex) {
      print('[$_tag] Could not resolve directory path: ${ex.message}');
    }
    return null;
  }

  @override
  Future<void> clearTemporaryFiles() async {
    await methodChannel.invokeMethod<void>('clear');
  }

  /// Skips the macOS App Sandbox entitlement checks performed before showing a dialog.
  ///
  /// Only relevant for non-sandboxed macOS apps, which do not declare the
  /// `com.apple.security.files.user-selected.read-only`/`read-write` entitlements
  /// and would otherwise be incorrectly blocked by those checks. Call this before
  /// any other file picking method.
  ///
  /// This method does nothing on iOS.
  ///
  /// Note: skipping entitlement checks may lead to unexpected behavior if the
  /// app is actually sandboxed. Use with caution.
  ///
  /// ```dart
  /// if (FilePickerPlatform.instance case final FilePickerDarwin instance) {
  ///   await instance.skipEntitlementsChecks();
  /// }
  /// ```
  @override
  Future<void> skipEntitlementsChecks() async {
    // Only macOS performs App Sandbox entitlement checks, this is a no-op on iOS.
    if (!Platform.isMacOS) return;
    await methodChannel.invokeMethod<void>('skipEntitlementsChecks');
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    // On macOS, NSSavePanel only returns the destination path; the plugin
    // writes the bytes to that path itself, mirroring how the Windows and
    // Linux implementations handle saveFile. On iOS, the native side needs
    // the bytes upfront to write a temp file before exporting it through
    // UIDocumentPickerViewController.
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS;

    try {
      if (onFileSaving != null) {
        onFileSaving(FilePickerStatus.picking);
        _eventSubscription = eventChannel.receiveBroadcastStream().listen((
          data,
        ) {
          if (data is! bool) return;
          onFileSaving(data ? FilePickerStatus.picking : FilePickerStatus.done);
        }, onError: (error) => throw Exception(error));
      }

      final String? savedPath = await methodChannel
          .invokeMethod<String>("save", {
            "fileName": fileName,
            "fileType": mimeType,
            "initialDirectory": initialDirectory,
            if (!isMacOS) "bytes": bytes,
          });

      if (savedPath != null && isMacOS) {
        await File(savedPath).writeAsBytes(bytes);
      }

      if (onFileSaving != null) {
        onFileSaving(FilePickerStatus.done);
      }

      if (savedPath == null) return null;
      return Uri.file(savedPath);
    } catch (e) {
      rethrow;
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
    }
  }
}
