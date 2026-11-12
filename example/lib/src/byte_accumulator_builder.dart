import 'dart:typed_data';

import 'byte_accumulator.dart';

/// Native platforms read chunks into Dart memory, so a [BytesBuilder] that
/// keeps references to them and concatenates once at the end is enough.
ByteAccumulator createByteAccumulator(int? length) => _BuilderByteAccumulator();

/// A [ByteAccumulator] backed by a non-copying [BytesBuilder].
class _BuilderByteAccumulator implements ByteAccumulator {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  @override
  void add(Uint8List chunk) => _builder.add(chunk);

  @override
  Uint8List takeBytes() => _builder.takeBytes();
}
