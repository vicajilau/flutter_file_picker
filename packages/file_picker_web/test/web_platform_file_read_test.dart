@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cross_file_web/cross_file_web.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

void main() {
  setUpAll(() => CrossFileWeb.registerWith(webPluginRegistrar));

  final content = Uint8List.fromList(utf8.encode('hello file_picker'));

  String createBlobUrl() => URL.createObjectURL(Blob([content.toJS].toJS));

  WebPlatformFile fileAt(String url) =>
      WebPlatformFile(name: 'a.txt', uri: Uri.parse(url));

  test('readAsBytes() reads a blob URL', () async {
    final url = createBlobUrl();
    addTearDown(() => URL.revokeObjectURL(url));

    expect(await fileAt(url).readAsBytes(), content);
  });

  test('readAsBytes() throws when the blob URL cannot be read', () async {
    final url = createBlobUrl();
    URL.revokeObjectURL(url);

    await expectLater(fileAt(url).readAsBytes(), throwsA(anything));
  });

  test('readAsByteStream() reads a blob URL', () async {
    final url = createBlobUrl();
    addTearDown(() => URL.revokeObjectURL(url));

    final chunks = await fileAt(url).readAsByteStream().toList();
    expect(chunks.expand((chunk) => chunk).toList(), content);
  });

  test(
    'readAsByteStream() emits an error when the blob URL cannot be read',
    () async {
      final url = createBlobUrl();
      URL.revokeObjectURL(url);

      await expectLater(
        fileAt(url).readAsByteStream().toList(),
        throwsA(anything),
      );
    },
  );

  test('readAsBytes() and readAsByteStream() read a data URL', () async {
    final url = Uri.dataFromBytes(content).toString();

    expect(await fileAt(url).readAsBytes(), content);
    final chunks = await fileAt(url).readAsByteStream().toList();
    expect(chunks.expand((chunk) => chunk).toList(), content);
  });
}
