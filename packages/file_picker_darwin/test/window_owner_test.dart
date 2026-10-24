import 'dart:async';

import 'package:file_picker_darwin/file_picker_darwin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<Object?, Object?>> arguments;
  setUp(() {
    arguments = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      arguments.add(call.arguments as Map<Object?, Object?>);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'concurrent pickers retain their own origin, including view zero',
    () async {
      final picker = FilePickerDarwin();
      final firstReady = Completer<void>();
      final secondReady = Completer<void>();
      final first = FilePickerDarwin.withWindow(0, () async {
        await firstReady.future;
        return picker.getDirectoryPath();
      });
      final second = FilePickerDarwin.withWindow(99, () async {
        await secondReady.future;
        return picker.getDirectoryPath();
      });
      secondReady.complete();
      await second;
      firstReady.complete();
      await first;
      await picker.getDirectoryPath();
      expect(arguments[0]['viewId'], 99);
      expect(arguments[1]['viewId'], 0);
      expect(arguments[2], isNot(contains('viewId')));
    },
  );
}
