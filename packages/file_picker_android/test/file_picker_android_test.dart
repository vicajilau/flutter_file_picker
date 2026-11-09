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
