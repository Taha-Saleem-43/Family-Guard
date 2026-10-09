import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/user_account_model.dart';
import '../../features/auth/services/auth_service.dart';
import '../models/member.dart';
import '../services/location_service.dart';
import '../models/account_scope.dart';
export '../models/member.dart' show UserRole;

enum AppStage { onboarding, main }

enum AppTab { map, history, places, alerts, settings }

class AppState {
  static const _unchanged = Object();
  final DateTime? inviteExpiresAt;
  final bool accountUnavailable;
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
    this.inviteExpiresAt,
    this.accountUnavailable = false,
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
    Object? inviteExpiresAt = _unchanged,
    bool? accountUnavailable,
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
    inviteExpiresAt: identical(inviteExpiresAt, _unchanged)
        ? this.inviteExpiresAt
        : inviteExpiresAt as DateTime?,
    accountUnavailable: accountUnavailable ?? this.accountUnavailable,
  );
}

class AppStateNotifier extends StateNotifier<AppState> {
  StreamSubscription? _circleSub, _inviteSub;
  StreamSubscription<AccountScope>? _profileSub;
  String? _profileUid;
  int _profileGeneration = 0;
  String? _revokedCircleId;
  final Stream<AccountScope> Function(String)? _profileStream;
  final String? Function()? _currentUid;
  final Future<void> Function(String)? _stopSharing;
  final Future<UserAccountModel?> Function()? _accountLoader;
  int _sessionGeneration = 0;
  static const initial = AppState(
    stage: AppStage.onboarding,
    role: UserRole.child,
    activeTab: AppTab.map,
    circleName: 'Family Circle',
  );
  AppStateNotifier({
    Future<UserAccountModel?> Function()? accountLoader,
    Stream<AccountScope> Function(String)? profileStream,
    String? Function()? currentUid,
    Future<void> Function(String)? stopSharing,
  }) : _accountLoader = accountLoader,
       _profileStream = profileStream,
       _currentUid = currentUid,
       _stopSharing = stopSharing,
       super(initial);

  void _watchOwnProfile() {
    if (state.stage != AppStage.main) return;
    final uid = state.userId;
    if (uid.isEmpty || (_profileStream == null && Firebase.apps.isEmpty)) {
      return;
    }
    if (_profileUid == uid && _profileSub != null) return;
    _profileSub?.cancel();
    _profileUid = uid;
    final generation = ++_profileGeneration;
    final stream =
        _profileStream?.call(uid) ??
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(includeMetadataChanges: true)
            .where((doc) => !doc.metadata.isFromCache)
            .map((doc) => AccountScope.fromServer(uid, doc.data()));
    bool current() =>
        mounted &&
        generation == _profileGeneration &&
        state.userId == uid &&
        (_currentUid != null
                ? _currentUid()
                : (Firebase.apps.isNotEmpty
                      ? FirebaseAuth.instance.currentUser?.uid
                      : uid)) ==
            uid;
    _profileSub = stream.listen(
      (scope) {
        if (!current() ||
            scope.uid != uid ||
            (state.stage != AppStage.main &&
                !state.accountUnavailable &&
                scope.available)) {
          return;
        }
        if (scope.available &&
            scope.circleId.isNotEmpty &&
            scope.circleId == _revokedCircleId) {
          return;
        }
        if (state.accountUnavailable ||
            !scope.available ||
            scope.circleId != state.circleId ||
            scope.role != state.role) {
          if (scope.available) {
            ++_profileGeneration;
            _profileSub?.cancel();
            _profileSub = null;
            _profileUid = null;
          }
          ++_sessionGeneration;
          _circleSub?.cancel();
          _inviteSub?.cancel();
          state = initial.copyWith(
            userId: uid,
            userName: scope.name,
            role: scope.role,
            circleId: scope.circleId,
            accountUnavailable: !scope.available,
          );
          final stop = _stopSharing;
          unawaited(
            (stop != null
                    ? stop(uid)
                    : LocationService.instance.stop(expectedUid: uid))
                .catchError((Object _) {}),
          );
        } else if (scope.name != state.userName) {
          state = state.copyWith(userName: scope.name);
        }
      },
      onError: (Object error) {
        if (current() &&
            error is FirebaseException &&
            error.code == 'permission-denied') {
          ++_profileGeneration;
          _profileSub?.cancel();
          _profileSub = null;
          _profileUid = null;
          ++_sessionGeneration;
          _circleSub?.cancel();
          _inviteSub?.cancel();
          state = initial.copyWith(userId: uid, accountUnavailable: true);
          final stop = _stopSharing;
          unawaited(
            (stop != null
                    ? stop(uid)
                    : LocationService.instance.stop(expectedUid: uid))
                .catchError((Object _) {}),
          );
        }
      },
    );
  }

  void _subscribeToCircle(String circleId) {
    _watchOwnProfile();
    final generation = ++_sessionGeneration;
    _circleSub?.cancel();
    _inviteSub?.cancel();
    if (circleId.isEmpty || Firebase.apps.isEmpty) return;
    final service = AuthService();
    _circleSub = service
        .streamCircle(circleId)
        .listen(
          (circle) {
            if (!mounted || generation != _sessionGeneration) return;
            if (circle == null) {
              _loseCircleAccess(circleId);
              return;
            }
            state = state.copyWith(circleName: circle.name);
          },
          onError: (Object error) {
            if (mounted &&
                generation == _sessionGeneration &&
                error is FirebaseException &&
                error.code == 'permission-denied') {
              _loseCircleAccess(circleId);
            }
          },
        );
    if (state.role == UserRole.parent) {
      _inviteSub = service.streamInvites(circleId).listen((data) {
        if (!mounted || generation != _sessionGeneration) return;
        final expiry = data?['expiresAt'];
        state = state.copyWith(
          childInviteCode: data?['childInviteCode'] as String? ?? '',
          parentInviteCode: data?['parentInviteCode'] as String? ?? '',
          inviteExpiresAt: expiry is Timestamp
              ? expiry.toDate()
              : expiry is String
              ? DateTime.tryParse(expiry)
              : null,
        );
      }, onError: (Object _) {});
    }
  }

  void _loseCircleAccess(String circleId) {
    final uid = state.userId;
    _revokedCircleId = circleId;
    ++_sessionGeneration;
    _circleSub?.cancel();
    _inviteSub?.cancel();
    state = initial.copyWith(
      userId: uid,
      userName: state.userName,
      accountUnavailable: true,
    );
    final stop = _stopSharing;
    unawaited(
      (stop != null
              ? stop(uid)
              : LocationService.instance.stop(expectedUid: uid))
          .catchError((Object _) {}),
    );
  }

  void setRole(UserRole role) {
    if (state.role == role) return;
    state = state.copyWith(
      role: role,
      childInviteCode: '',
      parentInviteCode: '',
      inviteExpiresAt: null,
    );
    _subscribeToCircle(state.circleId);
  }

  void setCircleName(String name) {
    state = state.copyWith(circleName: name);
  }

  void setUserName(String name) {
    if (name.trim().isNotEmpty) state = state.copyWith(userName: name.trim());
  }

  void setUserId(String uid) {
    if (state.userId == uid) return;
    state = state.copyWith(
      userId: uid,
      childInviteCode: '',
      parentInviteCode: '',
      inviteExpiresAt: null,
    );
    _subscribeToCircle(state.circleId);
  }

  void setCircleId(String id) {
    state = state.copyWith(
      circleId: id,
      childInviteCode: '',
      parentInviteCode: '',
      inviteExpiresAt: null,
    );
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
    _revokedCircleId = null;
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
    _revokedCircleId = null;
    ++_profileGeneration;
    _profileSub?.cancel();
    _profileSub = null;
    _profileUid = null;
    unawaited(LocationService.instance.stop().catchError((Object _) {}));
    _sessionGeneration++;
    _circleSub?.cancel();
    _inviteSub?.cancel();
    state = initial;
  }

  @override
  void dispose() {
    ++_profileGeneration;
    _profileSub?.cancel();
    _sessionGeneration++;
    _circleSub?.cancel();
    _inviteSub?.cancel();
    super.dispose();
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(),
);
