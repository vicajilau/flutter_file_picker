/// Runs [task] once for each index in `[0, length)`, either one at a time
/// ([sequential] `true`) or with up to [maxConcurrent] concurrent tasks.
/// This prevents bulk picks from starting unbounded file reads.
///
/// Returns the results in index order regardless of completion order, so
/// callers can pick concurrency without also giving up on ordering.
Future<List<T>> runIndexedTasks<T>(
  int length,
  Future<T> Function(int index) task, {
  required bool sequential,
  int maxConcurrent = 2,
}) async {
  if (maxConcurrent < 1) {
    throw ArgumentError.value(
      maxConcurrent,
      'maxConcurrent',
      'Must be positive',
    );
  }
  if (length == 0) return [];

  if (sequential) {
    final results = <T>[];
    for (var i = 0; i < length; i++) {
      results.add(await task(i));
    }
    return results;
  }

  // Only start another read after a worker finishes its previous one.
  // Keeping a slot per index preserves the browser's original selection order.
  final results = List<T?>.filled(length, null);
  var nextIndex = 0;
  Future<void> worker() async {
    while (nextIndex < length) {
      final index = nextIndex++;
      results[index] = await task(index);
    }
  }

  await Future.wait([
    for (var i = 0; i < length && i < maxConcurrent; i++) worker(),
  ]);
  return [for (final result in results) result as T];
}
