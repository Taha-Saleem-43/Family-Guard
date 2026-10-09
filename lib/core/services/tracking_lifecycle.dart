typedef TrackingScope = ({String uid, String circleId});

/// Orders native lifecycle operations and fences them to the requesting account.
class TrackingLifecycle {
  TrackingLifecycle({
    required this.currentUid,
    required this.verifyScope,
    required this.activate,
    required this.deactivate,
    required this.startNative,
    required this.stopNative,
    this.operationTimeout = const Duration(seconds: 10),
  });
  final String? Function() currentUid;
  final Future<bool> Function(String, String) verifyScope;
  final Future<void> Function(String, String) activate;
  final Future<void> Function(String) deactivate;
  final Future<void> Function() startNative;
  final Future<void> Function() stopNative;
  final Duration operationTimeout;
  Future<void> _tail = Future.value();
  TrackingScope? activeScope;

  Future<void> _ordered(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> start(String uid, String circleId) => _ordered(() async {
    if (currentUid() != uid) return;
    final verified = await verifyScope(uid, circleId).timeout(operationTimeout);
    if (currentUid() != uid) return;
    if (!verified) {
      try {
        await deactivate(uid);
      } finally {
        try {
          await stopNative().timeout(operationTimeout);
        } finally {
          activeScope = null;
        }
      }
      return;
    }
    try {
      await activate(uid, circleId);
      if (currentUid() != uid) {
        await deactivate(uid);
        await stopNative().timeout(operationTimeout);
        activeScope = null;
        return;
      }
      await startNative().timeout(operationTimeout);
      if (currentUid() != uid) {
        await deactivate(uid);
        await stopNative().timeout(operationTimeout);
        activeScope = null;
        return;
      }
      activeScope = (uid: uid, circleId: circleId);
    } catch (_) {
      activeScope = null;
      try {
        await deactivate(uid);
      } catch (_) {
        /* Preserve the original failure. */
      }
      try {
        await stopNative().timeout(operationTimeout);
      } catch (_) {
        /* The caller receives a failed start. */
      }
      rethrow;
    }
  });
  Future<void> stop(String? uid) => _ordered(() async {
    Object? cleanupError;
    StackTrace? cleanupStack;
    if (uid != null) {
      try {
        await deactivate(uid);
      } catch (error, stack) {
        cleanupError = error;
        cleanupStack = stack;
      }
    }
    final authenticated = currentUid();
    if (authenticated == uid ||
        authenticated == null ||
        activeScope?.uid == uid) {
      try {
        await stopNative().timeout(operationTimeout);
      } finally {
        activeScope = null;
      }
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStack!);
    }
  });
}
