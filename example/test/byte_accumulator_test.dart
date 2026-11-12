import 'dart:typed_data';

import 'package:file_picker_example/src/byte_accumulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ByteAccumulator', () {
    Uint8List collect(List<List<int>> chunks, {int? length}) {
      final accumulator = ByteAccumulator(length: length);
      for (final chunk in chunks) {
        accumulator.add(Uint8List.fromList(chunk));
      }
      return accumulator.takeBytes();
    }

    test('concatenates chunks in order', () {
      expect(
        collect([
          [1, 2],
          [3],
          [4, 5, 6],
        ], length: 6),
        [1, 2, 3, 4, 5, 6],
      );
    });

    test('works without a known length', () {
      expect(
        collect([
          [1],
          [2, 3],
        ]),
        [1, 2, 3],
      );
    });

    test('returns only the added bytes when the stream is shorter', () {
      expect(
        collect([
          [1, 2],
        ], length: 5),
        [1, 2],
      );
    });

    test('keeps every byte when the stream is longer', () {
      expect(
        collect([
          [1, 2],
          [3, 4],
          [5],
        ], length: 3),
        [1, 2, 3, 4, 5],
      );
    });

    test('returns no bytes for an empty stream', () {
      expect(collect([], length: 0), isEmpty);
    });
  });
}
