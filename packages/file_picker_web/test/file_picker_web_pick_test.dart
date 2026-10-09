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
