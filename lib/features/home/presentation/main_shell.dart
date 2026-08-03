import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../presentation/widgets/bottom_nav.dart';
import '../../map/presentation/map_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../places/presentation/places_screen.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    Widget buildBody() {
      switch (appState.activeTab) {
        case AppTab.map:
          return const MapScreen();
        case AppTab.history:
          return const HistoryScreen();
        case AppTab.places:
          return const PlacesScreen();
        case AppTab.alerts:
          return const AlertsScreen();
        case AppTab.settings:
          return const SettingsScreen();
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: buildBody()),
            BottomNav(
              activeTab: appState.activeTab,
              onTabChanged: (tab) {
                ref.read(appStateProvider.notifier).setActiveTab(tab);
              },
            ),
          ],
        ),
      ),
    );
  }
}
