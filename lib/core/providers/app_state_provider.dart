import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/services/auth_service.dart';
import '../models/member.dart';
import '../services/user_session_service.dart';
export '../models/member.dart' show UserRole;

enum AppStage { onboarding, main }
enum AppTab { map, history, places, alerts, settings }

class AppState {
  final AppStage stage;
  final UserRole role;
  final AppTab activeTab;
  final String circleName;
  final String userName;
  final String childInviteCode;
  final String parentInviteCode;
  final String userId;
  final String circleId;

  const AppState({
    required this.stage,
    required this.role,
    required this.activeTab,
    required this.circleName,
    this.userName = 'Family Member',
    this.childInviteCode = 'FAMILY-XXXX',
    this.parentInviteCode = 'PARENT-XXXX',
    this.userId = '',
    this.circleId = '',
  });

  AppState copyWith({
    AppStage? stage,
    UserRole? role,
    AppTab? activeTab,
    String? circleName,
    String? userName,
    String? childInviteCode,
    String? parentInviteCode,
    String? userId,
    String? circleId,
  }) {
    return AppState(
      stage: stage ?? this.stage,
      role: role ?? this.role,
      activeTab: activeTab ?? this.activeTab,
      circleName: circleName ?? this.circleName,
      userName: userName ?? this.userName,
      childInviteCode: childInviteCode ?? this.childInviteCode,
      parentInviteCode: parentInviteCode ?? this.parentInviteCode,
      userId: userId ?? this.userId,
      circleId: circleId ?? this.circleId,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  StreamSubscription? _circleSub;

  AppStateNotifier()
      : super(const AppState(
          stage: AppStage.onboarding,
          role: UserRole.parent,
          activeTab: AppTab.map,
          circleName: 'Family Circle',
          userName: 'Family Member',
          childInviteCode: 'FAMILY-XXXX',
          parentInviteCode: 'PARENT-XXXX',
          userId: '',
          circleId: '',
        ));

  void _subscribeToCircle(String circleId) {
    _circleSub?.cancel();
    if (circleId.isEmpty || Firebase.apps.isEmpty) return;

    _circleSub = AuthService().streamCircle(circleId).listen((circle) {
      if (circle != null && circle.name.isNotEmpty) {
        state = state.copyWith(
          circleName: circle.name,
          childInviteCode: circle.childInviteCode.isNotEmpty ? circle.childInviteCode : state.childInviteCode,
          parentInviteCode: circle.parentInviteCode.isNotEmpty ? circle.parentInviteCode : state.parentInviteCode,
        );
        if (state.userId.isNotEmpty) {
          UserSessionService.saveUserSession(
            uid: state.userId,
            role: state.role == UserRole.parent ? 'parent' : 'child',
            circleId: circleId,
            circleName: circle.name,
            childCode: circle.childInviteCode,
            parentCode: circle.parentInviteCode,
          );
        }
      }
    });
  }

  void setRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  void setCircleName(String name) {
    state = state.copyWith(circleName: name);
  }

  void setUserName(String name) {
    if (name.trim().isNotEmpty) {
      state = state.copyWith(userName: name.trim());
    }
  }

  void setUserId(String userId) {
    state = state.copyWith(userId: userId);
  }

  void setCircleId(String circleId) {
    state = state.copyWith(circleId: circleId);
    _subscribeToCircle(circleId);
  }

  void setUserSession({
    required String userId,
    required String circleId,
    String? userName,
    UserRole? role,
    String? circleName,
    String? childCode,
    String? parentCode,
  }) {
    state = state.copyWith(
      userId: userId,
      circleId: circleId,
      userName: userName != null && userName.isNotEmpty ? userName : state.userName,
      role: role ?? state.role,
      circleName: circleName != null && circleName.isNotEmpty ? circleName : state.circleName,
      childInviteCode: childCode != null && childCode.isNotEmpty ? childCode : state.childInviteCode,
      parentInviteCode: parentCode != null && parentCode.isNotEmpty ? parentCode : state.parentInviteCode,
    );
    if (circleId.isNotEmpty) {
      _subscribeToCircle(circleId);
    }
  }

  void setInviteCodes({required String childCode, required String parentCode}) {
    state = state.copyWith(childInviteCode: childCode, parentInviteCode: parentCode);
  }

  void completeOnboarding(UserRole role, [String? circleName]) {
    state = state.copyWith(
      stage: AppStage.main,
      role: role,
      activeTab: AppTab.map,
      circleName: circleName ?? state.circleName,
    );
    if (state.circleId.isNotEmpty) {
      _subscribeToCircle(state.circleId);
    }
  }

  void setActiveTab(AppTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  /// Restores session from persistent storage on app startup
  Future<bool> checkRestoreSession([String? targetUid]) async {
    Map<String, dynamic>? session;
    if (targetUid != null && targetUid.isNotEmpty) {
      session = await UserSessionService.getUserSession(targetUid);
    } else {
      session = await UserSessionService.getActiveSession();
    }

    if (session != null && session['isLoggedIn'] == true) {
      final circleId = session['circleId'] as String? ?? '';
      final roleStr = session['role'] as String? ?? 'parent';
      final role = roleStr == 'parent' ? UserRole.parent : UserRole.child;
      final userName = session['userName'] as String?;
      final circleName = session['circleName'] as String?;
      final childCode = session['childCode'] as String?;
      final parentCode = session['parentCode'] as String?;
      final uid = session['uid'] as String? ?? targetUid ?? '';

      setUserSession(
        userId: uid,
        circleId: circleId,
        userName: userName,
        role: role,
        circleName: circleName,
        childCode: childCode,
        parentCode: parentCode,
      );

      if (circleId.isNotEmpty) {
        completeOnboarding(role, circleName);
        return true;
      }
    }
    return false;
  }

  void resetToOnboarding() {
    _circleSub?.cancel();
    state = const AppState(
      stage: AppStage.onboarding,
      role: UserRole.parent,
      activeTab: AppTab.map,
      circleName: 'Family Circle',
      userName: 'Family Member',
      childInviteCode: 'FAMILY-XXXX',
      parentInviteCode: 'PARENT-XXXX',
      userId: '',
      circleId: '',
    );
  }

  @override
  void dispose() {
    _circleSub?.cancel();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

