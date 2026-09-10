import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// The primary entry point for picking files and directories across platforms.
abstract final class FilePicker {
  /// Retrieves the file(s) from the underlying platform.
  ///
  /// Opens a native file explorer and lets the user select one or multiple files.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the picker.
  /// The [type] parameter defines the type of files that can be selected (e.g. [FileType.image], [FileType.video], etc.).
  /// The [allowedExtensions] parameter can be used to filter by specific file extensions when [type] is set to [FileType.custom].
  /// The [onFileLoading] callback can be used to track picker status changes.
  /// The [compressionQuality] parameter allows compressing picked images/videos on supported platforms (0-100).
  /// The [darwinOptions] parameter configures iOS photo-library asset representation.
  ///
  /// The [androidOptions], [darwinOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow for platform-specific configurations when configuring the file picker.
  ///
  /// Returns a list of [PlatformFile] objects containing the selected files, or an empty list if the user canceled the operation.
  static Future<List<PlatformFile>> pickFiles({
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
    darwinOptions.validate(compressionQuality);
    return FilePickerPlatform.instance.pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      compressionQuality: compressionQuality,
      androidOptions: androidOptions,
      darwinOptions: darwinOptions,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      webOptions: webOptions,
    );
  }

  /// Opens a native file explorer and lets the user select a single file.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the picker.
  /// The [type] parameter defines the type of file that can be selected (e.g. [FileType.image], [FileType.video], etc.).
  /// The [allowedExtensions] parameter can be used to filter by specific file extensions when [type] is set to [FileType.custom].
  /// The [onFileLoading] callback can be used to track picker status changes.
  /// The [compressionQuality] parameter allows compressing picked images/videos on supported platforms (0-100).
  /// The [darwinOptions] parameter configures iOS photo-library asset representation.
  ///
  /// The [androidOptions], [darwinOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow for platform-specific configurations when configuring the file picker.
  ///
  /// Returns a [PlatformFile] object if a file was selected, or `null` if the user canceled the operation.
  static Future<PlatformFile?> pickFile({
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
    darwinOptions.validate(compressionQuality);
    return FilePickerPlatform.instance.pickFile(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      compressionQuality: compressionQuality,
      androidOptions: androidOptions,
      darwinOptions: darwinOptions,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      webOptions: webOptions,
    );
  }

  /// Displays a dialog that allows the user to select both files and
  /// directories simultaneously, returning their absolute paths.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the picker.
  /// The [type] parameter specifies the type of files to be picked and defaults to [FileType.any].
  /// The [allowedExtensions] parameter can be used to filter by specific file extensions when [type] is set to [FileType.custom].
  ///
  /// Returns the list of absolute paths to the selected files and directories, or an empty list if the operation was canceled.
  ///
  /// **Platform Support:** As of right now, this functionality is only
  /// supported on macOS.
  static Future<List<String>> pickFileAndDirectoryPaths({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) {
    return FilePickerPlatform.instance.pickFileAndDirectoryPaths(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
    );
  }

  /// Asks the underlying platform to remove any temporary files created by this plugin.
  static Future<void> clearTemporaryFiles() async {
    await FilePickerPlatform.instance.clearTemporaryFiles();
  }

  /// Selects a directory and returns its absolute path.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the directory picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the directory picker.
  ///
  /// The [androidOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow for platform-specific configurations when configuring the directory picker.
  ///
  /// Returns a [String] containing the selected directory path, or `null` if canceled.
  static Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    return FilePickerPlatform.instance.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      androidOptions: androidOptions,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      webOptions: webOptions,
    );
  }

  /// Opens a save file dialog to let the user select a location and a file name to
  /// save [bytes] to.
  ///
  /// The [fileName] parameter specifies the default file name for saving (e.g. `myFile.txt`).
  /// The [bytes] parameter contains the raw byte data to write.
  /// The [mimeType] parameter specifies the MIME type of the file (e.g. `application/pdf`).
  /// The [dialogTitle], if provided, will be used as the title for the save file dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the save file dialog.
  /// The [onFileSaving] callback, if provided, is triggered when the save dialog changes status.
  ///
  /// The [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow for platform-specific configurations when configuring the save file dialog.
  ///
  /// Returns the [Uri] of the saved file, or `null` if the user canceled the operation.
  /// Depending on the platform, the [Uri.scheme] may be `file`, `content`, `http(s)`, `data` or `blob`.
  static Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    return FilePickerPlatform.instance.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      onFileSaving: onFileSaving,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      webOptions: webOptions,
    );
  }

  /// Skips the macOS App Sandbox entitlement checks performed before showing a dialog.
  ///
  /// Only relevant for non-sandboxed macOS apps, which do not declare the
  /// `com.apple.security.files.user-selected.read-only`/`read-write` entitlements
  /// and would otherwise be incorrectly blocked by those checks. Call this before
  /// any other file picking method.
  ///
  /// Delegates to `FilePickerPlatform.instance.skipEntitlementsChecks()`,
  /// whose default implementation is a no-op. Only `FilePickerDarwin`
  /// overrides it, and only macOS performs the check in the first place, so
  /// this method does nothing on platforms other than macOS.
  ///
  /// Note: skipping entitlement checks may lead to unexpected behavior if the
  /// app is actually sandboxed. Use with caution.
  static Future<void> skipEntitlementsChecks() async {
    await FilePickerPlatform.instance.skipEntitlementsChecks();
  }
}
