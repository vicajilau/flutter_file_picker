import 'package:file_picker_web/src/indexed_task_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runIndexedTasks', () {
    test('sequential runs one at a time and preserves order', () async {
      var concurrent = 0;
      var maxConcurrent = 0;
      final startOrder = <int>[];

      final results = await runIndexedTasks<int>(5, (index) async {
        concurrent++;
        maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
        startOrder.add(index);
        // Earlier indices are slower, so if the next task started before
        // this one finished, sequential mode would still be broken.
        await Future.delayed(Duration(milliseconds: 5 * (5 - index)));
        concurrent--;
        return index;
      }, sequential: true);

      expect(maxConcurrent, 1);
      expect(startOrder, [0, 1, 2, 3, 4]);
      expect(results, [0, 1, 2, 3, 4]);
    });

    test(
      'concurrent runs more than one task at a time and still preserves order',
      () async {
        var concurrent = 0;
        var maxConcurrent = 0;
        final completionOrder = <int>[];

        final results = await runIndexedTasks<int>(5, (index) async {
          concurrent++;
          maxConcurrent = concurrent > maxConcurrent
              ? concurrent
              : maxConcurrent;
          // Reverse delays so completion order is the opposite of index
          // order, proving the result list isn't just built in completion
          // order.
          await Future.delayed(Duration(milliseconds: 5 * (5 - index)));
          concurrent--;
          completionOrder.add(index);
          return index;
        }, sequential: false);

        expect(maxConcurrent, greaterThan(1));
        expect(completionOrder.toSet(), {0, 1, 2, 3, 4});
        expect(results, [0, 1, 2, 3, 4]);
      },
    );

    test('limits simultaneous file reads and retains result order', () async {
      var active = 0;
      var peak = 0;
      final results = await runIndexedTasks<int>(
        20,
        (index) async {
          active++;
          if (active > peak) peak = active;
          await Future.delayed(Duration(milliseconds: 2 + index % 3));
          active--;
          return index;
        },
        sequential: false,
        maxConcurrent: 2,
      );

      expect(peak, 2);
      expect(results, [for (var i = 0; i < 20; i++) i]);
    });

    test('rejects a non-positive concurrency limit', () async {
      await expectLater(
        runIndexedTasks<int>(
          2,
          (index) async => index,
          sequential: false,
          maxConcurrent: 0,
        ),
        throwsArgumentError,
      );
    });

    test('returns an empty list for zero length', () async {
      final results = await runIndexedTasks<int>(
        0,
        (index) async => index,
        sequential: false,
      );
      expect(results, isEmpty);
    });
  });
}
