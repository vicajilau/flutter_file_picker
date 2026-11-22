import 'dart:async';
import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerAndroid', () {
    test('registers instance', () {
      FilePickerAndroid.registerWith();
      expect(FilePickerPlatform.instance, isA<FilePickerAndroid>());
    });

    test('AndroidSAFOptions toMap contains expected keys', () {
      const safOptions = AndroidSAFOptions(
        grant: AndroidSAFGrant.lifetime,
        accessMode: AndroidSAFAccessMode.readWrite,
        persistGrant: true,
      );
      const options = FilePickerAndroidOptions(safOptions: safOptions);
      final map = options.safOptions.toMap();
      expect(map['grant'], equals('lifetime'));
      expect(map['access'], equals('readWrite'));
      expect(map['autoPersist'], isTrue);
      expect(map['copyToCache'], isTrue);
    });

    test('AndroidSAFOptions can opt out of the cache copy', () {
      const safOptions = AndroidSAFOptions(copyToCache: false);
      expect(safOptions.toMap()['copyToCache'], isFalse);
    });

    test('a document that was not copied keeps its content URI', () {
      const contentUri =
          'content://com.android.providers.media.documents/document/video%3A42';
      final file = AndroidPlatformFile.fromMap({
        'path': contentUri,
        'name': 'game.mp4',
        'size': 3 * 1024 * 1024 * 1024,
        'identifier': contentUri,
        'safHandle': {'uri': contentUri, 'access': 'readOnly'},
      });

      expect(file.uri, Uri.parse(contentUri));
      expect(file.path, isNull);
      expect(file.name, 'game.mp4');
      expect(file.lengthSync(), 3 * 1024 * 1024 * 1024);
      expect(file.safHandle?.uri, Uri.parse(contentUri));
    });

    test('AndroidSAFHandle parses map correctly', () {
      final handle = AndroidSAFHandle.fromMap({
        'uri': 'content://media/external/images/media/1',
        'access': 'readWrite',
      });
      expect(
        handle.uri,
        equals(Uri.parse('content://media/external/images/media/1')),
      );
      expect(handle.accessMode, equals(AndroidSAFAccessMode.readWrite));
    });

    test('AndroidPlatformFile derives name from path if name is empty', () {
      final file = AndroidPlatformFile.fromMap({'path': '/tmp/test_file.txt'});
      expect(file.name, equals('test_file.txt'));
      expect(file.path, equals('/tmp/test_file.txt'));
    });

    test('AndroidPlatformFile.lengthSync() reflects the reported size', () {
      final withSize = AndroidPlatformFile.fromMap({
        'path': '/tmp/test_file.txt',
        'size': 2048,
      });
      expect(withSize.lengthSync(), equals(2048));

      final withoutSize = AndroidPlatformFile.fromMap({
        'path': '/tmp/test_file.txt',
      });
      expect(withoutSize.lengthSync(), isNull);
    });

    test('a document that was not copied can have no known size', () async {
      const contentUri =
          'content://com.android.providers.media.documents/document/video%3A42';
      final file = AndroidPlatformFile.fromMap({
        'path': contentUri,
        'name': 'game.mp4',
        'identifier': contentUri,
      });

      expect(file.lengthSync(), isNull);
      expect(await file.length(), isNull);
    });

    test('a reported empty file needs no size lookup', () async {
      final file = AndroidPlatformFile.fromMap({
        'path': '/tmp/empty.txt',
        'size': 0,
      });
      expect(file.lengthSync(), 0);
      expect(await file.length(), 0);
    });

    test(
      'pickFileAndDirectoryPaths returns decoded paths that match the cached files',
      () async {
        final picker = FilePickerAndroid();
        const cachedPath =
            '/data/user/0/app/cache/file_picker/1/AdSenseReport (3) #1 ñ%.PDF';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              return [
                {'path': cachedPath, 'name': 'AdSenseReport (3) #1 ñ%.PDF'},
              ];
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(picker.methodChannel, null),
        );

        expect(await picker.pickFileAndDirectoryPaths(), [cachedPath]);
      },
    );

    group('sends the SAF options where the native side reads them', () {
      const options = FilePickerAndroidOptions(
        safOptions: AndroidSAFOptions(
          grant: AndroidSAFGrant.lifetime,
          accessMode: AndroidSAFAccessMode.readWrite,
          persistGrant: false,
        ),
      );
      const expected = {
        'grant': 'lifetime',
        'access': 'readWrite',
        'autoPersist': false,
        'copyToCache': true,
      };

      late FilePickerAndroid picker;
      late List<MethodCall> calls;

      setUp(() {
        picker = FilePickerAndroid();
        calls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              calls.add(call);
              return call.method == 'dir' ? '/storage/dir' : [];
            });
      });
      tearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null),
      );

      test('when picking files', () async {
        await picker.pickFiles(androidOptions: options);

        expect(calls.single.arguments['androidSafOptions'], expected);
      });

      test('when picking a directory', () async {
        await picker.getDirectoryPath(androidOptions: options);

        expect(calls.single.arguments['androidSafOptions'], expected);
      });
    });

    group('pickDirectory', () {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const treeUri =
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments';
      late FilePickerAndroid picker;
      late List<MethodCall> calls;

      setUp(() {
        picker = FilePickerAndroid();
        calls = [];
      });

      tearDown(
        () => messenger.setMockMethodCallHandler(picker.methodChannel, null),
      );

      test('returns the content URI of the tree', () async {
        messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
          calls.add(call);
          return treeUri;
        });

        final uri = await picker.pickDirectory();

        expect(uri?.scheme, 'content');
        expect(uri.toString(), treeUri);
        expect(calls.single.method, 'dir');
      });

      // The native side only answers with the tree URI when it gets SAF
      // options, so they are sent even when the app passes none.
      test('sends the default SAF options when the app passes none', () async {
        messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
          calls.add(call);
          return treeUri;
        });

        await picker.pickDirectory(androidOptions: const AndroidOptions());

        expect(
          (calls.single.arguments as Map)['androidSafOptions'],
          const AndroidSAFOptions().toMap(),
        );
      });

      test('sends the SAF options of the app', () async {
        messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
          calls.add(call);
          return treeUri;
        });
        const safOptions = AndroidSAFOptions(
          grant: AndroidSAFGrant.lifetime,
          accessMode: AndroidSAFAccessMode.readWrite,
        );

        await picker.pickDirectory(
          androidOptions: const FilePickerAndroidOptions(
            safOptions: safOptions,
          ),
        );

        expect(
          (calls.single.arguments as Map)['androidSafOptions'],
          safOptions.toMap(),
        );
      });

      test('returns null when the user cancels', () async {
        messenger.setMockMethodCallHandler(
          picker.methodChannel,
          (call) async => null,
        );

        expect(await picker.pickDirectory(), isNull);
      });

      // Unlike getDirectoryPath, a failure is not swallowed.
      test('throws when the pick fails', () async {
        messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
          throw PlatformException(code: 'already_active');
        });

        await expectLater(
          picker.pickDirectory(),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'already_active',
            ),
          ),
        );
      });
    });

    group('getDirectoryPath', () {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      late FilePickerAndroid picker;

      setUp(() => picker = FilePickerAndroid());

      tearDown(
        () => messenger.setMockMethodCallHandler(picker.methodChannel, null),
      );

      for (final code in ['already_active', 'unknown_path']) {
        test('logs $code and returns null', () async {
          messenger.setMockMethodCallHandler(picker.methodChannel, (_) async {
            throw PlatformException(code: code, message: 'Failed.');
          });
          final logs = <String>[];

          final path = await runZoned(
            picker.getDirectoryPath,
            zoneSpecification: ZoneSpecification(
              print: (_, _, _, line) => logs.add(line),
            ),
          );

          expect(path, isNull);
          expect(logs, contains(contains('failed with $code (Failed.)')));
          expect(logs, contains(contains('pickDirectory()')));
        });
      }
    });

    group('saveFileFromStream', () {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      late FilePickerAndroid picker;
      late List<MethodCall> calls;

      // The calls as maps of the method and its arguments, so a test can
      // compare all of their values at once.
      List<Map<String, Object?>> sent() => [
        for (final call in calls)
          {
            'method': call.method,
            ...?(call.arguments as Map<Object?, Object?>?)
                ?.cast<String, Object?>(),
          },
      ];

      setUp(() {
        picker = FilePickerAndroid();
        calls = [];
      });

      tearDown(
        () => messenger.setMockMethodCallHandler(picker.methodChannel, null),
      );

      void mock({int? id = 7, String? savedPath = '/document/primary:a.bin'}) {
        messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'openSaveStream' => id,
            'closeSaveStream' => savedPath,
            _ => null,
          };
        });
      }

      Stream<Uint8List> chunks(List<List<int>> chunks) async* {
        for (final chunk in chunks) {
          yield Uint8List.fromList(chunk);
        }
      }

      test('is supported', () {
        expect(picker.supportsSaveFileFromStream, isTrue);
      });

      test('opens, writes every chunk in order and closes', () async {
        mock();

        final uri = await picker.saveFileFromStream(
          fileName: 'a.bin',
          mimeType: 'application/octet-stream',
          data: chunks([
            [1, 2],
            [3],
          ]),
        );

        expect(uri, Uri.parse('/document/primary:a.bin'));
        expect(sent(), [
          {
            'method': 'openSaveStream',
            'fileName': 'a.bin',
            'fileType': 'application/octet-stream',
            'initialDirectory': null,
          },
          {
            'method': 'writeSaveStream',
            'id': 7,
            'bytes': Uint8List.fromList([1, 2]),
          },
          {
            'method': 'writeSaveStream',
            'id': 7,
            'bytes': Uint8List.fromList([3]),
          },
          {'method': 'closeSaveStream', 'id': 7},
        ]);
      });

      test('cuts a chunk bigger than the max chunk size in pieces', () async {
        mock();
        const megabyte = 1024 * 1024;

        await picker.saveFileFromStream(
          fileName: 'a.bin',
          mimeType: 'application/octet-stream',
          data: Stream.value(Uint8List(megabyte * 2 + 5)),
        );

        final sizes = [
          for (final call in calls.where((c) => c.method == 'writeSaveStream'))
            (call.arguments['bytes'] as Uint8List).length,
        ];
        expect(sizes, [megabyte, megabyte, 5]);
      });

      test('returns null and reads no data when the user cancels', () async {
        mock(id: null);
        final data = StreamController<Uint8List>();

        final uri = await picker.saveFileFromStream(
          fileName: 'a.bin',
          mimeType: 'application/octet-stream',
          data: data.stream,
        );

        expect(uri, isNull);
        expect(data.hasListener, isFalse);
        expect(sent().map((call) => call['method']), ['openSaveStream']);
      });

      test('aborts the save and rethrows when the stream fails', () async {
        mock();
        Stream<Uint8List> failing() async* {
          yield Uint8List(1);
          throw StateError('boom');
        }

        await expectLater(
          picker.saveFileFromStream(
            fileName: 'a.bin',
            mimeType: 'application/octet-stream',
            data: failing(),
          ),
          throwsStateError,
        );

        expect(sent().skip(1), [
          {
            'method': 'writeSaveStream',
            'id': 7,
            'bytes': Uint8List.fromList([0]),
          },
          {'method': 'abortSaveStream', 'id': 7},
        ]);
      });

      test('aborts the save when a chunk cannot be written', () async {
        messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
          calls.add(call);
          if (call.method == 'openSaveStream') return 7;
          if (call.method == 'writeSaveStream') {
            throw PlatformException(code: 'Error while saving file');
          }
          return null;
        });

        await expectLater(
          picker.saveFileFromStream(
            fileName: 'a.bin',
            mimeType: 'application/octet-stream',
            data: chunks([
              [1],
            ]),
          ),
          throwsA(isA<PlatformException>()),
        );

        expect(sent().last, {'method': 'abortSaveStream', 'id': 7});
      });

      test('reports picking and then done', () async {
        mock();
        final statuses = <FilePickerStatus>[];

        await picker.saveFileFromStream(
          fileName: 'a.bin',
          mimeType: 'application/octet-stream',
          data: chunks([
            [1],
          ]),
          onFileSaving: statuses.add,
        );

        expect(statuses, [FilePickerStatus.picking, FilePickerStatus.done]);
      });
    });

    group('status updates', () {
      late FilePickerAndroid picker;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      setUp(() {
        picker = FilePickerAndroid();
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

      test(
        'pickFile reports done after cancellation or a channel error',
        () async {
          var fail = false;
          messenger.setMockMethodCallHandler(picker.methodChannel, (
            call,
          ) async {
            if (fail) throw PlatformException(code: 'pick_failed');
            return null;
          });

          final statuses = <FilePickerStatus>[];
          expect(await picker.pickFiles(onFileLoading: statuses.add), isEmpty);
          expect(statuses.last, FilePickerStatus.done);

          fail = true;
          await expectLater(
            picker.pickFile(onFileLoading: statuses.add),
            throwsA(isA<PlatformException>()),
          );
          expect(statuses.last, FilePickerStatus.done);
        },
      );

      test(
        'a rejected overlapping pick keeps the first listener alive',
        () async {
          final pending = Completer<Object?>();
          MockStreamHandlerEventSink? sink;
          var calls = 0;
          messenger.setMockStreamHandler(
            picker.eventChannel,
            MockStreamHandler.inline(onListen: (_, events) => sink = events),
          );
          messenger.setMockMethodCallHandler(picker.methodChannel, (
            call,
          ) async {
            if (calls++ == 0) return pending.future;
            throw PlatformException(code: 'already_active');
          });
          final statuses = <FilePickerStatus>[];
          final first = picker.pickFiles(onFileLoading: statuses.add);
          await pumpEventQueue();
          await expectLater(
            FilePickerAndroid().pickFiles(onFileLoading: (_) {}),
            throwsA(isA<PlatformException>()),
          );
          sink!.success(true);
          await pumpEventQueue();
          expect(statuses, contains(FilePickerStatus.picking));
          pending.complete(null);
          await first;
          expect(statuses.last, FilePickerStatus.done);
        },
      );

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

    group('retrieveLostData', () {
      late FilePickerAndroid picker;

      void respondWith(Object? response) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              expect(call.method, 'retrieveLostData');
              return response;
            });
      }

      setUp(() => picker = FilePickerAndroid());
      tearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null),
      );

      test('returns null when nothing was lost', () async {
        respondWith(null);
        expect(await picker.retrieveLostData(), isNull);
      });

      test('returns the lost files', () async {
        respondWith({
          'files': [
            {'path': '/cache/a.pdf', 'name': 'a.pdf', 'size': 3},
            {'path': '/cache/b.png', 'name': 'b.png', 'size': 5},
          ],
        });

        final lost = await picker.retrieveLostData();

        expect(lost?.exception, isNull);
        expect(lost?.files.map((f) => f.path), [
          '/cache/a.pdf',
          '/cache/b.png',
        ]);
        expect(lost?.files.first.lengthSync(), 3);
      });

      test('returns the error raised while processing', () async {
        respondWith({
          'errorCode': 'out_of_memory',
          'errorMessage': 'Selected files are too large to process.',
        });

        final lost = await picker.retrieveLostData();

        expect(lost?.files, isEmpty);
        expect(lost?.exception?.code, 'out_of_memory');
        expect(
          lost?.exception?.message,
          'Selected files are too large to process.',
        );
      });
    });

    test('AndroidPlatformFile throws ArgumentError on empty path and uri', () {
      expect(() => AndroidPlatformFile.fromMap({}), throwsArgumentError);
    });

    test('AndroidPlatformFile equality and hashCode work correctly', () {
      final file1 = AndroidPlatformFile(
        name: 'test.txt',
        uri: Uri.file('/tmp/test.txt'),
      );
      final file2 = AndroidPlatformFile(
        name: 'test.txt',
        uri: Uri.file('/tmp/test.txt'),
      );
      expect(file1, equals(file2));
      expect(file1.hashCode, equals(file2.hashCode));
    });
  });
}
