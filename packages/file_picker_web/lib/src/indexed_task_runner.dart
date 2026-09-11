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
  final results = List<T?>.filled(length, null);

  if (sequential) {
    for (var i = 0; i < length; i++) {
      results[i] = await task(i);
    }
  } else {
    await Future.wait([
      for (var i = 0; i < length; i++)
        task(i).then((value) => results[i] = value),
    ]);
  }

  return results.cast<T>();
}
