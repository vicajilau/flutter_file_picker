import 'package:file_picker_web/src/file_picker_web_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FilePickerWebOptions cancels on window blur by default', () {
    expect(const FilePickerWebOptions().cancelUploadOnWindowBlur, isTrue);
    expect(
      const FilePickerWebOptions(
        cancelUploadOnWindowBlur: false,
      ).cancelUploadOnWindowBlur,
      isFalse,
    );
  });
}
