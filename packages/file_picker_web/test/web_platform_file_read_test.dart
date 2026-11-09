@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart';

void main() {
  final content = Uint8List.fromList(utf8.encode('hello file_picker'));

  String createBlobUrl() => URL.createObjectURL(Blob([content.toJS].toJS));

  WebPlatformFile fileAt(String url) =>
      WebPlatformFile(name: 'a.txt', uri: Uri.parse(url));

  test(
    'native browser File supports direct reads without an object URL',
    () async {
      final native = File([content.toJS].toJS, 'lazy.txt');
      final file = WebPlatformFile(
        name: native.name,
        sourceFile: native,
        bytesLength: native.size,
      );

      expect(file.hasCreatedObjectUrl, isFalse);
      expect(await file.readAsBytes(), content);
      final chunks = await file.readAsByteStream().toList();
      expect(chunks.expand((chunk) => chunk).toList(), content);
      expect(file.hasCreatedObjectUrl, isFalse);

      final firstUri = file.uri;
      expect(firstUri.scheme, 'blob');
      expect(file.hasCreatedObjectUrl, isTrue);
      file.releaseObjectUrl();
      expect(file.hasCreatedObjectUrl, isFalse);
      expect(await file.readAsBytes(), content);
      final nextUri = file.uri;
      expect(nextUri, isNot(firstUri));
      file.releaseObjectUrl();
    },
  );

  test('releasing a lazy URL preserves set membership and file identity', () {
    final native = File([content.toJS].toJS, 'lazy.txt');
    final file = WebPlatformFile(name: native.name, sourceFile: native);
    final files = {file};
    final initialHash = file.hashCode;
    expect(file.hasCreatedObjectUrl, isFalse);
    final firstUri = file.uri;
    file.releaseObjectUrl();
    expect(file.uri, isNot(firstUri));
    expect(file.hashCode, initialHash);
    expect(files.contains(file), isTrue);
    expect(WebPlatformFile(name: native.name, sourceFile: native), file);
    file.releaseObjectUrl();
  });

  test(
    'explicit URI identity is symmetric and independent of source files',
    () {
      final native = File([content.toJS].toJS, 'lazy.txt');
      final lazy = WebPlatformFile(name: native.name, sourceFile: native);
      final uri = lazy.uri;
      final explicit = WebPlatformFile(name: native.name, uri: uri);
      final both = WebPlatformFile(
        name: native.name,
        uri: uri,
        sourceFile: native,
      );
      expect(lazy == explicit, isFalse);
      expect(explicit == lazy, isFalse);
      expect(explicit, both);
      expect(both, explicit);
      expect(explicit.hashCode, both.hashCode);
      lazy.releaseObjectUrl();
      explicit.releaseObjectUrl();
      expect(explicit.uri, uri);
    },
  );

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

  test('readAsByteStream() emits evenly sized chunks', () async {
    const size =
        WebPlatformFile.streamChunkSize * 2 +
        WebPlatformFile.streamChunkSize ~/ 2;
    // 251 is prime, so the byte pattern does not line up with the chunk
    // boundaries (a multiple of 256) and swapped or repeated chunks still fail.
    final large = Uint8List.fromList(List.generate(size, (i) => i % 251));
    final url = URL.createObjectURL(Blob([large.toJS].toJS));
    addTearDown(() => URL.revokeObjectURL(url));

    final chunks = await fileAt(url).readAsByteStream().toList();

    expect(chunks.map((chunk) => chunk.length), [
      WebPlatformFile.streamChunkSize,
      WebPlatformFile.streamChunkSize,
      WebPlatformFile.streamChunkSize ~/ 2,
    ]);
    expect(chunks.expand((chunk) => chunk).toList(), large);
  });

  test('readAsByteStream() emits nothing for an empty file', () async {
    final url = URL.createObjectURL(Blob(<JSAny>[].toJS));
    addTearDown(() => URL.revokeObjectURL(url));

    expect(await fileAt(url).readAsByteStream().toList(), isEmpty);
  });
}
