import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracelet/tracelet.dart' as tl;

import '../models/member.dart';
import '../models/movement_activity.dart';
import '../services/firestore_location_service.dart';
import '../services/location_service.dart';
import '../services/location_sync_service.dart';
import '../services/location_fix_policy.dart';
import '../services/member_profile_decoder.dart';
import '../theme/app_colors.dart';
import 'app_state_provider.dart';

class MemberStateNotifier extends StateNotifier<List<Member>> {
  final Ref _ref;
  final Battery _battery = Battery();
  final FirestoreLocationService _firestoreLocationService =
      LocationSyncService.uploader;

  StreamSubscription<BatteryState>? _batterySub;
  StreamSubscription<List<Member>>? _firestoreCircleSub;
  int _circleGeneration = 0;
  Timer? _batteryPollTimer;
  Timer? _freshnessTimer;
  StreamSubscription<tl.Location>? _locationSub, _motionSub;

  MemberStateNotifier(this._ref) : super([]) {
    _initMembers();
    _listenToDeviceBattery();
    _listenToLocationUpdates();
    _listenToFirestoreCircle();
    _freshnessTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final updated = MemberProfileDecoder.ageMembers(state, DateTime.now());
      if (!identical(updated, state)) state = updated;
    });
  }

  void _initMembers() {
    final appState = _ref.read(appStateProvider);
    final userName = appState.userName.isNotEmpty ? appState.userName : 'You';
    final isParent = appState.role == UserRole.parent;

    state = [
      Member(
        id: appState.userId.isNotEmpty ? appState.userId : 'm_self',
        name: '$userName (You)',
        avatar: isParent ? '👨' : '👩‍🦰',
        role: isParent ? UserRole.parent : UserRole.child,
        address: 'Waiting for location',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
        isStale: true,
        batteryLevel: -1,
        isCharging: false,
        speedMph: 0.0,
        movementActivity: MovementActivity.stationary,
        pinColor: isParent ? AppColors.primary : AppColors.teal,
      ),
    ];
  }

  void _listenToFirestoreCircle() {
    _ref.listen<AppState>(appStateProvider, (previous, next) {
      if (next.circleId != previous?.circleId ||
          next.userId != previous?.userId ||
          next.role != previous?.role) {
        _initMembers();
        _subscribeToCircleStream(next.circleId, next.userId, next.role);
      }
    });

    final currentAppState = _ref.read(appStateProvider);
    if (currentAppState.circleId.isNotEmpty) {
      _subscribeToCircleStream(
        currentAppState.circleId,
        currentAppState.userId,
        currentAppState.role,
      );
    }
  }

  void _subscribeToCircleStream(
    String circleId,
    String currentUid,
    UserRole role,
  ) {
    final generation = ++_circleGeneration;
    _firestoreCircleSub?.cancel();
    if (circleId.isEmpty) return;

    _firestoreCircleSub = _firestoreLocationService
        .streamCircleMembers(
          circleId: circleId,
          currentUid: currentUid,
          currentRole: role,
        )
        .listen(
          (remoteMembers) {
            if (!mounted || generation != _circleGeneration) return;
            final localSelf = state
                .where((m) => m.id == currentUid)
                .firstOrNull;
            final updatedList = remoteMembers.map((remote) {
              if (remote.id != currentUid ||
                  localSelf == null ||
                  localSelf.latitude == null) {
                return remote;
              }
              return localSelf.copyWith(
                name: remote.name,
                role: remote.role,
                avatar: remote.avatar,
                pinColor: remote.pinColor,
                isSosActive: remote.isSosActive,
              );
            }).toList();
            state = updatedList;
          },
          onError: (e) {
            debugPrint('[MemberStateNotifier] Circle stream error: $e');
          },
        );
  }

  /// Sets self SOS active state and updates pin border color back to default when false
  void setSelfSosActive(bool isActive) {
    final appState = _ref.read(appStateProvider);
    final selfId = appState.userId.isNotEmpty ? appState.userId : 'm_self';

    state = state.map((member) {
      if (member.id == selfId || member.id == 'm_self') {
        final defaultPinColor = member.role == UserRole.parent
            ? AppColors.primary
            : AppColors.teal;
        return member.copyWith(
          isSosActive: isActive,
          pinColor: isActive ? AppColors.sosRed : defaultPinColor,
        );
      }
      return member;
    }).toList();
  }

  Future<void> _listenToDeviceBattery() async {
    try {
      final initialLevel = await _battery.batteryLevel;
      final initialStatus = await _battery.batteryState;
      if (!mounted) return;
      final initialCharging =
          initialStatus == BatteryState.charging ||
          initialStatus == BatteryState.full;
      _updateSelfBattery(initialLevel, isCharging: initialCharging);

      _batterySub = _battery.onBatteryStateChanged.listen((batteryState) async {
        final level = await _battery.batteryLevel;
        if (!mounted) return;
        final isCharging =
            batteryState == BatteryState.charging ||
            batteryState == BatteryState.full;
        _updateSelfBattery(level, isCharging: isCharging);
      });

      // Poll battery level every 120 seconds to catch percentage drops while unplugged/discharging
      _batteryPollTimer?.cancel();
      _batteryPollTimer = Timer.periodic(const Duration(seconds: 120), (
        _,
      ) async {
        try {
          final level = await _battery.batteryLevel;
          final state = await _battery.batteryState;
          final isCharging =
              state == BatteryState.charging || state == BatteryState.full;
          if (mounted) _updateSelfBattery(level, isCharging: isCharging);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[MemberStateNotifier] Battery check error: $e');
    }
  }

  void _listenToLocationUpdates() {
    _locationSub = LocationService.instance.onLocation((tl.Location location) {
      if (!mounted ||
          !_ownsDeviceFix(location) ||
          !LocationFixPolicy.accepts(
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            accuracy: location.coords.accuracy,
            capturedAt: DateTime.tryParse(location.timestamp),
            now: DateTime.now(),
          )) {
        return;
      }
      final speedMph = location.coords.speed < 0
          ? 0.0
          : location.coords.speed * 2.23694;
      final rawActivity = location.activity.type.toString();
      final activity = MovementActivity.fromSpeed(
        speedMph,
        rawActivity: rawActivity,
      );

      _updateSelfLocation(
        capturedAt: DateTime.parse(location.timestamp),
        lat: location.coords.latitude,
        lng: location.coords.longitude,
        speedMph: speedMph,
        activity: activity,
      );
    });

    _motionSub = LocationService.instance.onMotionChange((
      tl.Location location,
    ) {
      if (!mounted ||
          !_ownsDeviceFix(location) ||
          !LocationFixPolicy.accepts(
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
            accuracy: location.coords.accuracy,
            capturedAt: DateTime.tryParse(location.timestamp),
            now: DateTime.now(),
          )) {
        return;
      }
      final speedMph = location.coords.speed < 0
          ? 0.0
          : location.coords.speed * 2.23694;
      final activity = location.isMoving
          ? MovementActivity.fromSpeed(
              speedMph,
              rawActivity: location.activity.type.toString(),
            )
          : MovementActivity.stationary;

      _updateSelfLocation(
        capturedAt: DateTime.parse(location.timestamp),
        lat: location.coords.latitude,
        lng: location.coords.longitude,
        speedMph: speedMph,
        activity: activity,
      );
    });
  }

  bool _ownsDeviceFix(tl.Location location) {
    final account = _ref.read(appStateProvider);
    return account.stage == AppStage.main &&
        account.role == UserRole.child &&
        LocationService.instance.ownsDisplayFix(
          account.userId,
          account.circleId,
          DateTime.tryParse(location.timestamp),
        );
  }

  void _updateSelfLocation({
    required DateTime capturedAt,
    required double lat,
    required double lng,
    required double speedMph,
    required MovementActivity activity,
  }) {
    final appState = _ref.read(appStateProvider);
    final selfId = appState.userId.isNotEmpty ? appState.userId : 'm_self';

    if (!mounted || appState.userId.isEmpty) return;
    Member? selfMember;

    state = state.map((member) {
      if (member.id == selfId || member.id == 'm_self') {
        selfMember = member.copyWith(
          latitude: lat,
          longitude: lng,
          speedMph: speedMph,
          movementActivity: activity,
          lastSeen: capturedAt,
          isStale: false,
        );
        return selfMember!;
      }
      return member;
    }).toList();
  }

  void _updateSelfBattery(int level, {required bool isCharging}) {
    if (!mounted) return;
    final appState = _ref.read(appStateProvider);
    final selfId = appState.userId.isNotEmpty ? appState.userId : 'm_self';

    Member? selfMember;

    state = state.map((member) {
      if (member.id == selfId || member.id == 'm_self') {
        selfMember = member.copyWith(
          batteryLevel: level,
          isCharging: isCharging,
        );
        return selfMember!;
      }
      return member;
    }).toList();
  }

  /// Manually update member battery level for testing
  void setMemberBattery(
    String memberId,
    int batteryLevel, {
    bool isCharging = false,
  }) {
    state = state.map((m) {
      if (m.id == memberId) {
        return m.copyWith(batteryLevel: batteryLevel, isCharging: isCharging);
      }
      return m;
    }).toList();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _motionSub?.cancel();
    _batteryPollTimer?.cancel();
    _freshnessTimer?.cancel();
    _batterySub?.cancel();
    _firestoreCircleSub?.cancel();
    super.dispose();
  }
}

final memberStateProvider =
    StateNotifierProvider<MemberStateNotifier, List<Member>>((ref) {
      return MemberStateNotifier(ref);
    });

final selectedActivityFilterProvider = StateProvider<MovementActivity?>(
  (ref) => null,
);
