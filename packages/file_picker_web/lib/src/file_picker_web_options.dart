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
  /// Whether to read each picked file into memory at pick time.
  ///
  /// Defaults to false to avoid allocating the full payload of every selected
  /// PDF, book or database just to return file names and metadata. Set to
  /// true only if the application explicitly needs eager loading.
  ///
  /// Files larger than 2 GB are never preloaded, since browsers cannot hold
  /// them in a single buffer. Their content can be read on demand through
  /// `PlatformFile.readAsBytes()` and `readAsByteStream()` instead.
  @Deprecated(
    'Picked files are read on demand by PlatformFile.readAsBytes() and '
    'readAsByteStream(). This option will be removed in file_picker v14.0.0.',
  )
  final bool withData;

  /// Whether to create a read stream for each picked file.
  @Deprecated(
    'PlatformFile.readAsByteStream() already reads on demand in evenly sized '
    'chunks. This option will be removed in file_picker v14.0.0.',
  )
  final bool withReadStream;

  /// Whether to read multiple files one at a time instead of concurrently.
  ///
  /// The result always preserves the original selection order, regardless
  /// of this setting.
  @Deprecated(
    'Only affects the deprecated withData preload. This option will be '
    'removed in file_picker v14.0.0.',
  )
  final bool readSequential;

  /// Whether to cancel upload when window loses focus.
  final bool cancelUploadOnWindowBlur;

  /// How [FilePickerWeb.saveFile] saves the file. Defaults to
  /// [WebSaveFileMode.download].
  final WebSaveFileMode saveMode;

  /// Creates an instance of [FilePickerWebOptions].
  const FilePickerWebOptions({
    @Deprecated(
      'Picked files are read on demand by PlatformFile.readAsBytes() and '
      'readAsByteStream(). This option will be removed in file_picker v14.0.0.',
    )
    this.withData = false,
    @Deprecated(
      'PlatformFile.readAsByteStream() already reads on demand in evenly '
      'sized chunks. This option will be removed in file_picker v14.0.0.',
    )
    this.withReadStream = false,
    @Deprecated(
      'Only affects the deprecated withData preload. This option will be '
      'removed in file_picker v14.0.0.',
    )
    this.readSequential = false,
    this.cancelUploadOnWindowBlur = true,
    this.saveMode = WebSaveFileMode.download,
  });
}
