import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracelet/tracelet.dart' as tl;

import '../models/member.dart';
import '../models/movement_activity.dart';
import '../services/firestore_location_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import 'app_state_provider.dart';

class MemberStateNotifier extends StateNotifier<List<Member>> {
  final Ref _ref;
  final Battery _battery = Battery();
  final FirestoreLocationService _firestoreLocationService = FirestoreLocationService();

  StreamSubscription<BatteryState>? _batterySub;
  StreamSubscription<List<Member>>? _firestoreCircleSub;
  Timer? _batteryPollTimer;

  MemberStateNotifier(this._ref) : super([]) {
    _initMembers();
    _listenToDeviceBattery();
    _listenToLocationUpdates();
    _listenToFirestoreCircle();
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
        address: 'Active Location',
        latitude: 33.6844,
        longitude: 73.0479,
        lastSeen: DateTime.now(),
        batteryLevel: 95,
        isCharging: false,
        speedMph: 0.0,
        movementActivity: MovementActivity.stationary,
        pinColor: isParent ? AppColors.primary : AppColors.teal,
      ),
    ];
  }

  void _listenToFirestoreCircle() {
    _ref.listen<AppState>(appStateProvider, (previous, next) {
      if (next.circleId != previous?.circleId || next.userId != previous?.userId) {
        _subscribeToCircleStream(next.circleId, next.userId);
      }
    });

    final currentAppState = _ref.read(appStateProvider);
    if (currentAppState.circleId.isNotEmpty) {
      _subscribeToCircleStream(currentAppState.circleId, currentAppState.userId);
    }
  }

  void _subscribeToCircleStream(String circleId, String currentUid) {
    _firestoreCircleSub?.cancel();
    if (circleId.isEmpty) return;

    _firestoreCircleSub = _firestoreLocationService
        .streamCircleMembers(circleId: circleId, currentUid: currentUid)
        .listen((remoteMembers) {
      if (remoteMembers.isEmpty) return;

      final updatedList = <Member>[];
      final remoteMemberIds = remoteMembers.map((m) => m.id).toSet();

      // Maintain local self if present
      for (final m in state) {
        if (!remoteMemberIds.contains(m.id)) {
          updatedList.add(m);
        }
      }

      // Add/update remote members
      for (final remote in remoteMembers) {
        final existingIndex = updatedList.indexWhere((m) => m.id == remote.id);
        if (existingIndex != -1) {
          final existing = updatedList[existingIndex];
          final isSelf = remote.id == currentUid || remote.id == 'm_self' || existing.id == 'm_self';
          if (isSelf) {
            // Keep local live status (battery, location, activity) for self
            updatedList[existingIndex] = existing.copyWith(
              name: remote.name,
              avatar: remote.avatar,
              role: remote.role,
              pinColor: remote.pinColor,
            );
          } else {
            updatedList[existingIndex] = remote.copyWith(
              latitude: existing.latitude ?? remote.latitude,
              longitude: existing.longitude ?? remote.longitude,
            );
          }
        } else {
          updatedList.add(remote);
        }
      }

      state = updatedList;
    }, onError: (e) {
      debugPrint('[MemberStateNotifier] Circle stream error: $e');
    });
  }

  Future<void> _listenToDeviceBattery() async {
    try {
      final initialLevel = await _battery.batteryLevel;
      final initialStatus = await _battery.batteryState;
      final initialCharging = initialStatus == BatteryState.charging || initialStatus == BatteryState.full;
      _updateSelfBattery(initialLevel, isCharging: initialCharging);

      _batterySub = _battery.onBatteryStateChanged.listen((batteryState) async {
        final level = await _battery.batteryLevel;
        final isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;
        _updateSelfBattery(level, isCharging: isCharging);
      });

      // Poll battery level every 120 seconds to catch percentage drops while unplugged/discharging
      _batteryPollTimer?.cancel();
      _batteryPollTimer = Timer.periodic(const Duration(seconds: 120), (_) async {
        try {
          final level = await _battery.batteryLevel;
          final state = await _battery.batteryState;
          final isCharging = state == BatteryState.charging || state == BatteryState.full;
          _updateSelfBattery(level, isCharging: isCharging);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[MemberStateNotifier] Battery check error: $e');
    }
  }

  void _listenToLocationUpdates() {
    LocationService.instance.onLocation((tl.Location location) {
      final speedMph = location.coords.speed * 2.23694;
      final rawActivity = location.activity.type.toString();
      final activity = MovementActivity.fromSpeed(speedMph, rawActivity: rawActivity);

      _updateSelfLocation(
        lat: location.coords.latitude,
        lng: location.coords.longitude,
        speedMph: speedMph,
        activity: activity,
      );
    });

    LocationService.instance.onMotionChange((tl.Location location) {
      final speedMph = location.coords.speed * 2.23694;
      final activity = location.isMoving
          ? MovementActivity.fromSpeed(speedMph, rawActivity: location.activity.type.toString())
          : MovementActivity.stationary;

      _updateSelfLocation(
        lat: location.coords.latitude,
        lng: location.coords.longitude,
        speedMph: speedMph,
        activity: activity,
      );
    });
  }

  void _updateSelfLocation({
    required double lat,
    required double lng,
    required double speedMph,
    required MovementActivity activity,
  }) {
    final appState = _ref.read(appStateProvider);
    final selfId = appState.userId.isNotEmpty ? appState.userId : 'm_self';

    Member? selfMember;

    state = state.map((member) {
      if (member.id == selfId || member.id == 'm_self') {
        selfMember = member.copyWith(
          latitude: lat,
          longitude: lng,
          speedMph: speedMph,
          movementActivity: activity,
          lastSeen: DateTime.now(),
        );
        return selfMember!;
      }
      return member;
    }).toList();

    if (selfMember != null && appState.userId.isNotEmpty) {
      _firestoreLocationService.updateUserLocation(
        uid: appState.userId,
        latitude: lat,
        longitude: lng,
        speedMph: speedMph,
        activity: activity,
        batteryLevel: selfMember!.batteryLevel,
        isCharging: selfMember!.isCharging,
      );
    }
  }

  void _updateSelfBattery(int level, {required bool isCharging}) {
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

    if (selfMember != null && appState.userId.isNotEmpty) {
      _firestoreLocationService.updateUserLocation(
        uid: appState.userId,
        latitude: selfMember!.latitude ?? 0.0,
        longitude: selfMember!.longitude ?? 0.0,
        speedMph: selfMember!.speedMph,
        activity: selfMember!.movementActivity,
        batteryLevel: level,
        isCharging: isCharging,
      );
    }
  }

  /// Manually cycle member activity state for testing/interactive inspection
  void cycleMemberActivity(String memberId) {
    state = state.map((m) {
      if (m.id == memberId) {
        MovementActivity nextActivity;
        double nextSpeed;

        switch (m.movementActivity) {
          case MovementActivity.stationary:
            nextActivity = MovementActivity.walking;
            nextSpeed = 3.5;
            break;
          case MovementActivity.walking:
            nextActivity = MovementActivity.driving;
            nextSpeed = 34.0;
            break;
          case MovementActivity.driving:
            nextActivity = MovementActivity.stationary;
            nextSpeed = 0.0;
            break;
        }

        return m.copyWith(
          movementActivity: nextActivity,
          speedMph: nextSpeed,
          lastSeen: DateTime.now(),
        );
      }
      return m;
    }).toList();
  }

  /// Manually update member battery level for testing
  void setMemberBattery(String memberId, int batteryLevel, {bool isCharging = false}) {
    state = state.map((m) {
      if (m.id == memberId) {
        return m.copyWith(batteryLevel: batteryLevel, isCharging: isCharging);
      }
      return m;
    }).toList();
  }

  @override
  void dispose() {
    _batteryPollTimer?.cancel();
    _batterySub?.cancel();
    _firestoreCircleSub?.cancel();
    super.dispose();
  }
}

final memberStateProvider = StateNotifierProvider<MemberStateNotifier, List<Member>>((ref) {
  return MemberStateNotifier(ref);
});

final selectedActivityFilterProvider = StateProvider<MovementActivity?>((ref) => null);
