import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// Configuration options specific to the Web platform.
final class FilePickerWebOptions extends WebOptions {
  /// Whether to cancel upload when window loses focus.
  final bool cancelUploadOnWindowBlur;

  /// Creates an instance of [FilePickerWebOptions].
  const FilePickerWebOptions({this.cancelUploadOnWindowBlur = true});
}
