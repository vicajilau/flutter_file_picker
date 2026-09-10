import 'desktop_window_options.dart';

/// The options for the Windows file picker.
class WindowsOptions extends DesktopWindowOptions {
  /// Creates an instance of [WindowsOptions].
  const WindowsOptions({this.acceptLabel, super.lockParentWindow});

  /// The label for the confirm ("OK") button of the file dialog.
  ///
  /// Maps to `IFileDialog::SetOkButtonLabel`.
  final String? acceptLabel;
}
