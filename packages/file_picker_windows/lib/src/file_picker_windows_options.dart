import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// Configuration options specific to the Windows platform.
final class FilePickerWindowsOptions extends WindowsOptions {
  const FilePickerWindowsOptions({
    this.parentWindowHandle,
    super.acceptLabel,
    super.lockParentWindow,
  });

  /// The handle to the parent window (`HWND`).
  final int? parentWindowHandle;
}
