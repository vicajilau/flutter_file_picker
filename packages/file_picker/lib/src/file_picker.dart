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
  /// Only Android, iOS, macOS and web report it. Linux and Windows never call it.
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
  /// Only Android, iOS, macOS and web report it. Linux and Windows never call it.
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
  /// **Platform Support:** Only iOS and macOS can select files and
  /// directories in the same dialog. On Android, Linux and Windows the system
  /// picker selects either files or a directory, so only files can be
  /// selected, as with [pickFiles]. Not supported on web.
  @Deprecated(
    'Only iOS and macOS can select files and directories in the same dialog. '
    'Call FilePickerDarwin.pickFileAndDirectoryPaths() from '
    'package:file_picker_darwin there, and use pickFiles() on the other '
    'platforms. This will be removed in 14.0.0.',
  )
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

  /// Opens a native directory picker and lets the user select a directory.
  ///
  /// The [dialogTitle], if provided, will be used as the title for the directory picker dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the directory picker.
  ///
  /// The [androidOptions], [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow for platform-specific configurations when configuring the directory picker.
  ///
  /// Returns the [Uri] of the selected directory, or `null` if canceled.
  /// On Android it is the `content://` tree URI the Storage Access Framework
  /// grants access through, which is what the app can actually read. On the
  /// other platforms it is a `file` URI, so `uri.toFilePath()` gives the path.
  ///
  /// Not supported on web.
  static Future<Uri?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    return FilePickerPlatform.instance.pickDirectory(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      androidOptions: androidOptions,
      windowsOptions: windowsOptions,
      linuxOptions: linuxOptions,
      webOptions: webOptions,
    );
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
  @Deprecated(
    'Use pickDirectory() instead, which returns a Uri. '
    'On Android a path is often not readable by the app, while the '
    'content:// URI is. This will be removed in a future major version.',
  )
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
  /// Only Android, iOS and macOS report it. Linux, Windows and web never call it.
  ///
  /// The [windowsOptions], [linuxOptions], and [webOptions] parameters
  /// allow for platform-specific configurations when configuring the save file dialog.
  ///
  /// Returns the [Uri] of the saved file, or `null` if the user canceled the operation.
  /// Depending on the platform, the [Uri.scheme] may be `file`, `content`, `http(s)`, `data` or `blob`.
  ///
  /// The whole file is held in memory, so avoid saving large files.
  ///
  /// On Android, [bytes] cross the method channel in one piece, and a file of
  /// a few hundred MB can end the app with an `OutOfMemoryError` before the
  /// dialog opens, which the plugin cannot catch.
  ///
  /// On web, [bytes] go into a `Blob`. Safari, for one, cannot build one of
  /// 2 GiB or more and closes the tab, which was tried on Safari 27.2.
  ///
  /// To save a large file, use [saveFileFromStream] where
  /// [supportsSaveFileFromStream] is `true`, which writes it chunk by chunk.
  /// Reading a large file in chunks with [PlatformFile.readAsByteStream] is not
  /// affected.
  static Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    @Deprecated(
      'Has no effect, saveFile() never used it. '
      'This parameter will be removed in file_picker v14.0.0.',
    )
    FileType type = FileType.any,
    @Deprecated(
      'Has no effect, saveFile() never used it. '
      'This parameter will be removed in file_picker v14.0.0.',
    )
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

  /// Whether [saveFileFromStream] is supported on this platform.
  static bool get supportsSaveFileFromStream =>
      FilePickerPlatform.instance.supportsSaveFileFromStream;

  /// Opens a save file dialog to let the user select a location and a file name,
  /// and saves the chunks of [data] to it, using streamed writes.
  /// memory.
  ///
  /// Unlike [saveFile], a file of any size can be saved, since only the chunk
  /// being written is in memory. The chunks are written one at a time, and the
  /// next one is only requested once the previous one is written.
  ///
  /// The [fileName] parameter specifies the default file name for saving, and
  /// should include the file extension (e.g. `myFile.txt`).
  /// The [mimeType] parameter specifies the MIME type of the file (e.g. `application/pdf`).
  /// The [dialogTitle], if provided, will be used as the title for the save file dialog.
  /// The [initialDirectory], if provided, will be used as the initial directory path for the save file dialog.
  /// The [onFileSaving] callback, if provided, is triggered when the save dialog changes status.
  ///
  /// Returns the [Uri] of the saved file, or `null` if the user canceled the operation.
  /// If [data] throws or the file cannot be written, the half written file is
  /// removed where the platform allows it, and the error is thrown.
  ///
  /// Throws an [UnsupportedError] if [supportsSaveFileFromStream] is `false`.
  static Future<Uri?> saveFileFromStream({
    required String fileName,
    required Stream<Uint8List> data,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    return FilePickerPlatform.instance.saveFileFromStream(
      fileName: fileName,
      data: data,
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
