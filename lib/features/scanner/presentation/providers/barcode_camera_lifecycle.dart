/// Serializes native camera calls. A stop arriving during restart must run
/// after it; a subsequent resume must not be discarded as "already restarting".
class BarcodeCameraLifecycle {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }
}
