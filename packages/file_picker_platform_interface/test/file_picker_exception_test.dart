import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FilePickerErrorCode mapped(String nativeCode, {bool isSave = false}) {
    return FilePickerException.fromPlatformException(
      PlatformException(code: nativeCode),
      isSave: isSave,
    ).errorCode;
  }

  group('FilePickerErrorCode', () {
    test('every value has its own code', () {
      final codes = FilePickerErrorCode.values.map((value) => value.code);
      expect(codes.toSet(), hasLength(FilePickerErrorCode.values.length));
    });
  });

  group('FilePickerException', () {
    test(
      'reports the code of its error code as the PlatformException code',
      () {
        final exception = FilePickerException(
          errorCode: FilePickerErrorCode.outOfMemory,
          message: 'no memory',
        );

        expect(exception, isA<PlatformException>());
        expect(exception.code, 'out_of_memory');
        expect(exception.message, 'no memory');
      },
    );

    test('maps the Android codes', () {
      expect(mapped('already_active'), FilePickerErrorCode.alreadyActive);
      expect(mapped('unknown_path'), FilePickerErrorCode.loadFailed);
      expect(mapped('unknown_activity'), FilePickerErrorCode.loadFailed);
      expect(mapped('unknown_result'), FilePickerErrorCode.loadFailed);
      expect(mapped('invalid_type'), FilePickerErrorCode.loadFailed);
      expect(mapped('file_picker_error'), FilePickerErrorCode.loadFailed);
      expect(
        mapped('explorer_not_found'),
        FilePickerErrorCode.noPickerAvailable,
      );
      expect(mapped('out_of_memory'), FilePickerErrorCode.outOfMemory);
      expect(
        mapped('unsupported_extension'),
        FilePickerErrorCode.unsupportedExtension,
      );
      expect(mapped('Error while saving file'), FilePickerErrorCode.saveFailed);
    });

    test('maps the iOS and macOS codes', () {
      expect(mapped('multiple_request'), FilePickerErrorCode.alreadyActive);
      expect(mapped('load_failed'), FilePickerErrorCode.loadFailed);
      expect(mapped('invalid_arguments'), FilePickerErrorCode.invalidArguments);
      expect(
        mapped('Unsupported file extension'),
        FilePickerErrorCode.unsupportedExtension,
      );
      expect(mapped('window_not_found'), FilePickerErrorCode.windowNotFound);
      expect(mapped('save_file_error'), FilePickerErrorCode.saveFailed);
      for (final code in [
        'ENTITLEMENT_NOT_FOUND',
        'ENTITLEMENT_REQUIRED_WRITE',
        'ENTITLEMENT_CHECK_FAILED',
      ]) {
        expect(mapped(code), FilePickerErrorCode.missingEntitlement);
      }
    });

    test(
      'a failure that reads as a failed pick is a failed save for a save',
      () {
        for (final code in [
          'unknown_path',
          'unknown_activity',
          'unknown_result',
          'invalid_type',
          'file_picker_error',
          'load_failed',
        ]) {
          expect(
            mapped(code, isSave: true),
            FilePickerErrorCode.saveFailed,
            reason: code,
          );
        }
        expect(
          mapped('already_active', isSave: true),
          FilePickerErrorCode.alreadyActive,
        );
      },
    );

    test('an unknown code keeps the native code in the message', () {
      final exception = FilePickerException.fromPlatformException(
        PlatformException(code: 'no_activity', message: 'Plugin not ready'),
      );

      expect(exception.errorCode, FilePickerErrorCode.unknown);
      expect(exception.message, 'no_activity: Plugin not ready');
    });

    test('keeps the message, the details and the stack trace', () {
      final exception = FilePickerException.fromPlatformException(
        PlatformException(
          code: 'load_failed',
          message: 'one file failed',
          details: [
            {'name': 'a.jpg'},
          ],
          stacktrace: 'native stack',
        ),
      );

      expect(exception.message, 'one file failed');
      expect(exception.details, [
        {'name': 'a.jpg'},
      ]);
      expect(exception.stacktrace, 'native stack');
    });

    test('is not wrapped twice', () {
      final exception = FilePickerException(
        errorCode: FilePickerErrorCode.windowNotFound,
      );

      expect(
        identical(
          FilePickerException.fromPlatformException(exception),
          exception,
        ),
        isTrue,
      );
    });
  });

  group('FilePickerException.guard', () {
    test('returns the result of the action', () async {
      expect(await FilePickerException.guard(() async => 7), 7);
    });

    test('turns a PlatformException into a FilePickerException', () async {
      await expectLater(
        FilePickerException.guard<void>(
          () async => throw PlatformException(code: 'multiple_request'),
        ),
        throwsA(
          isA<FilePickerException>().having(
            (e) => e.errorCode,
            'errorCode',
            FilePickerErrorCode.alreadyActive,
          ),
        ),
      );
    });

    test('with isSave, a failed pick becomes saveFailed', () async {
      await expectLater(
        FilePickerException.guard<void>(
          () async => throw PlatformException(code: 'unknown_result'),
          isSave: true,
        ),
        throwsA(
          isA<FilePickerException>().having(
            (e) => e.errorCode,
            'errorCode',
            FilePickerErrorCode.saveFailed,
          ),
        ),
      );
    });

    test('lets other errors through', () async {
      await expectLater(
        FilePickerException.guard<void>(() async => throw ArgumentError('x')),
        throwsArgumentError,
      );
      await expectLater(
        FilePickerException.guard<void>(
          () async => throw MissingPluginException(),
        ),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}
