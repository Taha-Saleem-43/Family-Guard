import 'dart:async';

/// One operation in flight and one newest pending value. Superseded callers share
/// the pending result instead of retaining one queued operation per callback.
class LatestValueQueue<T extends Object> {
  final Future<void> Function(T) _process;
  bool _running = false;
  T? _pendingValue;
  Completer<void>? _pendingResult;

  LatestValueQueue(this._process);

  Future<void> submit(T value) {
    _pendingValue = value;
    _pendingResult ??= Completer<void>();
    final result = _pendingResult!.future;
    if (!_running) {
      _running = true;
      unawaited(_drain());
    }
    return result;
  }

  Future<void> _drain() async {
    while (_pendingResult != null) {
      final value = _pendingValue!;
      final result = _pendingResult!;
      _pendingValue = null;
      _pendingResult = null;
      try {
        await _process(value);
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }
    _running = false;
  }
}
