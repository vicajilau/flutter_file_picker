import 'dart:isolate';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:meta/meta.dart';

/// Arguments passed to background isolates for open and save file dialogs.
@internal
class OpenSaveFileArgs {
  OpenSaveFileArgs({
    required this.port,
    this.defaultFileName,
    this.dialogTitle,
    this.initialDirectory,
    this.type = FileType.any,
    this.allowedExtensions,
    this.allowMultiple = false,
    this.lockParentWindow = false,
    this.confirmOverwrite = false,
    this.parentWindowHandle,
    this.acceptLabel,
  });

  /// SendPort used to reply to the main isolate.
  final SendPort port;

  /// Default file name suggested in the save dialog.
  final String? defaultFileName;

  /// Optional title for the dialog box.
  final String? dialogTitle;

  /// Optional initial directory to open.
  final String? initialDirectory;

  /// File type filter rule.
  final FileType type;

  /// List of custom allowed extensions when [type] is [FileType.custom].
  final List<String>? allowedExtensions;

  /// Whether multi-selection is enabled.
  final bool allowMultiple;

  /// Whether to lock the parent window modally.
  final bool lockParentWindow;

  /// Whether to prompt before overwriting an existing file in save dialogs.
  final bool confirmOverwrite;

  /// The HWND handle of the parent window.
  final int? parentWindowHandle;

  /// The label for the dialog's confirm ("OK") button.
  final String? acceptLabel;
}
