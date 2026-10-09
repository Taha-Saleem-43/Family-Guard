import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/user_account_model.dart';
import '../../features/auth/services/auth_service.dart';
import '../models/member.dart';
import '../services/location_service.dart';
export '../models/member.dart' show UserRole;

enum AppStage { onboarding, main }

enum AppTab { map, history, places, alerts, settings }

class AppState {
  final AppStage stage;
  final UserRole role;
  final AppTab activeTab;
  final String circleName,
      userName,
      childInviteCode,
      parentInviteCode,
      userId,
      circleId;
  const AppState({
    required this.stage,
    required this.role,
    required this.activeTab,
    required this.circleName,
    this.userName = 'Family Member',
    this.childInviteCode = '',
    this.parentInviteCode = '',
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
  }) => AppState(
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

class AppStateNotifier extends StateNotifier<AppState> {
  StreamSubscription? _circleSub, _inviteSub;
  final Future<UserAccountModel?> Function()? _accountLoader;
  int _sessionGeneration = 0;
  static const initial = AppState(
    stage: AppStage.onboarding,
    role: UserRole.child,
    activeTab: AppTab.map,
    circleName: 'Family Circle',
  );
  AppStateNotifier({Future<UserAccountModel?> Function()? accountLoader})
    : _accountLoader = accountLoader,
      super(initial);

  void _subscribeToCircle(String circleId) {
    _circleSub?.cancel();
    _inviteSub?.cancel();
    if (circleId.isEmpty || Firebase.apps.isEmpty) return;
    final service = AuthService();
    final generation = _sessionGeneration;
    _circleSub = service
        .streamCircle(circleId)
        .listen(
          (circle) {
            if (!mounted || generation != _sessionGeneration) return;
            if (circle == null) {
              resetToOnboarding();
              return;
            }
            state = state.copyWith(circleName: circle.name);
          },
          onError: (Object error) {
            if (mounted &&
                generation == _sessionGeneration &&
                error is FirebaseException &&
                error.code == 'permission-denied') {
              resetToOnboarding();
            }
          },
        );
    if (state.role == UserRole.parent) {
      _inviteSub = service.streamInvites(circleId).listen((data) {
        if (!mounted || generation != _sessionGeneration) return;
        state = state.copyWith(
          childInviteCode: data?['childInviteCode'] as String? ?? '',
          parentInviteCode: data?['parentInviteCode'] as String? ?? '',
        );
      }, onError: (Object _) {});
    }
  }

  void setRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  void setCircleName(String name) {
    state = state.copyWith(circleName: name);
  }

  void setUserName(String name) {
    if (name.trim().isNotEmpty) state = state.copyWith(userName: name.trim());
  }

  void setUserId(String uid) {
    state = state.copyWith(userId: uid);
  }

  void setCircleId(String id) {
    state = state.copyWith(circleId: id);
    _subscribeToCircle(id);
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
    _sessionGeneration++;
    state = initial.copyWith(
      stage: state.stage,
      userId: userId,
      circleId: circleId,
      userName: userName,
      role: role,
      circleName: circleName,
      childInviteCode: childCode ?? '',
      parentInviteCode: parentCode ?? '',
    );
    _subscribeToCircle(circleId);
  }

  void setInviteCodes({required String childCode, required String parentCode}) {
    state = state.copyWith(
      childInviteCode: childCode,
      parentInviteCode: parentCode,
    );
  }

  void completeOnboarding(UserRole role, [String? circleName]) {
    state = state.copyWith(
      stage: AppStage.main,
      role: role,
      activeTab: AppTab.map,
      circleName: circleName,
    );
    _subscribeToCircle(state.circleId);
  }

  void setActiveTab(AppTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<bool> checkRestoreSession([String? targetUid]) async {
    final generation = _sessionGeneration;
    UserAccountModel? account;
    if (_accountLoader != null) {
      account = await _accountLoader();
    } else {
      if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
        return false;
      }
      account = await AuthService().loadCurrentAccount();
    }
    if (!mounted ||
        generation != _sessionGeneration ||
        account == null ||
        (targetUid != null && targetUid != account.uid)) {
      return false;
    }
    setUserSession(
      userId: account.uid,
      circleId: account.circleId ?? '',
      userName: account.displayName,
      role: account.role,
    );
    if (account.circleId?.isNotEmpty != true) return false;
    completeOnboarding(account.role);
    return true;
  }

  void resetToOnboarding() {
    unawaited(LocationService.instance.stop().catchError((Object _) {}));
    _sessionGeneration++;
    _circleSub?.cancel();
    _inviteSub?.cancel();
    state = initial;
  }

  @override
  void dispose() {
    _sessionGeneration++;
    _circleSub?.cancel();
    _inviteSub?.cancel();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(),
);
