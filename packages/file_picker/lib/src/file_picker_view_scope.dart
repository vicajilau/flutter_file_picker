import 'package:file_picker_darwin/file_picker_darwin.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Provides the [FilePickerPlatform] that the widgets below it use.
///
/// Import it from `package:file_picker/file_picker_view_scope.dart`.
///
/// On macOS each [View] gets a [FilePickerDarwin] bound to that view, so in a
/// multi-window app the panels attach to the window that asked for them.
///
/// Most apps don't need this: call `FilePicker.pickFile()` and friends
/// directly. For now only multi-window macOS apps need this scope, so that
/// each picker opens in its own window.
class FilePickerViewScope extends StatelessWidget {
  const FilePickerViewScope({super.key, required this.child});

  final Widget child;

  /// The picker of the closest [FilePickerViewScope], or
  /// [FilePickerPlatform.instance] when there is none.
  static FilePickerPlatform of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_FilePickerViewScope>()
            ?.picker ??
        FilePickerPlatform.instance;
  }

  @override
  Widget build(BuildContext context) {
    final viewId = View.of(context).viewId;
    final picker = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
        ? FilePickerDarwin(viewId: viewId)
        : FilePickerPlatform.instance;
    return _FilePickerViewScope(viewId: viewId, picker: picker, child: child);
  }
}

class _FilePickerViewScope extends InheritedWidget {
  const _FilePickerViewScope({
    required this.viewId,
    required this.picker,
    required super.child,
  });

  final int viewId;
  final FilePickerPlatform picker;

  @override
  bool updateShouldNotify(_FilePickerViewScope oldWidget) =>
      viewId != oldWidget.viewId ||
      picker.runtimeType != oldWidget.picker.runtimeType;
}
