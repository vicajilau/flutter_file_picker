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
        expect(completionOrder, [4, 3, 2, 1, 0]);
        expect(results, [0, 1, 2, 3, 4]);
      },
    );

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
