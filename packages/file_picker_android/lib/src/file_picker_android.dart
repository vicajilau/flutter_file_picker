import 'dart:async';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_platform_file.dart';
import 'file_picker_android_options.dart';
import 'lost_file_picker_result.dart';

/// An implementation of [FilePickerPlatform] for Android.
class FilePickerAndroid extends FilePickerPlatform {
  /// Registers this class as the default instance of [FilePickerPlatform].
  static void registerWith() {
    FilePickerPlatform.instance = FilePickerAndroid();
  }

  static const String _tag = 'FilePickerAndroid';

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
    AndroidOptions androidOptions = const FilePickerAndroidOptions(),
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
      androidOptions: androidOptions,
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
    AndroidOptions androidOptions = const FilePickerAndroidOptions(),
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
      androidOptions: androidOptions,
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
    AndroidOptions androidOptions = const FilePickerAndroidOptions(),
  }) async {
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

      final Map<String, Object?>? safOptionsMap = switch (androidOptions) {
        FilePickerAndroidOptions opts => opts.safOptions.toMap(),
        _ => null,
      };

      final List<Map>? result = await methodChannel.invokeListMethod(typeName, {
        'allowMultipleSelection': allowMultiple,
        'allowedExtensions': allowedExtensions,
        'compressionQuality': compressionQuality,
        'androidSafOptions': safOptionsMap,
      });

      if (result == null) {
        return [];
      }

      final platformFiles = <PlatformFile>[];
      for (final Map platformFileMap in result) {
        platformFiles.add(AndroidPlatformFile.fromMap(platformFileMap));
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
    final files = await pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
    );
    return files.map((e) => e.path).nonNulls.toList();
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const FilePickerAndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    try {
      final Map<String, Object?>? safOptionsMap = switch (androidOptions) {
        FilePickerAndroidOptions opts => opts.safOptions.toMap(),
        _ => null,
      };

      return await methodChannel.invokeMethod<String>('dir', {
        'androidSafOptions': safOptionsMap,
      });
    } on PlatformException catch (ex) {
      if (ex.code == "unknown_path") {
        print(
          '[$_tag] Could not resolve directory path. Maybe it\'s a protected one or unsupported (such as Downloads folder). Make sure that you are on SDK 21 or above.',
        );
      }
    }
    return null;
  }

  /// Recovers the files picked before Android destroyed the activity, or the
  /// whole app process, while the file picker was open, or `null` if there is
  /// nothing to recover.
  ///
  /// Only `pickFile()` and `pickFiles()` can be recovered. The outcome is
  /// delivered once, and only the most recent lost pick is kept. Call it
  /// early, for example in the `initState` of the screen that started the
  /// pick, which a `RestorationScope` can bring back:
  ///
  /// ```dart
  /// if (FilePickerPlatform.instance case final FilePickerAndroid android) {
  ///   final lost = await android.retrieveLostData();
  /// }
  /// ```
  Future<LostFilePickerResult?> retrieveLostData() async {
    final Map<Object?, Object?>? data = await methodChannel
        .invokeMapMethod<Object?, Object?>('retrieveLostData');
    if (data == null) return null;

    if (data['errorCode'] case final String code) {
      return LostFilePickerResult(
        exception: PlatformException(
          code: code,
          message: data['errorMessage'] as String?,
        ),
      );
    }

    final files = (data['files'] as List<Object?>?) ?? const [];
    return LostFilePickerResult(
      files: [
        for (final file in files.whereType<Map<Object?, Object?>>())
          AndroidPlatformFile.fromMap(file),
      ],
    );
  }

  @override
  Future<void> clearTemporaryFiles() async {
    await methodChannel.invokeMethod<void>('clear');
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
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
            "bytes": bytes,
          });

      if (onFileSaving != null) {
        onFileSaving(FilePickerStatus.done);
      }

      if (savedPath == null) return null;
      return Uri.tryParse(savedPath) ?? Uri.file(savedPath);
    } catch (e) {
      rethrow;
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
    }
  }

  /// Releases the given Storage Access Framework [uri] grant on Android.
  Future<void> releaseSAFGrant(String uri) async {
    await methodChannel.invokeMethod('releaseSafGrant', {'uri': uri});
  }
}
