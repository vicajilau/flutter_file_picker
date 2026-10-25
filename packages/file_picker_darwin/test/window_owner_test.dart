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

  test('each instance sends its own view, including view zero', () async {
    await Future.wait([
      FilePickerDarwin(viewId: 0).getDirectoryPath(),
      FilePickerDarwin(viewId: 99).getDirectoryPath(),
    ]);
    await FilePickerDarwin().getDirectoryPath();
    expect(arguments[0]['viewId'], 0);
    expect(arguments[1]['viewId'], 99);
    expect(arguments[2], isNot(contains('viewId')));
  });

  test('every picker method sends the view', () async {
    final picker = FilePickerDarwin(viewId: 7);
    await picker.pickFiles();
    await picker.pickFileAndDirectoryPaths();
    await picker.getDirectoryPath();
    await picker.saveFile(
      fileName: 'a.txt',
      bytes: Uint8List(0),
      mimeType: 'text/plain',
    );
    expect(arguments.map((a) => a['viewId']), [7, 7, 7, 7]);
  });

  test('a missing window is an error, not a cancel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'window_not_found');
    });
    final picker = FilePickerDarwin(viewId: 3);
    for (final pick in <Future<Object?> Function()>[
      picker.getDirectoryPath,
      picker.pickFileAndDirectoryPaths,
      picker.pickFiles,
      () => picker.saveFile(
        fileName: 'a.txt',
        bytes: Uint8List(0),
        mimeType: 'text/plain',
      ),
    ]) {
      await expectLater(
        pick(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'window_not_found',
          ),
        ),
      );
    }
  });
}
