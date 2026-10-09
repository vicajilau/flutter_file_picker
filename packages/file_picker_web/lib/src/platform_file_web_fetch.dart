import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart';

@JS('fetch')
external JSPromise<JSObject> _fetchJs(JSString url);

/// Interop extension type representing a Web `Response` JS object.
extension type _Response(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
  external JSPromise<Blob> blob();
}

/// Fetches the bytes of a web-only path (`blob:` or `data:` URL).
///
/// Returns the full file bytes (`Uint8List`) using `fetch(...).arrayBuffer()`
/// for `blob:` URLs, or parses `data:` URIs. Returns `null` if [path] is not a
/// web URL, so the caller can fall back to another source. Throws if the
/// content of a web URL cannot be read.
Future<Uint8List?> fetchBytesFromWebPath(String path) async {
  if (!_isWebPath(path)) return null;

  if (path.startsWith('data:')) {
    final uriData = Uri.parse(path).data;

    if (uriData == null) {
      return null;
    }

    return uriData.contentAsBytes();
  }

  final response = _Response(await _fetchJs(path.toJS).toDart);
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

bool _isWebPath(String path) =>
    path.startsWith('blob:') || path.startsWith('data:');

/// Attempts to create a streaming `Stream<Uint8List>` from a web-only path
/// (`blob:` or `data:` URL).
///
/// Returns `null` if [path] is not a web URL, so the caller can fall back to
/// another source. Read failures are emitted as errors on the stream.
Stream<Uint8List>? fetchStreamFromWebPath(String path) {
  if (!_isWebPath(path)) return null;

  return _streamFromWebPath(path);
}

/// The size of the chunks emitted by [streamBlobInChunks].
const int webStreamChunkSize = 1024 * 1024;

/// Reads a `blob:` or `data:` URL and emits its bytes in evenly sized chunks.
Stream<Uint8List> _streamFromWebPath(String path) async* {
  final response = _Response(await _fetchJs(path.toJS).toDart);
  yield* streamBlobInChunks(await response.blob().toDart);
}

/// Emits the content of [blob] in chunks of [webStreamChunkSize] bytes,
/// except the last one, which may be shorter.
Stream<Uint8List> streamBlobInChunks(Blob blob) async* {
  for (var start = 0; start < blob.size; start += webStreamChunkSize) {
    final end = min(start + webStreamChunkSize, blob.size);
    final buffer = await blob.slice(start, end).arrayBuffer().toDart;
    yield buffer.toDart.asUint8List();
  }
}
