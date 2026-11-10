import 'dart:async';
import 'dart:io';
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

    test('WindowsPlatformFile uri converts back to the original path', () {
      const path = r'C:\Users\Test\AdSenseReport (3) #1 ñ%.PDF';
      final file = WindowsPlatformFile.fromPath(path);
      expect(file.uri.toFilePath(windows: true), equals(path));
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

    test('empty in-memory files have a known zero length', () async {
      final file = WindowsPlatformFile.fromPath(
        r'C:\Users\Test\empty.txt',
        bytes: Uint8List(0),
      );
      expect(file.lengthSync(), 0);
      expect(await file.length(), 0);
    });

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

  group('native dialog failures', () {
    late Directory directory;
    late String missingDirectory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('picker_failure_');
      missingDirectory = '${directory.path}\\missing';
    });
    tearDown(() => directory.delete(recursive: true));

    for (final multiple in [false, true]) {
      test(
        'pickFiles multiple=$multiple propagates failure without status callbacks',
        () async {
          final statuses = <FilePickerStatus>[];
          final picker = FilePickerWindows();
          final result = multiple
              ? picker.pickFiles(
                  initialDirectory: missingDirectory,
                  onFileLoading: statuses.add,
                )
              : picker.pickFile(
                  initialDirectory: missingDirectory,
                  onFileLoading: statuses.add,
                );
          await expectLater(
            result.timeout(const Duration(seconds: 5)),
            throwsA(isNot(isA<TimeoutException>())),
          );
          expect(statuses, isEmpty);
        },
      );
    }

    test('saveFile propagates failure without status callbacks', () async {
      final statuses = <FilePickerStatus>[];
      await expectLater(
        FilePickerWindows()
            .saveFile(
              fileName: 'a.txt',
              bytes: Uint8List(0),
              mimeType: 'text/plain',
              initialDirectory: missingDirectory,
              onFileSaving: statuses.add,
            )
            .timeout(const Duration(seconds: 5)),
        throwsA(isNot(isA<TimeoutException>())),
      );
      expect(statuses, isEmpty);
    });
    test('directory propagates native failure', () async {
      await expectLater(
        FilePickerWindows()
            .getDirectoryPath(initialDirectory: missingDirectory)
            .timeout(const Duration(seconds: 5)),
        throwsA(isNot(isA<TimeoutException>())),
      );
    });
  }, skip: !Platform.isWindows);

  group('validateFileName', () {
    final picker = FilePickerWindows();

    test('accepts ordinary names', () {
      for (final name in ['report.pdf', 'report (1).pdf', 'ñ #1 %.txt']) {
        expect(() => picker.validateFileName(name), returnsNormally);
      }
    });

    test('rejects the characters Windows reserves', () {
      for (final char in ['<', '>', ':', '/', r'\', '|', '?', '*', '"']) {
        expect(
          () => picker.validateFileName('a${char}b.txt'),
          throwsArgumentError,
          reason: char,
        );
      }
    });
  });

  group('resolveDefaultExtension', () {
    final picker = FilePickerWindows();

    OpenSaveFileArgs args({
      List<String>? allowedExtensions,
      String? defaultFileName,
    }) {
      return OpenSaveFileArgs(
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

    test('media type combines all image and video extensions', () {
      final media = FilePickerWindows.fileTypeFilterSpecs(FileType.media, null);
      final images = FilePickerWindows.fileTypeFilterSpecs(
        FileType.image,
        null,
      );
      final videos = FilePickerWindows.fileTypeFilterSpecs(
        FileType.video,
        null,
      );

      expect(media, hasLength(1));
      expect(media.single.name, 'Images and videos');
      final patterns = media.single.pattern.split(';');
      expect(patterns, hasLength(patterns.toSet().length));
      expect(patterns.toSet(), {
        ...images.single.pattern.split(';'),
        ...videos.single.pattern.split(';'),
      });
    });

    test('video type keeps its own label and excludes image extensions', () {
      expect(FilePickerWindows.fileTypeFilterSpecs(FileType.video, null), [
        (
          name: 'Videos (*.avi,*.flv,*.mkv,*.mov,*.mp4,*.mpeg,*.webm,*.wmv)',
          pattern: '*.avi;*.flv;*.mkv;*.mov;*.mp4;*.mpeg;*.webm;*.wmv',
        ),
      ]);
    });

    test('allowed extensions affect custom filters, not media presets', () {
      expect(
        FilePickerWindows.fileTypeFilterSpecs(FileType.media, ['pdf']),
        FilePickerWindows.fileTypeFilterSpecs(FileType.media, null),
      );
      expect(FilePickerWindows.fileTypeFilterSpecs(FileType.custom, ['pdf']), [
        (name: 'Files (*.pdf)', pattern: '*.pdf'),
      ]);
    });
  });
}
