import 'package:file_picker_web/src/file_picker_web_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FilePickerWebOptions initializes with default properties', () {
    const options = FilePickerWebOptions();
    expect(options.cancelUploadOnWindowBlur, isTrue);
    expect(options.saveMode, WebSaveFileMode.download);
  });
}
