@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

void main() {
  setUpAll(() => FilePickerWeb.registerWith(webPluginRegistrar));

  Future<List<PlatformFile>> pickFiles(
    List<File> files, {
    WebOptions webOptions = const WebOptions(),
  }) {
    final result = FilePickerPlatform.instance.pickFiles(
      webOptions: webOptions,
    );

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

  test('selected files do not create a URL until a caller needs it', () async {
    final files = await pickFiles([
      fileWith(name: 'book.pdf', content: 'data'),
    ]);
    final file = files.single as WebPlatformFile;
    expect(file.hasCreatedObjectUrl, isFalse);
    expect(utf8.decode(await file.readAsBytes()), 'data');
    expect(file.hasCreatedObjectUrl, isFalse);
    expect(file.uri.scheme, 'blob');
    expect(file.hasCreatedObjectUrl, isTrue);
    file.releaseObjectUrl();
  });

  test('picked files point at a readable blob: URL', () async {
    final files = await pickFiles([fileWith(name: 'a.txt', content: 'hello')]);

    expect(files.single.uri.scheme, 'blob');
    expect(utf8.decode(await files.single.readAsBytes()), 'hello');
  });

  test(
    'default lazy loading still supports readAsBytes after picking',
    () async {
      final files = await pickFiles([
        fileWith(name: 'chapter.txt', content: 'Large book contents'),
      ]);
      expect(files.single.lengthSync(), 'Large book contents'.length);
      expect(
        utf8.decode(await files.single.readAsBytes()),
        'Large book contents',
      );
    },
  );

  test('explicit eager loading remains supported for compatibility', () async {
    final files = await pickFiles(
      [fileWith(name: 'eager.txt', content: 'eager')],
      // ignore: deprecated_member_use_from_same_package
      webOptions: const FilePickerWebOptions(withData: true),
    );
    expect(utf8.decode(await files.single.readAsBytes()), 'eager');
  });

  test('an empty picked file still gets a blob: URL', () async {
    final files = await pickFiles([fileWith(name: 'empty.txt', content: '')]);

    expect(files.single.uri.scheme, 'blob');
    expect(await files.single.readAsBytes(), isEmpty);
  });

  Future<void> expectEvenChunks(List<PlatformFile> files) async {
    final chunks = await files.single.readAsByteStream().toList();
    expect(chunks.map((chunk) => chunk.length), [
      WebPlatformFile.streamChunkSize,
      10,
    ]);
  }

  String bigContent() => 'a' * (WebPlatformFile.streamChunkSize + 10);

  test('picked files stream evenly sized chunks', () async {
    await expectEvenChunks(
      await pickFiles([fileWith(name: 'big.txt', content: bigContent())]),
    );
  });

  test('picked files stream evenly sized chunks with withReadStream', () async {
    await expectEvenChunks(
      await pickFiles(
        [fileWith(name: 'big.txt', content: bigContent())],
        // ignore: deprecated_member_use_from_same_package
        webOptions: const FilePickerWebOptions(withReadStream: true),
      ),
    );
  });
}
