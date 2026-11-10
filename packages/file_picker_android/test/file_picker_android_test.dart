import 'dart:async';
import 'package:android_file_picker/android_file_picker.dart';
import 'package:android_file_picker/src/messages.g.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_file_picker_api.dart';

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
        const cachedPath =
            '/data/user/0/app/cache/file_picker/1/AdSenseReport (3) #1 ñ%.PDF';
        final picker = FilePickerAndroid(
          api: FakeFilePickerApi(
            (_, _) async => [
              PickedFileMessage(
                path: cachedPath,
                name: 'AdSenseReport (3) #1 ñ%.PDF',
                size: 0,
              ),
            ],
          ),
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
      void expectSent(Object? sent) {
        expect(
          sent,
          isA<SafOptionsMessage>()
              .having((o) => o.grant, 'grant', SafGrantMessage.lifetime)
              .having((o) => o.access, 'access', SafAccessMessage.readWrite)
              .having((o) => o.autoPersist, 'autoPersist', isFalse),
        );
      }

      late FakeFilePickerApi api;
      late FilePickerAndroid picker;

      setUp(() {
        api = FakeFilePickerApi();
        picker = FilePickerAndroid(api: api);
      });

      test('when picking files', () async {
        await picker.pickFiles(androidOptions: options);

        expectSent(api.calls.single.arguments[4]);
      });

      test('when picking a directory', () async {
        await picker.getDirectoryPath(androidOptions: options);

        expectSent(api.calls.single.arguments.single);
      });
    });

    test('saveFile returns the content URI of the saved document', () async {
      final picker = FilePickerAndroid(
        api: FakeFilePickerApi(
          (_, _) async =>
              'content://com.android.providers.downloads.documents/document/42',
        ),
      );

      final uri = await picker.saveFile(
        fileName: 'report.pdf',
        bytes: Uint8List.fromList([1]),
        mimeType: 'application/pdf',
      );

      expect(uri?.scheme, 'content');
      expect(
        uri.toString(),
        'content://com.android.providers.downloads.documents/document/42',
      );
    });

    // A failure must not look like a cancel (#2286).
    test('getDirectoryPath throws the failures it used to swallow', () async {
      final picker = FilePickerAndroid(
        api: FakeFilePickerApi(
          (_, _) async => throw PlatformException(code: 'already_active'),
        ),
      );

      await expectLater(
        picker.getDirectoryPath(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'already_active',
          ),
        ),
      );
    });

    group('status updates', () {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final eventChannel = FilePickerAndroid().eventChannel;

      setUp(() {
        // The status stream fails as soon as it is listened to.
        messenger.setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (_, events) => events.error(code: 'stream_error'),
          ),
        );
      });

      tearDown(() => messenger.setMockStreamHandler(eventChannel, null));

      test('a failing status stream does not fail the pick', () async {
        final picker = FilePickerAndroid(
          api: FakeFilePickerApi((method, arguments) async {
            // Let the stream error arrive while the pick is still running.
            await pumpEventQueue();
            return null;
          }),
        );

        expect(await picker.pickFiles(onFileLoading: (_) {}), isEmpty);
      });

      test(
        'pickFile reports done after cancellation or a channel error',
        () async {
          var fail = false;
          final picker = FilePickerAndroid(
            api: FakeFilePickerApi((method, arguments) async {
              if (fail) throw PlatformException(code: 'pick_failed');
              return null;
            }),
          );

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
            eventChannel,
            MockStreamHandler.inline(onListen: (_, events) => sink = events),
          );
          final api = FakeFilePickerApi((method, arguments) async {
            if (calls++ == 0) return pending.future;
            throw PlatformException(code: 'already_active');
          });
          final picker = FilePickerAndroid(api: api);
          final statuses = <FilePickerStatus>[];
          final first = picker.pickFiles(onFileLoading: statuses.add);
          await pumpEventQueue();
          await expectLater(
            FilePickerAndroid(api: api).pickFiles(onFileLoading: (_) {}),
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
        final picker = FilePickerAndroid(
          api: FakeFilePickerApi((method, arguments) async {
            throw PlatformException(code: 'save_failed');
          }),
        );
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

      void respondWith(LostDataMessage? response) {
        picker = FilePickerAndroid(
          api: FakeFilePickerApi((method, _) async {
            expect(method, 'retrieveLostData');
            return response;
          }),
        );
      }

      test('returns null when nothing was lost', () async {
        respondWith(null);
        expect(await picker.retrieveLostData(), isNull);
      });

      test('returns the lost files', () async {
        respondWith(
          LostDataMessage(
            files: [
              PickedFileMessage(path: '/cache/a.pdf', name: 'a.pdf', size: 3),
              PickedFileMessage(path: '/cache/b.png', name: 'b.png', size: 5),
            ],
          ),
        );

        final lost = await picker.retrieveLostData();

        expect(lost?.exception, isNull);
        expect(lost?.files.map((f) => f.path), [
          '/cache/a.pdf',
          '/cache/b.png',
        ]);
        expect(lost?.files.first.lengthSync(), 3);
      });

      test('returns the error raised while processing', () async {
        respondWith(
          LostDataMessage(
            errorCode: 'out_of_memory',
            errorMessage: 'Selected files are too large to process.',
          ),
        );

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
