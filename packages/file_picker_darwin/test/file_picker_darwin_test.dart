import 'dart:io';

import 'package:file_picker_darwin/file_picker_darwin.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerDarwin', () {
    test('registers instance', () {
      FilePickerDarwin.registerWith();
      expect(FilePickerPlatform.instance, isA<FilePickerDarwin>());
    });

    test('DarwinPlatformFile parses map correctly', () {
      final file = DarwinPlatformFile.fromMap({
        'name': 'test.png',
        'path': '/tmp/test.png',
        'size': 1024,
      });
      expect(file.name, equals('test.png'));
      expect(file.uri.path, equals('/tmp/test.png'));
      expect(file.lengthSync(), equals(1024));
    });

    test('DarwinPlatformFile.lengthSync() is null when not reported', () {
      final file = DarwinPlatformFile.fromMap({
        'name': 'test.png',
        'path': '/tmp/test.png',
      });
      expect(file.lengthSync(), isNull);
    });

    test(
      'pickFile and pickFiles send every asset representation mode',
      () async {
        final picker = FilePickerDarwin();
        final receivedModes = <String?>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              receivedModes.add(
                (call.arguments as Map)['assetRepresentationMode'] as String?,
              );
              return <Map<Object?, Object?>>[];
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(picker.methodChannel, null);
        });

        for (final mode in DarwinAssetRepresentationMode.values) {
          final options = DarwinOptions(assetRepresentationMode: mode);
          await picker.pickFile(darwinOptions: options);
          await picker.pickFiles(darwinOptions: options);
        }

        expect(receivedModes, [
          'automatic',
          'automatic',
          'current',
          'current',
          'compatible',
          'compatible',
        ]);
      },
    );

    test('pickFile sends acceptLabel', () async {
      final picker = FilePickerDarwin();
      String? receivedLabel;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            receivedLabel = (call.arguments as Map)['acceptLabel'] as String?;
            return <Map<Object?, Object?>>[];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      await picker.pickFile(
        darwinOptions: const DarwinOptions(acceptLabel: 'Choose'),
      );
      expect(receivedLabel, 'Choose');

      await picker.pickFile();
      expect(receivedLabel, isNull);
    });

    test('pickFiles sends acceptLabel', () async {
      final picker = FilePickerDarwin();
      String? receivedLabel;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            receivedLabel = (call.arguments as Map)['acceptLabel'] as String?;
            return <Map<Object?, Object?>>[];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      await picker.pickFiles(
        darwinOptions: const DarwinOptions(acceptLabel: 'Choose'),
      );
      expect(receivedLabel, 'Choose');

      await picker.pickFiles();
      expect(receivedLabel, isNull);
    });

    test(
      'pickFile and pickFiles send dialogTitle and initialDirectory',
      () async {
        final picker = FilePickerDarwin();
        Map? receivedArguments;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              receivedArguments = call.arguments as Map;
              return <Map<Object?, Object?>>[];
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(picker.methodChannel, null);
        });

        await picker.pickFile(
          dialogTitle: 'Pick a file',
          initialDirectory: '/Users/test/Documents',
        );
        expect(receivedArguments?['dialogTitle'], 'Pick a file');
        expect(receivedArguments?['initialDirectory'], '/Users/test/Documents');

        await picker.pickFiles(
          dialogTitle: 'Pick files',
          initialDirectory: '/Users/test/Downloads',
        );
        expect(receivedArguments?['dialogTitle'], 'Pick files');
        expect(receivedArguments?['initialDirectory'], '/Users/test/Downloads');
      },
    );

    test('getDirectoryPath sends dialogTitle and initialDirectory', () async {
      final picker = FilePickerDarwin();
      Map? receivedArguments;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            receivedArguments = call.arguments as Map;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      await picker.getDirectoryPath(
        dialogTitle: 'Pick a folder',
        initialDirectory: '/Users/test/Projects',
      );
      expect(receivedArguments?['dialogTitle'], 'Pick a folder');
      expect(receivedArguments?['initialDirectory'], '/Users/test/Projects');
    });

    test('rejects non-automatic representation with compression', () {
      final picker = FilePickerDarwin();
      const darwinOptions = DarwinOptions(
        assetRepresentationMode: DarwinAssetRepresentationMode.current,
      );

      expect(
        () => picker.pickFile(
          compressionQuality: 50,
          darwinOptions: darwinOptions,
        ),
        throwsArgumentError,
      );
      expect(
        () => picker.pickFiles(
          compressionQuality: 50,
          darwinOptions: darwinOptions,
        ),
        throwsArgumentError,
      );
    });

    test('saveFile writes bytes to disk on macOS', () async {
      final picker = FilePickerDarwin();
      final tempDir = await Directory.systemTemp.createTemp(
        'file_picker_darwin_test',
      );
      final targetFile = File('${tempDir.path}/output.txt');
      addTearDown(() => tempDir.delete(recursive: true));

      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            expect(call.method, 'save');
            expect(
              (call.arguments as Map).containsKey('bytes'),
              isFalse,
              reason:
                  'macOS writes bytes itself; the native side only '
                  'needs to return the destination path.',
            );
            return targetFile.path;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await picker.saveFile(
        fileName: 'output.txt',
        bytes: bytes,
        mimeType: 'text/plain',
      );

      expect(result, isNotNull);
      expect(await targetFile.readAsBytes(), equals(bytes));
    });

    test('pickFileAndDirectoryPaths calls the native combined picker and '
        'returns its paths', () async {
      final picker = FilePickerDarwin();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            expect(call.method, 'pickFileAndDirectoryPaths');
            expect((call.arguments as Map)['allowedExtensions'], ['pdf']);
            return ['/tmp/some_file.pdf', '/tmp/some_directory'];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      final result = await picker.pickFileAndDirectoryPaths(
        allowedExtensions: ['pdf'],
      );

      expect(result, ['/tmp/some_file.pdf', '/tmp/some_directory']);
    });

    test(
      'pickFileAndDirectoryPaths returns an empty list on PlatformException',
      () async {
        final picker = FilePickerDarwin();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              throw PlatformException(code: 'error');
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(picker.methodChannel, null);
        });

        final result = await picker.pickFileAndDirectoryPaths();

        expect(result, isEmpty);
      },
    );
  });
}
