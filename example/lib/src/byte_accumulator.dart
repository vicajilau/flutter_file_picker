import 'dart:typed_data';

import 'byte_accumulator_builder.dart'
    if (dart.library.js_interop) 'byte_accumulator_web.dart'
    as impl;

/// Collects the chunks of a byte stream, such as
/// `PlatformFile.readAsByteStream()`, into a single [Uint8List].
abstract interface class ByteAccumulator {
  /// Creates an accumulator for a stream of [length] bytes, if known upfront.
  ///
  /// [length] is only a hint: the accumulator still returns every added byte
  /// if the stream turns out to be shorter or longer.
  factory ByteAccumulator({int? length}) => impl.createByteAccumulator(length);

  /// Appends [chunk]. The accumulator may keep a reference to it.
  void add(Uint8List chunk);

  /// Returns every byte added so far, in order.
  Uint8List takeBytes();
}
