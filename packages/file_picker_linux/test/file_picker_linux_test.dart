import 'dart:convert';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';

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

      final withBytes = LinuxPlatformFile.fromPath(
        '/tmp/test.png',
        bytes: Uint8List.fromList([1, 2, 3]),
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

  group('FilePickerLinux.openFileOptions', () {
    Map<String, DBusValue> open(
      FilePickerLinuxOptions options, {
      bool allowMultiple = false,
      String? initialDirectory,
    }) {
      return FilePickerLinux.openFileOptions(
        options,
        allowMultiple: allowMultiple,
        filter: Filter(FileType.any, null),
        initialDirectory: initialDirectory,
      );
    }

    test('sends lockParentWindow as modal', () {
      final locked = open(const FilePickerLinuxOptions(lockParentWindow: true));
      final unlocked = open(const FilePickerLinuxOptions());

      expect(locked['modal'], DBusBoolean(true));
      expect(unlocked['modal'], DBusBoolean(false));
    });

    test('sends multiple and the filters', () {
      final options = open(const FilePickerLinuxOptions(), allowMultiple: true);

      expect(options['multiple'], DBusBoolean(true));
      expect(options['filters'], Filter(FileType.any, null).toDBusArray());
    });

    test('sends acceptLabel only when set', () {
      final labelled = open(const FilePickerLinuxOptions(acceptLabel: 'Use'));
      final unlabelled = open(const FilePickerLinuxOptions());

      expect(labelled['accept_label'], DBusString('Use'));
      expect(unlabelled.containsKey('accept_label'), isFalse);
    });

    test('sends the initial directory as a null terminated byte string', () {
      final options = open(
        const FilePickerLinuxOptions(),
        initialDirectory: '/home/ñ',
      );

      expect(
        options['current_folder'],
        DBusArray.byte([...utf8.encode('/home/ñ'), 0]),
      );
    });

    test('omits the initial directory when not set', () {
      expect(
        open(const FilePickerLinuxOptions()).containsKey('current_folder'),
        isFalse,
      );
    });
  });

  group('FilePickerLinux.directoryOptions', () {
    test('asks for a directory', () {
      final options = FilePickerLinux.directoryOptions(
        const FilePickerLinuxOptions(lockParentWindow: true),
        initialDirectory: '/tmp',
      );

      expect(options['directory'], DBusBoolean(true));
      expect(options['modal'], DBusBoolean(true));
      expect(
        options['current_folder'],
        DBusArray.byte([...utf8.encode('/tmp'), 0]),
      );
    });
  });

  group('FilePickerLinux.saveFileOptions', () {
    test('suggests the file name', () {
      final options = FilePickerLinux.saveFileOptions(
        const FilePickerLinuxOptions(),
        fileName: 'report.pdf',
      );

      expect(options['current_name'], DBusString('report.pdf'));
      expect(options['modal'], DBusBoolean(false));
      expect(options.containsKey('current_folder'), isFalse);
    });
  });

  group('FilePickerLinux.pathsFromResponse', () {
    DBusValue uris(List<String> values) => DBusArray.string(values);

    test('returns the chosen paths, decoded', () {
      final paths = FilePickerLinux.pathsFromResponse(0, {
        'uris': uris([
          'file:///home/user/a.pdf',
          'file:///home/user/My%20Files/%C3%B1.txt',
        ]),
      });

      expect(paths, ['/home/user/a.pdf', '/home/user/My Files/ñ.txt']);
    });

    test('returns an empty list when nothing is chosen', () {
      expect(FilePickerLinux.pathsFromResponse(0, {}), isEmpty);
    });

    test('returns null when the user cancels', () {
      expect(
        FilePickerLinux.pathsFromResponse(1, {
          'uris': uris(['file:///a']),
        }),
        isNull,
      );
    });

    test('returns null when the request fails', () {
      expect(FilePickerLinux.pathsFromResponse(2, {}), isNull);
    });
  });

  group('FilePickerLinux.formatParentWindow', () {
    test('is empty without a parent window', () {
      expect(FilePickerLinux.formatParentWindow(null), '');
      expect(FilePickerLinux.formatParentWindow('  '), '');
    });

    test('keeps prefixed handles', () {
      expect(FilePickerLinux.formatParentWindow('x11:0x2a'), 'x11:0x2a');
      expect(
        FilePickerLinux.formatParentWindow(' wayland:handle '),
        'wayland:handle',
      );
    });

    test('prefixes a hex X11 window id', () {
      expect(FilePickerLinux.formatParentWindow('0x2a'), 'x11:0x2a');
    });

    test('converts a decimal X11 window id to hex', () {
      expect(FilePickerLinux.formatParentWindow('42'), 'x11:0x2a');
    });

    test('passes anything else through', () {
      expect(FilePickerLinux.formatParentWindow('other'), 'other');
    });
  });
}
