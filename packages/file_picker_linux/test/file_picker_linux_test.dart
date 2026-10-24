import 'package:file_picker_linux/file_picker_linux.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerLinux', () {
    test('registers instance', () {
      FilePickerLinux.registerWith();
      expect(FilePickerPlatform.instance, isA<FilePickerLinux>());
    });

    test('LinuxPlatformFile parses path correctly', () {
      final file = LinuxPlatformFile.fromPath('/tmp/test.png');
      expect(file.name, equals('test.png'));
      expect(file.uri.path, equals('/tmp/test.png'));
    });

    test('LinuxPlatformFile.path decodes special characters', () {
      const path = '/home/user/AdSenseReport (3) #1 ñ%.PDF';
      final file = LinuxPlatformFile.fromPath(path);
      expect(file.path, equals(path));
    });

    test('LinuxPlatformFile.lengthSync() reflects bytesLength when known', () {
      final withoutBytes = LinuxPlatformFile.fromPath('/tmp/test.png');
      expect(withoutBytes.lengthSync(), isNull);

      final withBytes = LinuxPlatformFile(
        name: 'test.png',
        uri: Uri.file('/tmp/test.png'),
        bytesLength: 3,
      );
      expect(withBytes.lengthSync(), equals(3));
    });

    test('Filter constructs filters correctly', () {
      final filter = Filter(FileType.custom, ['png', 'jpg']);
      expect(filter.info.containsKey('Custom'), isTrue);
    });
  });

  group('FilePickerLinux.resolveOptions', () {
    // Exercises the narrowing the portal calls actually use. It used to fall
    // back to a default instance when the incoming value was a plain
    // LinuxOptions, silently dropping whatever the caller had set, which is
    // exactly what the deprecation on FilePicker.pickFiles points people at.

    test('keeps lockParentWindow from a plain LinuxOptions', () {
      expect(
        FilePickerLinux.resolveOptions(
          const LinuxOptions(lockParentWindow: true),
        ).lockParentWindow,
        isTrue,
      );
    });

    test('keeps acceptLabel from a plain LinuxOptions', () {
      expect(
        FilePickerLinux.resolveOptions(
          const LinuxOptions(acceptLabel: 'Choose'),
        ).acceptLabel,
        equals('Choose'),
      );
    });

    test('defaults are preserved for a plain LinuxOptions', () {
      final resolved = FilePickerLinux.resolveOptions(const LinuxOptions());

      expect(resolved.lockParentWindow, isFalse);
      expect(resolved.acceptLabel, isNull);
      expect(resolved.parentWindow, isNull);
    });

    test('returns a FilePickerLinuxOptions untouched', () {
      const options = FilePickerLinuxOptions(
        parentWindow: 'x11:0x1234',
        acceptLabel: 'Choose',
        lockParentWindow: true,
      );

      expect(
        identical(FilePickerLinux.resolveOptions(options), options),
        isTrue,
      );
    });

    test('FilePickerLinuxOptions can carry acceptLabel and parentWindow', () {
      const options = FilePickerLinuxOptions(
        parentWindow: 'wayland:handle',
        acceptLabel: 'Save here',
      );

      expect(options.acceptLabel, equals('Save here'));
      expect(options.parentWindow, equals('wayland:handle'));
      expect(options.lockParentWindow, isFalse);
    });
  });
}
