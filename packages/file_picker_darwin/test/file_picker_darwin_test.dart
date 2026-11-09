import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
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

    test('a reported empty file needs no size lookup', () async {
      final file = DarwinPlatformFile.fromMap({
        'path': '/tmp/empty.txt',
        'size': 0,
      });
      expect(file.lengthSync(), 0);
      expect(await file.length(), 0);
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

    test('pickFile and pickFiles send copyMedia', () async {
      final picker = FilePickerDarwin();
      bool? copyMedia;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            copyMedia = (call.arguments as Map)['copyMedia'] as bool?;
            return <Map<Object?, Object?>>[];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      await picker.pickFiles(type: FileType.media);
      expect(copyMedia, isTrue);

      await picker.pickFiles(
        type: FileType.media,
        darwinOptions: const DarwinOptions(copyMedia: false),
      );
      expect(copyMedia, isFalse);

      await picker.pickFile(type: FileType.media);
      expect(copyMedia, isTrue);

      await picker.pickFile(
        type: FileType.media,
        darwinOptions: const DarwinOptions(copyMedia: false),
      );
      expect(copyMedia, isFalse);
    });

    group('DarwinPlatformFile asset identifier', () {
      test('is kept alongside a copied file', () {
        final file = DarwinPlatformFile.fromMap({
          'path': '/tmp/IMG_0001.HEIC',
          'name': 'IMG_0001.HEIC',
          'assetIdentifier': 'ABC-123/L0/001',
        });

        expect(file.assetIdentifier, 'ABC-123/L0/001');
        expect(file.uri.scheme, 'file');
      });

      test('is null for files outside the photo library', () {
        final file = DarwinPlatformFile.fromMap({'path': '/tmp/a.pdf'});
        expect(file.assetIdentifier, isNull);
      });

      test('reads through its own XFile even with a ph URI', () async {
        final dir = Directory.systemTemp.createTempSync('file_picker_test');
        addTearDown(() => dir.deleteSync(recursive: true));
        final copy = File('${dir.path}/IMG_0001.HEIC')
          ..writeAsBytesSync([1, 2, 3]);

        final file = DarwinPlatformFile(
          name: 'IMG_0001.HEIC',
          uri: Uri.parse('ph:///ABC-123/L0/001'),
          assetIdentifier: 'ABC-123/L0/001',
          xFile: XFile(copy.path),
        );

        expect(await file.readAsBytes(), [1, 2, 3]);
        expect(await file.length(), 3);
      });

      test('appears in toString only when set', () {
        final asset = DarwinPlatformFile.fromMap({
          'uri': 'ph:///ABC-123/L0/001',
          'name': 'IMG_0001.HEIC',
          'assetIdentifier': 'ABC-123/L0/001',
        });
        final file = DarwinPlatformFile.fromMap({'path': '/tmp/a.pdf'});

        expect(asset.toString(), contains('assetIdentifier: ABC-123/L0/001'));
        expect(file.toString(), isNot(contains('assetIdentifier')));
      });

      test('references the asset without a readable copy', () async {
        final file = DarwinPlatformFile.fromMap({
          'uri': 'ph:///ABC-123/L0/001',
          'name': 'IMG_0001.HEIC',
          'assetIdentifier': 'ABC-123/L0/001',
        });

        expect(file.uri.scheme, 'ph');
        expect(file.uri.path, '/ABC-123/L0/001');
        expect(file.path, isNull);
        expect(file.name, 'IMG_0001.HEIC');
        expect(file.assetIdentifier, 'ABC-123/L0/001');
        expect(await file.length(), isNull);
        final throwsAssetReferenceError = throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            'This file was picked with DarwinOptions(copyMedia: false), so it '
                'has no readable copy. Open the original asset by its '
                'assetIdentifier instead.',
          ),
        );
        await expectLater(file.readAsBytes(), throwsAssetReferenceError);
        await expectLater(
          file.readAsByteStream().toList(),
          throwsAssetReferenceError,
        );
      });
    });

    test('pickFiles surfaces load_failed instead of an empty list', () async {
      final picker = FilePickerDarwin();
      // Why each item failed, in the shape the native side sends it.
      final details = [
        {
          'index': 0,
          'domain': 'NSItemProviderErrorDomain',
          'code': -1000,
          'message': 'Cannot load representation of type public.movie',
          'underlying': [
            {
              'domain': 'NSCocoaErrorDomain',
              'code': 640,
              'message': 'You can’t save the file because the volume is full.',
            },
          ],
        },
      ];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            throw PlatformException(
              code: 'load_failed',
              message: 'None of the picked items could be loaded.',
              details: details,
            );
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      await expectLater(
        picker.pickFiles(type: FileType.media),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'load_failed')
              .having((e) => e.details, 'details', details),
        ),
      );
    });

    test('pickFile and pickFiles send orderedSelection', () async {
      final picker = FilePickerDarwin();
      bool? orderedSelection;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            orderedSelection =
                (call.arguments as Map)['orderedSelection'] as bool?;
            return <Map<Object?, Object?>>[];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null);
      });

      await picker.pickFiles(type: FileType.media);
      expect(orderedSelection, isTrue);

      await picker.pickFiles(
        type: FileType.media,
        darwinOptions: const DarwinOptions(orderedSelection: false),
      );
      expect(orderedSelection, isFalse);

      await picker.pickFile(type: FileType.media);
      expect(orderedSelection, isTrue);

      await picker.pickFile(
        type: FileType.media,
        darwinOptions: const DarwinOptions(orderedSelection: false),
      );
      expect(orderedSelection, isFalse);
    });

    test(
      'pickFile and pickFiles send dialogTitle and initialDirectory',
      () async {
        final picker = FilePickerDarwin();
        Map<Object?, Object?>? receivedArguments;

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

  group('status updates', () {
    late FilePickerDarwin picker;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      picker = FilePickerDarwin();
      // The status stream fails as soon as it is listened to.
      messenger.setMockStreamHandler(
        picker.eventChannel,
        MockStreamHandler.inline(
          onListen: (_, events) => events.error(code: 'stream_error'),
        ),
      );
    });

    tearDown(() {
      messenger.setMockStreamHandler(picker.eventChannel, null);
      messenger.setMockMethodCallHandler(picker.methodChannel, null);
    });

    test('a failing status stream does not fail the pick', () async {
      messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
        // Let the stream error arrive while the pick is still running.
        await pumpEventQueue();
        return null;
      });

      expect(await picker.pickFiles(onFileLoading: (_) {}), isEmpty);
    });

    test('pickFile reports done on cancellation and platform errors', () async {
      var shouldFail = false;
      messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
        if (shouldFail) {
          throw PlatformException(code: 'pick_failed');
        }
        return null;
      });

      final statuses = <FilePickerStatus>[];
      expect(await picker.pickFiles(onFileLoading: statuses.add), isEmpty);
      expect(statuses.last, FilePickerStatus.done);

      shouldFail = true;
      await expectLater(
        picker.pickFile(onFileLoading: statuses.add),
        throwsA(isA<PlatformException>()),
      );
      expect(statuses.last, FilePickerStatus.done);
    });

    test('independent picker requests finish their own callbacks', () async {
      final firstResponse = Completer<List<Map<Object?, Object?>>?>();
      final secondResponse = Completer<List<Map<Object?, Object?>>?>();
      var nextCall = 0;
      messenger.setMockMethodCallHandler(picker.methodChannel, (call) {
        return nextCall++ == 0 ? firstResponse.future : secondResponse.future;
      });

      final firstStatuses = <FilePickerStatus>[];
      final secondStatuses = <FilePickerStatus>[];
      final first = FilePickerDarwin(
        viewId: 1,
      ).pickFiles(onFileLoading: firstStatuses.add);
      final second = FilePickerDarwin(
        viewId: 2,
      ).pickFiles(onFileLoading: secondStatuses.add);

      firstResponse.complete(null);
      expect(await first, isEmpty);
      expect(firstStatuses.last, FilePickerStatus.done);
      expect(secondStatuses, isEmpty);

      secondResponse.complete(null);
      expect(await second, isEmpty);
      expect(secondStatuses.last, FilePickerStatus.done);
    });

    test('finishing one picker keeps events flowing to the other', () async {
      final responses = [Completer<Object?>(), Completer<Object?>()];
      var nextCall = 0;
      var listenCount = 0;
      void Function(bool)? emit;
      messenger.setMockStreamHandler(
        picker.eventChannel,
        MockStreamHandler.inline(
          onListen: (_, events) {
            listenCount++;
            emit = (value) => events.success(value);
          },
        ),
      );
      messenger.setMockMethodCallHandler(
        picker.methodChannel,
        (_) => responses[nextCall++].future,
      );
      final firstStatuses = <FilePickerStatus>[];
      final secondStatuses = <FilePickerStatus>[];
      final first = picker.pickFiles(onFileLoading: firstStatuses.add);
      final second = FilePickerDarwin(
        viewId: 2,
      ).pickFiles(onFileLoading: secondStatuses.add);
      await pumpEventQueue();
      expect(listenCount, 1);
      emit!(true);
      await pumpEventQueue();
      expect(firstStatuses, [FilePickerStatus.picking]);
      expect(secondStatuses, [FilePickerStatus.picking]);
      responses[0].complete(null);
      await first;
      emit!(false);
      await pumpEventQueue();
      expect(secondStatuses.last, FilePickerStatus.done);
      expect(firstStatuses, [FilePickerStatus.picking, FilePickerStatus.done]);
      responses[1].complete(null);
      await second;
    });

    test('save cancels its listener before a throwing done callback', () async {
      var cancellations = 0;
      messenger.setMockStreamHandler(
        picker.eventChannel,
        MockStreamHandler.inline(
          onListen: (_, _) {},
          onCancel: (_) => cancellations++,
        ),
      );
      messenger.setMockMethodCallHandler(
        picker.methodChannel,
        (_) async => null,
      );

      await expectLater(
        picker.saveFile(
          fileName: 'a.txt',
          bytes: Uint8List(0),
          mimeType: 'text/plain',
          onFileSaving: (status) {
            if (status == FilePickerStatus.done) throw StateError('callback');
          },
        ),
        throwsStateError,
      );
      expect(cancellations, 1);
    });

    test('saveFile reports done when saving fails', () async {
      messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
        throw PlatformException(code: 'save_failed');
      });
      final statuses = <FilePickerStatus>[];

      await expectLater(
        picker.saveFile(
          fileName: 'a.txt',
          bytes: Uint8List.fromList([1]),
          mimeType: 'text/plain',
          onFileSaving: statuses.add,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(statuses.last, FilePickerStatus.done);
    });
  });
}
