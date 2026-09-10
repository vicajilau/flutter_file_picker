import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:windows_file_picker/src/open_save_file_args.dart';
import 'package:windows_file_picker/windows_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerWindows', () {
    test('registers instance', () {
      FilePickerWindows.registerWith();
      expect(FilePickerPlatform.instance, isA<FilePickerWindows>());
    });

    test('WindowsPlatformFile parses path correctly', () {
      final file = WindowsPlatformFile.fromPath(r'C:\Users\Test\file.txt');
      expect(file.name, equals('file.txt'));
      expect(file.uri.path, equals('/C:/Users/Test/file.txt'));
    });

    test(
      'WindowsPlatformFile.lengthSync() reflects bytesLength when known',
      () {
        final withoutBytes = WindowsPlatformFile.fromPath(
          r'C:\Users\Test\file.txt',
        );
        expect(withoutBytes.lengthSync(), isNull);

        final withBytes = WindowsPlatformFile.fromPath(
          r'C:\Users\Test\file.txt',
          bytes: Uint8List.fromList([1, 2, 3]),
        );
        expect(withBytes.lengthSync(), equals(3));
      },
    );

    test('FilePickerWindowsOptions contains expected properties', () {
      const options = FilePickerWindowsOptions(
        parentWindowHandle: 12345,
        lockParentWindow: true,
        acceptLabel: 'Choose',
      );
      expect(options.parentWindowHandle, equals(12345));
      expect(options.lockParentWindow, isTrue);
      expect(options.acceptLabel, equals('Choose'));
    });

    test('WindowsOptions.acceptLabel defaults to null', () {
      const options = WindowsOptions();
      expect(options.acceptLabel, isNull);
    });
  });

  group('resolveDefaultExtension', () {
    final picker = FilePickerWindows();
    final port = ReceivePort();
    tearDownAll(port.close);

    OpenSaveFileArgs args({
      List<String>? allowedExtensions,
      String? defaultFileName,
    }) {
      return OpenSaveFileArgs(
        port: port.sendPort,
        allowedExtensions: allowedExtensions,
        defaultFileName: defaultFileName,
      );
    }

    test('prefers the first allowed extension', () {
      expect(
        picker.resolveDefaultExtension(
          args(allowedExtensions: ['pdf', 'docx'], defaultFileName: 'a.txt'),
        ),
        equals('pdf'),
      );
    });

    test('falls back to the extension of the default file name', () {
      expect(
        picker.resolveDefaultExtension(args(defaultFileName: 'calendar.pdf')),
        equals('pdf'),
      );
    });

    test('returns null when the default file name has no extension', () {
      expect(
        picker.resolveDefaultExtension(args(defaultFileName: 'calendar')),
        isNull,
      );
    });

    test('returns null when there is no extension source at all', () {
      expect(picker.resolveDefaultExtension(args()), isNull);
    });
  });

  group('fileTypeFilterSpecs', () {
    test('any type matches every file', () {
      final specs = FilePickerWindows.fileTypeFilterSpecs(FileType.any, null);
      expect(specs, [(name: 'All Files (*.*)', pattern: '*.*')]);
    });

    test('custom type builds a single spec from allowed extensions', () {
      final specs = FilePickerWindows.fileTypeFilterSpecs(FileType.custom, [
        'pdf',
        'docx',
      ]);
      expect(specs, [(name: 'Files (*.pdf,*.docx)', pattern: '*.pdf;*.docx')]);
    });

    test('custom type without allowed extensions throws', () {
      expect(
        () => FilePickerWindows.fileTypeFilterSpecs(FileType.custom, null),
        throwsArgumentError,
      );
      expect(
        () => FilePickerWindows.fileTypeFilterSpecs(FileType.custom, []),
        throwsArgumentError,
      );
    });

    test('image type builds the full image filter spec', () {
      final specs = FilePickerWindows.fileTypeFilterSpecs(FileType.image, null);
      expect(specs, [
        (
          name: 'Images (*.bmp,*.gif,*.jpeg,*.jpg,*.png,*.webp)',
          pattern: '*.bmp;*.gif;*.jpeg;*.jpg;*.png;*.webp',
        ),
      ]);
    });

    test('audio type builds the full audio filter spec', () {
      final specs = FilePickerWindows.fileTypeFilterSpecs(FileType.audio, null);
      expect(specs, [
        (
          name: 'Audio (*.aac,*.midi,*.mp3,*.ogg,*.wav,*.m4a)',
          pattern: '*.aac;*.midi;*.mp3;*.ogg;*.wav;*.m4a',
        ),
      ]);
    });

    test('media type produces separate video and image specs', () {
      final specs = FilePickerWindows.fileTypeFilterSpecs(FileType.media, null);
      expect(specs, [
        (
          name: 'Videos (*.avi,*.flv,*.mkv,*.mov,*.mp4,*.mpeg,*.webm,*.wmv)',
          pattern: '*.avi;*.flv;*.mkv;*.mov;*.mp4;*.mpeg;*.webm;*.wmv',
        ),
        (
          name: 'Images (*.bmp,*.gif,*.jpeg,*.jpg,*.png)',
          pattern: '*.bmp;*.gif;*.jpeg;*.jpg;*.png',
        ),
      ]);
    });
  });
}
