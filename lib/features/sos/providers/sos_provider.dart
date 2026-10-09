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

class SOSState {
  final bool isSelfSosActive;
  final String? activeAlertId;
  final List<SOSAlert> activeCircleAlerts;
  final DateTime? sosStartTime;
  final int activeDurationSeconds;
  final Set<String> handledAlertIds;

  const SOSState({
    this.isSelfSosActive = false,
    this.activeAlertId,
    this.activeCircleAlerts = const [],
    this.sosStartTime,
    this.activeDurationSeconds = 0,
    this.handledAlertIds = const {},
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
    String? activeAlertId,
    List<SOSAlert>? activeCircleAlerts,
    DateTime? sosStartTime,
    int? activeDurationSeconds,
    Set<String>? handledAlertIds,
  }) {
    return SOSState(
      isSelfSosActive: isSelfSosActive ?? this.isSelfSosActive,
      activeAlertId: activeAlertId ?? this.activeAlertId,
      activeCircleAlerts: activeCircleAlerts ?? this.activeCircleAlerts,
      sosStartTime: sosStartTime ?? this.sosStartTime,
      activeDurationSeconds:
          activeDurationSeconds ?? this.activeDurationSeconds,
      handledAlertIds: handledAlertIds ?? this.handledAlertIds,
    );
  }
}

class SOSNotifier extends StateNotifier<SOSState> {
  final Ref _ref;
  final SOSService _service = SOSService();
  StreamSubscription<List<SOSAlert>>? _alertsSub;
  Timer? _durationTimer;
  Timer? _receiverSirenCutoffTimer;
  Timer? _receiverVibrationTimer;
  AudioPlayer? _audioPlayer;

  SOSNotifier(this._ref) : super(const SOSState()) {
    _initSubscription();
  }

  void _initSubscription() {
    _ref.listen<AppState>(appStateProvider, (prev, next) {
      if (prev?.circleId != next.circleId) {
        _subscribeToCircle(next.circleId);
      }
    });

    final currentCircleId = _ref.read(appStateProvider).circleId;
    if (currentCircleId.isNotEmpty) {
      _subscribeToCircle(currentCircleId);
    }
  }

  void _subscribeToCircle(String circleId) {
    _alertsSub?.cancel();
    _durationTimer?.cancel();
    _stopReceiverSiren();
    state = const SOSState();
    if (circleId.isEmpty) return;

    _alertsSub = _service.streamActiveSOSAlerts(circleId).listen((alerts) {
      final currentUid = _ref.read(appStateProvider).userId;

      // Filter alerts sent by other circle members
      final otherAlerts = alerts
          .where((a) => a.senderId != currentUid)
          .toList();

      state = state.copyWith(activeCircleAlerts: otherAlerts);

      // Check if there is an unhandled alert for receiver
      SOSAlert? unhandled;
      for (final a in otherAlerts) {
        if (!state.handledAlertIds.contains(a.id)) {
          unhandled = a;
          break;
        }
      }

      if (unhandled != null) {
        _playReceiverSirenAlert();
      }
    });
  }

  /// Plays alarm siren and vibration ONLY on receiver devices for MAX 5 SECONDS
  Future<void> _playReceiverSirenAlert() async {
    _stopReceiverSiren();

    // 1. Play siren sound (capped at 5 seconds)
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer?.play(AssetSource('sounds/siren.wav'));

      // Strict 5-second max duration cutoff for siren
      _receiverSirenCutoffTimer = Timer(const Duration(seconds: 5), () {
        _stopReceiverSiren();
      });
    } catch (e) {
      debugPrint('[SOSNotifier] Error playing receiver siren: $e');
    }

    // 2. Trigger vibration (capped at 5 seconds)
    try {
      final hasVibrator = await Vibration.hasVibrator();
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
  Future<void> triggerEmergency({
    double? latitude,
    double? longitude,
    String address = 'Live Emergency Broadcast',
  }) async {
    final appState = _ref.read(appStateProvider);
    if (appState.circleId.isEmpty || appState.userId.isEmpty) return;

    // Use current member location if not explicitly provided
    final members = _ref.read(memberStateProvider);
    Member? memberLoc;
    for (final m in members) {
      if (m.id == appState.userId || m.id == 'm_self') {
        memberLoc = m;
        break;
      }
    }

    final lat = latitude ?? memberLoc?.latitude;
    final lng = longitude ?? memberLoc?.longitude;

    final now = DateTime.now();
    state = state.copyWith(
      isSelfSosActive: true,
      sosStartTime: now,
      activeDurationSeconds: 0,
    );

    // Update local member pin border to red
    _ref.read(memberStateProvider.notifier).setSelfSosActive(true);

    // Start 1-second interval ticker for duration display
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        activeDurationSeconds: state.activeDurationSeconds + 1,
      );
    });

    final alertId = await _service.triggerSOS(
      circleId: appState.circleId,
      userId: appState.userId,
      userName: appState.userName,
      latitude: lat,
      longitude: lng,
      address: address,
    );

    if (alertId != null) {
      state = state.copyWith(activeAlertId: alertId);
    }
  }

  /// Resolves current user's emergency alert
  Future<void> resolveEmergency() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    // Reset local member pin border back to default
    _ref.read(memberStateProvider.notifier).setSelfSosActive(false);

    final alertId = state.activeAlertId;
    final userId = _ref.read(appStateProvider).userId;

    if (alertId != null && alertId.isNotEmpty) {
      await _service.resolveSOS(
        alertId: alertId,
        userId: userId,
        circleId: _ref.read(appStateProvider).circleId,
      );
    }

    state = state.copyWith(
      isSelfSosActive: false,
      activeAlertId: null,
      sosStartTime: null,
      activeDurationSeconds: 0,
    );
  }

  /// Receiver dismisses emergency notification view locally
  void dismissReceiverAlert(String alertId) {
    _stopReceiverSiren();
    final updated = Set<String>.from(state.handledAlertIds)..add(alertId);
    state = state.copyWith(handledAlertIds: updated);
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
