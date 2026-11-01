import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'enums/file_picker_status.dart';
import 'enums/file_type.dart';
import 'file_picker_options/android_options.dart';
import 'file_picker_options/darwin_options.dart';
import 'file_picker_options/linux_options.dart';
import 'file_picker_options/web_options.dart';
import 'file_picker_options/windows_options.dart';
import 'method_channel_file_picker.dart';
import 'platform_file.dart';

/// The interface that implementations of file_picker must implement.
abstract class FilePickerPlatform extends PlatformInterface {
  FilePickerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FilePickerPlatform _instance = MethodChannelFilePicker();

  static FilePickerPlatform get instance => _instance;

  static set instance(FilePickerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Pick a single file using the native file picker.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the picker.
  /// The [type] parameter specifies the type of file to be picked and defaults to [FileType.any].
  /// The [allowedExtensions] parameter, if provided, restricts selection to specified file extensions
  /// when [type] is set to [FileType.custom].
  /// The [onFileLoading] callback, if provided, is triggered when the picker changes status.
  /// The [compressionQuality] parameter specifies image/video compression quality (0-100) on supported platforms.
  /// The [darwinOptions] parameter configures iOS photo-library asset representation.
  ///
  /// The [androidOptions], [darwinOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow platform-specific configurations for the file picker.
  ///
  /// Returns a [PlatformFile] object containing the selected file, or `null` if the user canceled the operation.
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
  }) {
    throw UnimplementedError('pickFile() has not been implemented.');
  }

  /// Pick multiple files using the native file picker.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the picker.
  /// The [type] parameter specifies the type of files to be picked and defaults to [FileType.any].
  /// The [allowedExtensions] parameter, if provided, restricts selection to specified file extensions
  /// when [type] is set to [FileType.custom].
  /// The [onFileLoading] callback, if provided, is triggered when the picker changes status.
  /// The [compressionQuality] parameter specifies image/video compression quality (0-100) on supported platforms.
  /// The [darwinOptions] parameter configures iOS photo-library asset representation.
  ///
  /// The [androidOptions], [darwinOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow platform-specific configurations for the file picker.
  ///
  /// Returns a list of [PlatformFile] objects containing the selected files, or an empty list if the user canceled the operation.
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
  }) {
    throw UnimplementedError('pickFiles() has not been implemented.');
  }

  /// Pick files and directories using the native file picker.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the picker.
  /// The [type] parameter specifies the type of files to be picked and defaults to [FileType.any].
  /// The [allowedExtensions] parameter, if provided, restricts selection to specified file extensions
  /// when [type] is set to [FileType.custom].
  ///
  /// Returns a list of absolute paths for the selected files and directories, or an empty list if canceled.
  Future<List<String>> pickFileAndDirectoryPaths({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    throw UnimplementedError(
      'pickFileAndDirectoryPaths() has not been implemented.',
    );
  }

  /// Pick a single directory using the native file picker.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the directory picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the directory picker.
  ///
  /// The [androidOptions], [darwinOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow platform-specific configurations for the directory picker.
  ///
  /// Returns the absolute path of the selected directory, or `null` if the user canceled the operation.
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    throw UnimplementedError('getDirectoryPath() has not been implemented.');
  }

  /// Asks the underlying platform to remove any temporary files created by this plugin.
  ///
  /// Default implementation is a no-op for platforms that do not create temporary files.
  Future<void> clearTemporaryFiles() async {}

  /// Asks the underlying platform to skip the App Sandbox entitlement checks
  /// performed before showing a dialog.
  ///
  /// Default implementation is a no-op for platforms that do not perform
  /// entitlement checks.
  Future<void> skipEntitlementsChecks() async {}

  /// Save the given [bytes] to a file with the given [fileName], using the native save file dialog.
  ///
  /// The [fileName] parameter specifies the default file name for saving (e.g. `myFile.txt`).
  /// The [bytes] parameter contains the raw byte data to write.
  /// The [mimeType] parameter specifies the MIME type of the file (e.g. `application/pdf`).
  /// The [dialogTitle], if provided, will be used as the title for the save file dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the save file dialog.
  /// The [onFileSaving] callback, if provided, is triggered when the save dialog changes status.
  ///
  /// The [darwinOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow platform-specific configurations for the save file dialog.
  ///
  /// Returns the [Uri] of the saved file, or `null` if the user canceled the operation.
  /// Depending on the platform, the [Uri.scheme] may be `file`, `content`, `http(s)`, `data` or `blob`.
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
    throw UnimplementedError('saveFile() has not been implemented.');
  }
}
