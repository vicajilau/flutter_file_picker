/// Runs [task] once for each index in `[0, length)`, either one at a time
/// ([sequential] `true`) or concurrently ([sequential] `false`).
///
/// Returns the results in index order regardless of completion order, so
/// callers can pick concurrency without also giving up on ordering.
Future<List<T>> runIndexedTasks<T>(
  int length,
  Future<T> Function(int index) task, {
  required bool sequential,
}) async {
  if (length == 0) return [];

  if (sequential) {
    final results = <T>[];
    for (var i = 0; i < length; i++) {
      results.add(await task(i));
    }
    return results;
  }

  // Future.wait() already returns results in the order the futures were
  // passed in, not completion order, so no manual index bookkeeping is
  // needed here.
  return Future.wait([for (var i = 0; i < length; i++) task(i)]);
}
