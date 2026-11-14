import 'dart:js_interop';
import 'dart:typed_data';

import 'byte_accumulator.dart';

/// On the web, every chunk is a view over a JavaScript `ArrayBuffer`.
///
/// Concatenating them with [BytesBuilder.takeBytes] copies each byte across
/// the JavaScript/WebAssembly boundary, which under dart2wasm blocks the UI
/// for close to a second per 200 MB. Copying them into a JavaScript
/// `Uint8Array` with its native `set()` keeps the data in browser memory and
/// spreads the work across chunks, so the UI stays smooth on both dart2js
/// and dart2wasm.
ByteAccumulator createByteAccumulator(int? length) =>
    _JSByteAccumulator(length ?? _defaultCapacity);

/// Initial buffer size when the stream length is unknown.
const _defaultCapacity = 64 * 1024;

class _JSByteAccumulator implements ByteAccumulator {
  _JSByteAccumulator(int capacity) : _bytes = JSUint8Array.withLength(capacity);

  JSUint8Array _bytes;
  int _offset = 0;

  @override
  void add(Uint8List chunk) {
    final end = _offset + chunk.length;
    if (end > _bytes.length) _grow(end);
    _bytes.set(chunk.toJS, _offset);
    _offset = end;
  }

  /// Doubles the buffer until it holds [minCapacity] bytes. The copy runs in
  /// JavaScript, so the bytes never cross into WebAssembly memory.
  void _grow(int minCapacity) {
    var capacity = _bytes.length < 1 ? 1 : _bytes.length;
    while (capacity < minCapacity) {
      capacity *= 2;
    }
    final bytes = JSUint8Array.withLength(capacity);
    bytes.set(_bytes.subarray(0, _offset), 0);
    _bytes = bytes;
  }

  @override
  Uint8List takeBytes() {
    final bytes = _offset == _bytes.length
        ? _bytes
        : _bytes.subarray(0, _offset);
    return bytes.toDart;
  }
}

// dart:js_interop does not expose these Uint8Array members yet.
extension on JSUint8Array {
  external int get length;

  external void set(JSUint8Array source, int offset);

  external JSUint8Array subarray(int start, int end);
}
