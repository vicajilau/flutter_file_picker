import 'package:file_picker_example/src/file_picker_demo.dart';
import 'package:file_picker_example/src/file_picker_scope.dart';
import 'package:flutter/widgets.dart';

// Most apps don't need FilePickerScope: call `FilePicker.pickFile()` and
// friends directly. Only multi-window macOS apps need it, so that each picker
// opens in its own window.
void main() => runApp(FilePickerScope(child: FilePickerDemo()));
