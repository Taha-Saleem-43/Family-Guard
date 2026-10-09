import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../../../core/models/member.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/member_status_provider.dart';
import '../models/sos_alert.dart';
import '../services/sos_service.dart';
import '../services/sos_dismissal_store.dart';

class SOSState {
  static const _unchanged = Object();
  final bool isSelfSosActive;
  final String? activeAlertId;
  final List<SOSAlert> activeCircleAlerts;
  final DateTime? sosStartTime;
  final int activeDurationSeconds;
  final Set<String> handledAlertIds;
  final bool updatesUnavailable;

  const SOSState({
    this.isSelfSosActive = false,
    this.activeAlertId,
    this.activeCircleAlerts = const [],
    this.sosStartTime,
    this.activeDurationSeconds = 0,
    this.handledAlertIds = const {},
    this.updatesUnavailable = false,
  });

  SOSAlert? get unhandledCircleEmergency {
    for (final alert in activeCircleAlerts) {
      if (!handledAlertIds.contains(alert.id)) {
        return alert;
      }
    }
    return null;
  }

  String get formattedActiveDuration {
    final mins = activeDurationSeconds ~/ 60;
    final secs = activeDurationSeconds % 60;
    final mStr = mins.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  SOSState copyWith({
    bool? isSelfSosActive,
    Object? activeAlertId = _unchanged,
    List<SOSAlert>? activeCircleAlerts,
    Object? sosStartTime = _unchanged,
    int? activeDurationSeconds,
    Set<String>? handledAlertIds,
    bool? updatesUnavailable,
  }) {
    return SOSState(
      isSelfSosActive: isSelfSosActive ?? this.isSelfSosActive,
      activeAlertId: identical(activeAlertId, _unchanged)
          ? this.activeAlertId
          : activeAlertId as String?,
      activeCircleAlerts: activeCircleAlerts ?? this.activeCircleAlerts,
      sosStartTime: identical(sosStartTime, _unchanged)
          ? this.sosStartTime
          : sosStartTime as DateTime?,
      activeDurationSeconds:
          activeDurationSeconds ?? this.activeDurationSeconds,
      handledAlertIds: handledAlertIds ?? this.handledAlertIds,
      updatesUnavailable: updatesUnavailable ?? this.updatesUnavailable,
    );
  }
}

class SOSNotifier extends StateNotifier<SOSState> {
  final Ref _ref;
  final SOSService _service;
  StreamSubscription<List<SOSAlert>>? _alertsSub;
  Timer? _durationTimer;
  Timer? _receiverSirenCutoffTimer;
  Timer? _receiverVibrationTimer;
  AudioPlayer? _audioPlayer;
  bool _sending = false;
  bool _resolving = false;
  int _sessionGeneration = 0;
  int _alarmGeneration = 0;
  final Set<String> _soundedAlertIds = {};
  final Future<void> Function()? _receiverAlarm;
  final SOSDismissalStore _dismissals;

  SOSNotifier(
    this._ref, {
    SOSService? service,
    Future<void> Function()? receiverAlarm,
    SOSDismissalStore? dismissals,
  }) : _service = service ?? SOSService(),
       _receiverAlarm = receiverAlarm,
       _dismissals = dismissals ?? PreferencesSOSDismissalStore(),
       super(const SOSState()) {
    _initSubscription();
  }

  void _initSubscription() {
    _ref.listen<AppState>(appStateProvider, (prev, next) {
      if (prev?.circleId != next.circleId || prev?.userId != next.userId) {
        _subscribeToCircle(next.circleId);
      }
    });

    final currentCircleId = _ref.read(appStateProvider).circleId;
    if (currentCircleId.isNotEmpty) {
      _subscribeToCircle(currentCircleId);
    }
  }

  void _subscribeToCircle(String circleId) {
    final generation = ++_sessionGeneration;
    _alertsSub?.cancel();
    _durationTimer?.cancel();
    _soundedAlertIds.clear();
    _stopReceiverSiren();
    state = const SOSState();
    if (circleId.isEmpty) return;
    final uid = _ref.read(appStateProvider).userId;
    final dismissed = _dismissals.load(uid, circleId).catchError((
      Object error,
    ) {
      debugPrint('[SOSNotifier] Dismissal restoration failed: $error');
      return <String>{};
    });

    _alertsSub = _service
        .streamActiveSOSAlerts(circleId)
        .listen(
          (alerts) async {
            final savedDismissals = await dismissed;
            if (!mounted || generation != _sessionGeneration) return;
            state = state.copyWith(
              handledAlertIds: {...savedDismissals, ...state.handledAlertIds},
            );
            final currentUid = _ref.read(appStateProvider).userId;
            final selfAlerts =
                alerts
                    .where((a) => a.senderId == currentUid && a.isActive)
                    .toList()
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _restoreSelfAlert(selfAlerts.isEmpty ? null : selfAlerts.first);

            // Filter alerts sent by other circle members
            final otherAlerts = alerts
                .where((a) => a.senderId != currentUid && a.isActive)
                .toList();

            state = state.copyWith(
              activeCircleAlerts: otherAlerts,
              updatesUnavailable: false,
            );

            // Check if there is an unhandled alert for receiver
            SOSAlert? unhandled;
            for (final a in otherAlerts) {
              if (!state.handledAlertIds.contains(a.id)) {
                unhandled = a;
                break;
              }
            }

            if (unhandled != null && _soundedAlertIds.add(unhandled.id)) {
              (_receiverAlarm?.call() ?? _playReceiverSirenAlert()).catchError((
                Object error,
              ) {
                debugPrint('[SOSNotifier] Receiver alarm failed: $error');
              });
            }
            if (unhandled == null) _stopReceiverSiren();
          },
          onError: (Object error) {
            if (!mounted || generation != _sessionGeneration) return;
            state = state.copyWith(updatesUnavailable: true);
            // Keep the last confirmed emergency during a connection failure.
            debugPrint('[SOSNotifier] Alert subscription failed: $error');
          },
        );
  }

  void _restoreSelfAlert(SOSAlert? alert) {
    if (alert == null) {
      _durationTimer?.cancel();
      _durationTimer = null;
      if (state.isSelfSosActive) {
        state = state.copyWith(
          isSelfSosActive: false,
          activeAlertId: null,
          sosStartTime: null,
          activeDurationSeconds: 0,
        );
        _ref.read(memberStateProvider.notifier).setSelfSosActive(false);
      }
      return;
    }
    final changed = state.activeAlertId != alert.id;
    state = state.copyWith(
      isSelfSosActive: true,
      activeAlertId: alert.id,
      sosStartTime: alert.timestamp,
      activeDurationSeconds: alert.currentDurationSeconds,
    );
    if (changed) _ref.read(memberStateProvider.notifier).setSelfSosActive(true);
    _startDurationTimer();
  }

  void _startDurationTimer() {
    if (_durationTimer?.isActive == true) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = state.sosStartTime;
      if (!mounted || start == null) return;
      final seconds = DateTime.now().difference(start).inSeconds;
      state = state.copyWith(activeDurationSeconds: seconds < 0 ? 0 : seconds);
    });
  }

  /// Plays alarm siren and vibration ONLY on receiver devices for MAX 5 SECONDS
  Future<void> _playReceiverSirenAlert() async {
    _stopReceiverSiren();
    final generation = _alarmGeneration;
    _receiverSirenCutoffTimer = Timer(const Duration(seconds: 5), () {
      _stopReceiverSiren();
    });

    // 1. Play siren sound (capped at 5 seconds)
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      if (!mounted || generation != _alarmGeneration) return;
      await _audioPlayer?.play(AssetSource('sounds/siren.wav'));
      if (!mounted || generation != _alarmGeneration) {
        await _audioPlayer?.stop();
        return;
      }
    } catch (e) {
      debugPrint('[SOSNotifier] Error playing receiver siren: $e');
    }

    // 2. Trigger vibration (capped at 5 seconds)
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (!mounted || generation != _alarmGeneration) return;
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [0, 500, 200, 500],
          repeat: 0,
        ).catchError((_) {});
      } else {
        _receiverVibrationTimer = Timer.periodic(
          const Duration(milliseconds: 700),
          (_) {
            try {
              HapticFeedback.vibrate();
            } catch (_) {}
          },
        );
      }
    } catch (e) {
      debugPrint('[SOSNotifier] Error starting vibration: $e');
    }
  }

  void _stopReceiverSiren() {
    _alarmGeneration++;
    _receiverSirenCutoffTimer?.cancel();
    _receiverSirenCutoffTimer = null;
    _receiverVibrationTimer?.cancel();
    _receiverVibrationTimer = null;

    try {
      Vibration.cancel().catchError((_) {});
    } catch (_) {}

    try {
      _audioPlayer?.stop().catchError((_) {});
    } catch (_) {}
  }

  /// Triggers SOS for current user (Silent sender mode: no sound or vibration for self)
  Future<bool> triggerEmergency({
    double? latitude,
    double? longitude,
    String address = 'Live Emergency Broadcast',
  }) async {
    final appState = _ref.read(appStateProvider);
    final generation = _sessionGeneration;
    if (appState.circleId.isEmpty || appState.userId.isEmpty || _sending) {
      return false;
    }
    if (state.isSelfSosActive) return true;
    _sending = true;

    // Use current member location if not explicitly provided
    final members = _ref.read(memberStateProvider);
    Member? memberLoc;
    for (final m in members) {
      if (m.id == appState.userId || m.id == 'm_self') {
        memberLoc = m;
        break;
      }
    }

    // Never label an old cached position as the emergency's current position.
    final locationAge = memberLoc == null
        ? null
        : DateTime.now().difference(memberLoc.lastSeen);
    final fresh =
        memberLoc != null &&
        !memberLoc.isStale &&
        locationAge != null &&
        locationAge.inSeconds >= -30 &&
        locationAge.inSeconds <= 120;
    final explicit = latitude != null || longitude != null;
    final lat = explicit ? latitude : (fresh ? memberLoc.latitude : null);
    final lng = explicit ? longitude : (fresh ? memberLoc.longitude : null);

    String? alertId;
    try {
      alertId = await _service.triggerSOS(
        circleId: appState.circleId,
        userId: appState.userId,
        userName: appState.userName,
        latitude: lat,
        longitude: lng,
        address: address,
      );
    } catch (error) {
      debugPrint('[SOSNotifier] Sending failed: $error');
    } finally {
      _sending = false;
    }
    if (!mounted ||
        generation != _sessionGeneration ||
        _ref.read(appStateProvider).userId != appState.userId ||
        _ref.read(appStateProvider).circleId != appState.circleId ||
        alertId == null) {
      return false;
    }

    final now = state.activeAlertId == alertId
        ? state.sosStartTime ?? DateTime.now()
        : DateTime.now();
    state = state.copyWith(
      isSelfSosActive: true,
      activeAlertId: alertId,
      sosStartTime: now,
      activeDurationSeconds: 0,
    );

    // Update local member pin border to red
    _ref.read(memberStateProvider.notifier).setSelfSosActive(true);

    // Start 1-second interval ticker for duration display
    _startDurationTimer();

    return true;
  }

  /// Resolves current user's emergency alert
  Future<bool> resolveEmergency() async {
    if (_resolving) return false;
    final alertId = state.activeAlertId;
    final userId = _ref.read(appStateProvider).userId;
    final generation = _sessionGeneration;
    if (alertId == null || alertId.isEmpty) return false;
    _resolving = true;
    var resolved = false;
    try {
      resolved = await _service.resolveSOS(
        alertId: alertId,
        userId: userId,
        circleId: _ref.read(appStateProvider).circleId,
      );
    } catch (error) {
      debugPrint('[SOSNotifier] Resolution failed: $error');
    } finally {
      _resolving = false;
    }
    if (!mounted ||
        !resolved ||
        generation != _sessionGeneration ||
        _ref.read(appStateProvider).userId != userId ||
        (state.activeAlertId != null && state.activeAlertId != alertId)) {
      return false;
    }
    _durationTimer?.cancel();
    _durationTimer = null;
    _ref.read(memberStateProvider.notifier).setSelfSosActive(false);
    state = state.copyWith(
      isSelfSosActive: false,
      activeAlertId: null,
      sosStartTime: null,
      activeDurationSeconds: 0,
    );
    return true;
  }

  /// Receiver dismisses emergency notification view locally
  void dismissReceiverAlert(String alertId) {
    _stopReceiverSiren();
    final updated = Set<String>.from(state.handledAlertIds)..add(alertId);
    state = state.copyWith(handledAlertIds: updated);
    final session = _ref.read(appStateProvider);
    if (session.userId.isNotEmpty && session.circleId.isNotEmpty) {
      _dismissals.save(session.userId, session.circleId, updated).catchError((
        Object error,
      ) {
        debugPrint('[SOSNotifier] Dismissal persistence failed: $error');
      });
    }
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _durationTimer?.cancel();
    _stopReceiverSiren();
    try {
      _audioPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }
}

final sosProvider = StateNotifierProvider<SOSNotifier, SOSState>((ref) {
  return SOSNotifier(ref);
});

final circleSosHistoryProvider = StreamProvider.autoDispose<List<SOSAlert>>((
  ref,
) {
  final circleId = ref.watch(
    appStateProvider.select((state) => state.circleId),
  );
  if (circleId.isEmpty) return Stream.value([]);
  return SOSService().streamCircleSOSHistory(circleId);
});
