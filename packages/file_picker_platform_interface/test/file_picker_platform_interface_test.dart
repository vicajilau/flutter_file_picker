import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class ExtendsFilePickerPlatform extends FilePickerPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerPlatformInterface', () {
    test('Can be extended', () {
      final ExtendsFilePickerPlatform instance = ExtendsFilePickerPlatform();
      expect(instance, isA<FilePickerPlatform>());
    });

    test('Default instance is MethodChannelFilePicker', () {
      expect(FilePickerPlatform.instance, isA<MethodChannelFilePicker>());
    });

    test('Can set instance', () {
      final ExtendsFilePickerPlatform instance = ExtendsFilePickerPlatform();
      FilePickerPlatform.instance = instance;
      expect(FilePickerPlatform.instance, instance);
    });

    test('Default implementations throw UnimplementedError or no-op', () async {
      final ExtendsFilePickerPlatform instance = ExtendsFilePickerPlatform();
      expect(() => instance.pickFile(), throwsUnimplementedError);
      expect(() => instance.pickFiles(), throwsUnimplementedError);
      expect(
        () => instance.pickFileAndDirectoryPaths(),
        throwsUnimplementedError,
      );
      expect(instance.clearTemporaryFiles(), completes);
      expect(() => instance.getDirectoryPath(), throwsUnimplementedError);
      expect(
        () => instance.saveFile(
          fileName: 'test.txt',
          bytes: Uint8List(0),
          mimeType: 'text/plain',
        ),
        throwsUnimplementedError,
      );
    });
  });
}
