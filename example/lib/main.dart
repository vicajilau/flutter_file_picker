import 'package:file_picker/file_picker_view_scope.dart';
import 'package:file_picker_example/src/file_picker_demo.dart';
import 'package:flutter/widgets.dart';

// Most apps don't need FilePickerViewScope: call `FilePicker.pickFile()` and
// friends directly. Only multi-window macOS apps need it, so that each picker
// opens in its own window.
void main() => runApp(FilePickerViewScope(child: FilePickerDemo()));
