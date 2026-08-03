import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRole { parent, child }
enum AppStage { onboarding, main }
enum AppTab { map, history, places, alerts, settings }

class AppState {
  final AppStage stage;
  final UserRole role;
  final AppTab activeTab;
  final String circleName;

  const AppState({
    required this.stage,
    required this.role,
    required this.activeTab,
    required this.circleName,
  });

  AppState copyWith({
    AppStage? stage,
    UserRole? role,
    AppTab? activeTab,
    String? circleName,
  }) {
    return AppState(
      stage: stage ?? this.stage,
      role: role ?? this.role,
      activeTab: activeTab ?? this.activeTab,
      circleName: circleName ?? this.circleName,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier()
      : super(const AppState(
          stage: AppStage.onboarding,
          role: UserRole.parent,
          activeTab: AppTab.map,
          circleName: 'The Johnson Family',
        ));

  void setRole(UserRole role) {
    state = state.copyWith(role: role);
  }

  void completeOnboarding(UserRole role, [String? circleName]) {
    state = state.copyWith(
      stage: AppStage.main,
      role: role,
      activeTab: AppTab.map,
      circleName: circleName ?? state.circleName,
    );
  }

  void setActiveTab(AppTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  void resetToOnboarding() {
    state = state.copyWith(stage: AppStage.onboarding);
  }
}

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
