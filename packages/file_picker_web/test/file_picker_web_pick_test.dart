@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:cross_file_web/cross_file_web.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

void main() {
  setUpAll(() {
    FilePickerWeb.registerWith(webPluginRegistrar);
    CrossFileWeb.registerWith(webPluginRegistrar);
  });

  Future<List<PlatformFile>> pickFiles(List<File> files) {
    final result = FilePickerPlatform.instance.pickFiles();

    final input =
        document.querySelector('flt-file-picker-inputs input')!
            as HTMLInputElement;
    final transfer = DataTransfer();
    for (final file in files) {
      transfer.items.add(file);
    }
    input.files = transfer.files;
    input.dispatchEvent(Event('change'));

    return result;
  }

  File fileWith({required String name, required String content}) =>
      File([utf8.encode(content).toJS].toJS, name);

  test(
    'three picks supersede old sessions without browser cancel events',
    () async {
      const options = FilePickerWebOptions(cancelUploadOnWindowBlur: false);
      final statuses = List.generate(3, (_) => <FilePickerStatus>[]);
      HTMLInputElement input() =>
          document.querySelector('flt-file-picker-inputs input')!
              as HTMLInputElement;
      final first = FilePickerPlatform.instance.pickFiles(
        webOptions: options,
        onFileLoading: statuses[0].add,
      );
      final firstInput = input();
      final second = FilePickerPlatform.instance.pickFiles(
        webOptions: options,
        onFileLoading: statuses[1].add,
      );
      final secondInput = input();
      expect(await first, isEmpty);
      final third = FilePickerPlatform.instance.pickFiles(
        webOptions: options,
        onFileLoading: statuses[2].add,
      );
      final thirdInput = input();
      expect(await second.timeout(const Duration(seconds: 2)), isEmpty);
      expect(firstInput.isConnected, isFalse);
      expect(secondInput.isConnected, isFalse);
      firstInput.dispatchEvent(Event('cancel'));
      secondInput.dispatchEvent(Event('change'));
      expect(input(), thirdInput);
      thirdInput.dispatchEvent(Event('cancel'));
      expect(await third, isEmpty);
      for (final values in statuses) {
        expect(values, [FilePickerStatus.picking, FilePickerStatus.done]);
      }
    },
  );

  test('invalid replacement leaves the current picker usable', () async {
    final pending = FilePickerPlatform.instance.pickFiles(
      webOptions: const FilePickerWebOptions(cancelUploadOnWindowBlur: false),
    );
    final input =
        document.querySelector('flt-file-picker-inputs input')!
            as HTMLInputElement;
    await expectLater(
      FilePickerPlatform.instance.pickFiles(type: FileType.custom),
      throwsArgumentError,
    );
    expect(document.querySelector('flt-file-picker-inputs input'), input);
    final transfer = DataTransfer();
    transfer.items.add(fileWith(name: 'kept.txt', content: 'kept'));
    input.files = transfer.files;
    input.dispatchEvent(Event('change'));
    expect((await pending).single.name, 'kept.txt');
  });

  test(
    'a replacement started by done is not orphaned by the outer request',
    () async {
      Future<List<PlatformFile>>? replacement;
      final first = FilePickerPlatform.instance.pickFiles(
        onFileLoading: (status) {
          if (status == FilePickerStatus.done) {
            replacement = FilePickerPlatform.instance.pickFiles();
          }
        },
      );
      final second = FilePickerPlatform.instance.pickFiles();
      expect(await first, isEmpty);
      expect(await second.timeout(const Duration(seconds: 2)), isEmpty);
      final input =
          document.querySelector('flt-file-picker-inputs input')!
              as HTMLInputElement;
      input.dispatchEvent(Event('cancel'));
      expect(await replacement!, isEmpty);
    },
  );

  test('media picks use a valid comma-separated accept filter', () async {
    final result = FilePickerPlatform.instance.pickFiles(type: FileType.media);
    final input =
        document.querySelector('flt-file-picker-inputs input')!
            as HTMLInputElement;
    expect(input.accept, 'video/*,image/*');
    input.dispatchEvent(Event('cancel'));
    expect(await result, isEmpty);
  });

  test('picked files point at a readable blob: URL', () async {
    final files = await pickFiles([fileWith(name: 'a.txt', content: 'hello')]);

    expect(files.single.uri.scheme, 'blob');
    expect(utf8.decode(await files.single.readAsBytes()), 'hello');
  });

  test('an empty picked file still gets a blob: URL', () async {
    final files = await pickFiles([fileWith(name: 'empty.txt', content: '')]);

    expect(files.single.uri.scheme, 'blob');
    expect(await files.single.readAsBytes(), isEmpty);
  });

  test('picked files stream evenly sized chunks', () async {
    final content = 'a' * (WebPlatformFile.streamChunkSize + 10);
    final files = await pickFiles([
      fileWith(name: 'big.txt', content: content),
    ]);

    final chunks = await files.single.readAsByteStream().toList();
    expect(chunks.map((chunk) => chunk.length), [
      WebPlatformFile.streamChunkSize,
      10,
    ]);
  });
}
