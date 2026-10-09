import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/push_registration_store.dart';

enum PushStatus { signedOut, registering, ready, denied, unavailable }

class PushState {
  final PushStatus status;
  const PushState(this.status);
}

class PushSession {
  final String uid, circleId;
  const PushSession(this.uid, this.circleId);
}

/// Session generations guard client state; persistent versions fence backend
/// registrations when network requests arrive out of order.
class PushCoordinator extends StateNotifier<PushState> {
  final Future<bool> Function() permission;
  final Future<String?> Function() token;
  final Future<PushDeviceRegistration> Function() nextRegistration;
  final Future<void> Function(PushSession, PushDeviceRegistration, String)
  register;
  final Future<void> Function(PushSession, PushDeviceRegistration) unregister;
  final Future<void> Function() deleteToken;
  final String? Function() currentUid;
  final DateTime Function() now;
  PushSession? _session;
  int _generation = 0;
  String? _lastToken;
  DateTime? _registeredAt;
  bool _disposed = false;
  bool _disabledConfirmed = false;
  PushCoordinator({
    required this.permission,
    required this.token,
    required this.nextRegistration,
    required this.register,
    required this.unregister,
    required this.deleteToken,
    required this.currentUid,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(const PushState(PushStatus.signedOut));

  bool _current(int generation, PushSession session) =>
      !_disposed &&
      generation == _generation &&
      _session?.uid == session.uid &&
      _session?.circleId == session.circleId &&
      currentUid() == session.uid;

  Future<void> bind(String? uid, String? circleId, {bool force = false}) async {
    if (_disposed) return;
    if (!force && uid == _session?.uid && circleId == _session?.circleId) {
      return;
    }
    final generation = ++_generation;
    if (uid == null || uid.isEmpty || circleId == null || circleId.isEmpty) {
      _session = null;
      _lastToken = null;
      _registeredAt = null;
      state = const PushState(PushStatus.signedOut);
      return;
    }
    final previousUid = _session?.uid;
    final session = _session = PushSession(uid, circleId);
    if (previousUid != uid) {
      _lastToken = null;
      _registeredAt = null;
      _disabledConfirmed = false;
    }
    state = const PushState(PushStatus.registering);
    try {
      final allowed = await permission();
      if (!_current(generation, session)) return;
      if (!allowed) {
        if (!_disabledConfirmed) {
          final revision = await nextRegistration();
          if (!_current(generation, session)) return;
          await unregister(session, revision);
          if (!_current(generation, session)) return;
          _disabledConfirmed = true;
          _lastToken = null;
          _registeredAt = null;
        }
        if (_current(generation, session)) {
          state = const PushState(PushStatus.denied);
        }
        return;
      }
      final value = await token().timeout(const Duration(seconds: 15));
      if (!_current(generation, session)) return;
      if (value == null || value.isEmpty) throw StateError('No push token');
      if (value == _lastToken &&
          _registeredAt != null &&
          now().difference(_registeredAt!) >= Duration.zero &&
          now().difference(_registeredAt!) < const Duration(days: 1)) {
        state = const PushState(PushStatus.ready);
        return;
      }
      final revision = await nextRegistration();
      if (!_current(generation, session)) return;
      await register(session, revision, value);
      if (!_current(generation, session)) return;
      _lastToken = value;
      _registeredAt = now();
      _disabledConfirmed = false;
      state = const PushState(PushStatus.ready);
    } catch (_) {
      if (_current(generation, session)) {
        state = const PushState(PushStatus.unavailable);
      }
    }
  }

  Future<void> refresh() =>
      bind(_session?.uid, _session?.circleId, force: true);

  Future<void> detach(String uid) async {
    final session = _session;
    if (session?.uid != uid) return;
    await bind(null, null, force: true);
    try {
      final revision = await nextRegistration();
      if (currentUid() == uid) {
        await unregister(
          session!,
          revision,
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      /* Logout must remain available offline. */
    }
    if (currentUid() == uid || currentUid() == null) {
      try {
        await deleteToken().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
