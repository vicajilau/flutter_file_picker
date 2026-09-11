import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

base class TestPlatformFile extends PlatformFile {
  TestPlatformFile({required this.name, required String path})
    : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(path ?? '');

  @override
  int? lengthSync() => 100;

  @override
  Future<int?> length() async => 100;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

class MockFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  DarwinOptions? lastDarwinOptions;
  bool skipEntitlementsChecksCalled = false;

  @override
  Future<void> skipEntitlementsChecks() async {
    skipEntitlementsChecksCalled = true;
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus status)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastDarwinOptions = darwinOptions;
    return TestPlatformFile(
      name: 'test_file.txt',
      path: '/path/to/test_file.txt',
    );
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus status)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastDarwinOptions = darwinOptions;
    return [
      TestPlatformFile(name: 'test_file.txt', path: '/path/to/test_file.txt'),
    ];
  }
}

void main() {
  test(
    'FilePicker.pickFiles delegates to FilePickerPlatform.instance.pickFiles',
    () async {
      final mockPlatform = MockFilePickerPlatform();
      FilePickerPlatform.instance = mockPlatform;

      final files = await FilePicker.pickFiles();
      expect(files, isNotEmpty);
      expect(files.first.name, 'test_file.txt');
      expect(files.first.path, '/path/to/test_file.txt');
    },
  );

  test('FilePicker.skipEntitlementsChecks delegates to '
      'FilePickerPlatform.instance.skipEntitlementsChecks', () async {
    final mockPlatform = MockFilePickerPlatform();
    FilePickerPlatform.instance = mockPlatform;

    await FilePicker.skipEntitlementsChecks();

    expect(mockPlatform.skipEntitlementsChecksCalled, isTrue);
  });

  group('FilePicker Darwin options', () {
    late MockFilePickerPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockFilePickerPlatform();
      FilePickerPlatform.instance = mockPlatform;
    });

    test('pickFiles forwards automatic by default', () async {
      final files = await FilePicker.pickFiles();

      expect(files, isNotEmpty);
      expect(files.first.name, 'test_file.txt');
      expect(files.first.path, '/path/to/test_file.txt');
      expect(
        mockPlatform.lastDarwinOptions?.assetRepresentationMode,
        DarwinAssetRepresentationMode.automatic,
      );
    });

    test('pickFile and pickFiles forward every representation mode', () async {
      for (final mode in DarwinAssetRepresentationMode.values) {
        final options = DarwinOptions(assetRepresentationMode: mode);

        await FilePicker.pickFile(darwinOptions: options);
        expect(mockPlatform.lastDarwinOptions, same(options));

        await FilePicker.pickFiles(darwinOptions: options);
        expect(mockPlatform.lastDarwinOptions, same(options));
      }
    });

    test('rejects non-automatic modes with compression', () {
      for (final mode in [
        DarwinAssetRepresentationMode.current,
        DarwinAssetRepresentationMode.compatible,
      ]) {
        expect(
          () => FilePicker.pickFiles(
            compressionQuality: 50,
            darwinOptions: DarwinOptions(assetRepresentationMode: mode),
          ),
          throwsArgumentError,
        );
      }
    });

    test('allows automatic mode with compression', () async {
      await FilePicker.pickFiles(
        compressionQuality: 50,
        darwinOptions: const DarwinOptions(),
      );

      expect(
        mockPlatform.lastDarwinOptions?.assetRepresentationMode,
        DarwinAssetRepresentationMode.automatic,
      );
    });
  });
}
