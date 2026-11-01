/// @docImport 'file_picker_web.dart';
library;

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// How [FilePickerWeb.saveFile] saves the file on the web.
enum WebSaveFileMode {
  /// Downloads the file, which most browsers drop into the Downloads folder
  /// without asking for a location or a name.
  download,

  /// Opens the browser's save dialog, so the user picks the folder and the
  /// file name.
  dialog,
}

/// Configuration options specific to the Web platform.
final class FilePickerWebOptions extends WebOptions {
  /// Whether to cancel upload when window loses focus.
  final bool cancelUploadOnWindowBlur;

  /// How [FilePickerWeb.saveFile] saves the file. Defaults to
  /// [WebSaveFileMode.download].
  final WebSaveFileMode saveMode;

  /// Creates an instance of [FilePickerWebOptions].
  const FilePickerWebOptions({
    this.cancelUploadOnWindowBlur = true,
    this.saveMode = WebSaveFileMode.download,
  });
}
