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

    test('AndroidPlatformFile uses original SAF URI when path is absent', () {
      final file = AndroidPlatformFile.fromMap({
        'name': 'book.pdf',
        'identifier': 'content://com.android.providers.documents/document/42',
      });
      expect(
        file.uri,
        Uri.parse('content://com.android.providers.documents/document/42'),
      );
      expect(file.path, isNull);
    });

    test('AndroidPlatformFile supports an explicit URI-only result', () {
      final file = AndroidPlatformFile.fromMap({
        'name': 'book.pdf',
        'uri': 'content://media/external/file/1',
      });
      expect(file.uri.scheme, 'content');
    });

    test('AndroidPlatformFile rejects an absent original URI', () {
      expect(
        () =>
            AndroidPlatformFile.fromMap({'name': 'bad', 'identifier': 'null'}),
        throwsArgumentError,
      );
    });

    test('saveFile preserves content URIs and converts plain paths', () async {
      final picker = FilePickerAndroid();
      var value = 'content://com.android.providers.documents/document/42';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(picker.methodChannel, (call) async {
            expect(call.method, 'save');
            return value;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null),
      );

      final content = await picker.saveFile(
        fileName: 'book.pdf',
        bytes: Uint8List.fromList([1]),
        mimeType: 'application/pdf',
      );
      expect(content?.scheme, 'content');
      expect(content?.host, 'com.android.providers.documents');

      value = '/storage/emulated/0/Download/book.pdf';
      final local = await picker.saveFile(
        fileName: 'book.pdf',
        bytes: Uint8List.fromList([1]),
        mimeType: 'application/pdf',
      );
      expect(local?.scheme, 'file');
      expect(local, Uri.file(value));
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
