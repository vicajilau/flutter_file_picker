import 'dart:js_interop';
import 'dart:typed_data';

import 'byte_accumulator.dart';
import 'byte_accumulator_builder.dart';

/// On the web, every chunk is a view over a JavaScript `ArrayBuffer`.
///
/// Concatenating them with [BytesBuilder.takeBytes] copies each byte across
/// the JavaScript/WebAssembly boundary, which under dart2wasm blocks the UI
/// for close to a second per 200 MB. Copying them into a JavaScript
/// `Uint8Array` with its native `set()` keeps the data in browser memory and
/// spreads the work across chunks, so the UI stays smooth on both dart2js
/// and dart2wasm.
ByteAccumulator createByteAccumulator(int? length) =>
    length == null ? BuilderByteAccumulator() : _JSByteAccumulator(length);

class _JSByteAccumulator implements ByteAccumulator {
  _JSByteAccumulator(int length) : _bytes = JSUint8Array.withLength(length);

  final JSUint8Array _bytes;
  int _offset = 0;

  /// Takes over if the stream is longer than the announced length.
  BuilderByteAccumulator? _overflow;

  @override
  void add(Uint8List chunk) {
    final overflow = _overflow;
    if (overflow != null) {
      overflow.add(chunk);
      return;
    }
    if (_offset + chunk.length > _bytes.length) {
      _overflow = BuilderByteAccumulator()
        ..add(Uint8List.sublistView(_bytes.toDart, 0, _offset))
        ..add(chunk);
      return;
    }
    _bytes.set(chunk.toJS, _offset);
    _offset += chunk.length;
  }

  @override
  Uint8List takeBytes() {
    final overflow = _overflow;
    if (overflow != null) return overflow.takeBytes();
    final bytes = _bytes.toDart;
    return _offset == bytes.length
        ? bytes
        : Uint8List.sublistView(bytes, 0, _offset);
  }
}

extension on JSUint8Array {
  external int get length;

  external void set(JSUint8Array source, int offset);
}
