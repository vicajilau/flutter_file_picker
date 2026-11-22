import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class ExtendsFilePickerPlatform extends FilePickerPlatform {}

/// Answers [getDirectoryPath] with [path], and records how it was called.
class DirectoryPlatform extends FilePickerPlatform {
  DirectoryPlatform(this.path, {this.error});

  final String? path;
  final Object? error;
  String? dialogTitle;
  String? initialDirectory;
  AndroidOptions? androidOptions;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.dialogTitle = dialogTitle;
    this.initialDirectory = initialDirectory;
    this.androidOptions = androidOptions;
    if (error != null) throw error!;
    return path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerPlatformInterface', () {
    test('Can be extended', () {
      final ExtendsFilePickerPlatform instance = ExtendsFilePickerPlatform();
      expect(instance, isA<FilePickerPlatform>());
    });

    test('Default instance is MethodChannelFilePicker', () {
      expect(FilePickerPlatform.instance, isA<MethodChannelFilePicker>());
    });

    group('pickDirectory', () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test('turns the path of getDirectoryPath into a file URI', () async {
        final uri = await DirectoryPlatform(
          '/home/me/Documents',
        ).pickDirectory();

        expect(uri?.scheme, 'file');
        expect(uri?.toFilePath(), '/home/me/Documents/');
      });

      test('keeps spaces and non ASCII characters of the path', () async {
        final uri = await DirectoryPlatform(
          '/home/me/Mis documentos/ñ%1',
        ).pickDirectory();

        expect(uri?.toFilePath(), '/home/me/Mis documentos/ñ%1/');
      });

      test('reads the path as a Windows path on Windows', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;

        final uri = await DirectoryPlatform(
          r'C:\Users\me\Documents',
        ).pickDirectory();

        expect(uri?.toFilePath(windows: true), r'C:\Users\me\Documents\');
      });

      test('returns null when the user cancels', () async {
        expect(await DirectoryPlatform(null).pickDirectory(), isNull);
      });

      test('passes its arguments on to getDirectoryPath', () async {
        final platform = DirectoryPlatform('/dir');
        const options = AndroidOptions();

        await platform.pickDirectory(
          dialogTitle: 'Pick a folder',
          initialDirectory: '/start',
          androidOptions: options,
        );

        expect(platform.dialogTitle, 'Pick a folder');
        expect(platform.initialDirectory, '/start');
        expect(platform.androidOptions, same(options));
      });

      test('lets the failures of getDirectoryPath through', () async {
        final platform = DirectoryPlatform(null, error: StateError('failed'));

        await expectLater(platform.pickDirectory(), throwsStateError);
      });

      test('throws on the default instance, which implements nothing', () {
        expect(
          () => ExtendsFilePickerPlatform().pickDirectory(),
          throwsUnimplementedError,
        );
      });
    });

    group('saveFileFromStream', () {
      test('supportsSaveFileFromStream returns false by default', () {
        expect(ExtendsFilePickerPlatform().supportsSaveFileFromStream, isFalse);
      });

      test('throws an UnsupportedError on the default instance', () {
        expect(
          () => ExtendsFilePickerPlatform().saveFileFromStream(
            fileName: 'a.bin',
            data: const Stream.empty(),
            mimeType: 'application/octet-stream',
          ),
          throwsUnsupportedError,
        );
      });
    });

    test('Can set instance', () {
      final ExtendsFilePickerPlatform instance = ExtendsFilePickerPlatform();
      FilePickerPlatform.instance = instance;
      expect(FilePickerPlatform.instance, instance);
    });

    test('Default implementations throw UnimplementedError or no-op', () async {
      final ExtendsFilePickerPlatform instance = ExtendsFilePickerPlatform();
      expect(() => instance.pickFile(), throwsUnimplementedError);
      expect(() => instance.pickFiles(), throwsUnimplementedError);
      expect(
        () => instance.pickFileAndDirectoryPaths(),
        throwsUnimplementedError,
      );
      expect(instance.clearTemporaryFiles(), completes);
      expect(instance.skipEntitlementsChecks(), completes);
      expect(() => instance.getDirectoryPath(), throwsUnimplementedError);
      expect(
        () => instance.saveFile(
          fileName: 'test.txt',
          bytes: Uint8List(0),
          mimeType: 'text/plain',
        ),
        throwsUnimplementedError,
      );
    });
  });
}
