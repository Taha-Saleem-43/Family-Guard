class AccountDeletionReceipt {
  final bool localCleanupComplete;
  const AccountDeletionReceipt({required this.localCleanupComplete});
}

class AccountDeletionFailure implements Exception {
  final String message;
  const AccountDeletionFailure(this.message);
  @override
  String toString() => message;
}

/// Password verification stays in Firebase Auth; the callable receives only the
/// expected UID. A confirmed request stays confirmed even if local cleanup fails.
class AccountDeletionService {
  final Future<void> Function(String uid, String password) verify;
  final Future<void> Function(String uid) pauseSharing;
  final Future<bool> Function(String uid) enqueue;
  final Future<void> Function(String uid) clearLocal;
  final Future<void> Function(String uid) signOut;
  const AccountDeletionService({
    required this.verify,
    required this.pauseSharing,
    required this.enqueue,
    required this.clearLocal,
    required this.signOut,
  });

  Future<AccountDeletionReceipt> request(String uid, String password) async {
    try {
      await verify(uid, password);
    } catch (_) {
      throw const AccountDeletionFailure(
        'Could not verify your sign-in. Check your password and try again.',
      );
    }
    try {
      await pauseSharing(uid);
    } catch (_) {
      throw const AccountDeletionFailure(
        'Could not stop location sharing. Deletion was not requested. Try again.',
      );
    }
    try {
      if (!await enqueue(uid)) throw StateError('Request not confirmed');
    } catch (_) {
      throw const AccountDeletionFailure(
        'Deletion could not be confirmed. It may still be processing. Location sharing has been paused.',
      );
    }
    var localCleanupComplete = true;
    for (final cleanup in [clearLocal, signOut]) {
      try {
        await cleanup(uid);
      } catch (_) {
        localCleanupComplete = false;
      }
    }
    return AccountDeletionReceipt(localCleanupComplete: localCleanupComplete);
  }
}
