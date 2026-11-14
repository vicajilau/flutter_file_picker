import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unsupported extension', () {
    const message =
        "Android has no MIME type for extension 'xyz'. "
        'Use FileType.any without allowedExtensions and validate the selected '
        'files in your app.';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late FilePickerAndroid picker;
    late bool listening;
    late int listenCount;
    late int cancelCount;
    late List<MethodCall> calls;
    late List<FilePickerStatus> statuses;

    setUp(() {
      picker = FilePickerAndroid();
      listening = false;
      listenCount = 0;
      cancelCount = 0;
      calls = [];
      statuses = [];
      messenger.setMockStreamHandler(
        picker.eventChannel,
        MockStreamHandler.inline(
          onListen: (_, _) {
            listening = true;
            listenCount++;
          },
          onCancel: (_) {
            listening = false;
            cancelCount++;
          },
        ),
      );
      messenger.setMockMethodCallHandler(picker.methodChannel, (call) async {
        calls.add(call);
        if (call.method == 'custom') {
          throw PlatformException(
            code: 'unsupported_extension',
            message: message,
          );
        }
        return [
          {'path': '/cache/report.xyz', 'name': 'report.xyz'},
        ];
      });
    });

    tearDown(() {
      messenger.setMockStreamHandler(picker.eventChannel, null);
      messenger.setMockMethodCallHandler(picker.methodChannel, null);
    });

    Future<void> verifyUnsupportedPick(
      Future<Object?> result, {
      required bool multiple,
    }) async {
      await expectLater(
        result,
        throwsA(
          isA<PlatformException>()
              .having((error) => error.code, 'code', 'unsupported_extension')
              .having((error) => error.message, 'message', message),
        ),
      );
      expect(calls.single.arguments['allowedExtensions'], ['zip', 'xyz']);
      expect(calls.single.arguments['allowMultipleSelection'], multiple);
      expect(statuses, [FilePickerStatus.done]);
      expect(listening, isFalse);
      expect(listenCount, 1);
      expect(cancelCount, 1);

      final file = await picker.pickFile(type: FileType.any);
      expect(file?.name, 'report.xyz');
      expect(calls.last.method, 'any');
      expect(calls.last.arguments['allowedExtensions'], isNull);
    }

    test('reaches a single pick and releases the status listener', () async {
      await verifyUnsupportedPick(
        picker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['zip', 'xyz'],
          onFileLoading: statuses.add,
        ),
        multiple: false,
      );
    });

    test('reaches a multi pick and releases the status listener', () async {
      await verifyUnsupportedPick(
        picker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip', 'xyz'],
          onFileLoading: statuses.add,
        ),
        multiple: true,
      );
    });
  });
}
