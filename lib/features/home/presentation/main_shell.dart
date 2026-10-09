import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/permission_service.dart';
import '../presentation/widgets/bottom_nav.dart';
import '../../map/presentation/map_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../places/presentation/places_screen.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sos/presentation/widgets/emergency_host.dart';

// Converted to ConsumerStatefulWidget so we can call LocationService
// in initState (lifecycle) rather than every build() call.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so the widget tree is fully built
    // and ref is valid before we touch state.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTracking());
  }

  Future<void> _initTracking() async {
    final initial = ref.read(appStateProvider);
    final role = initial.role;

    // Only child devices broadcast location.
    // Parents read from Firestore (Step 7) — they don't run the tracker.
    if (role != UserRole.child) return;

    try {
      final permissions = await PermissionService().getPermissionSummary();
      if (!mounted || !permissions.canOperate) return;
      await LocationService.instance.init();
      if (!mounted) return;
      final current = ref.read(appStateProvider);
      if (current.role != UserRole.child ||
          current.userId != initial.userId ||
          current.circleId != initial.circleId) {
        return;
      }
      await LocationService.instance.start(
        uid: current.userId,
        circleId: current.circleId,
      );
    } catch (e) {
      // Non-fatal in Step 6 — failure is visible in the debug log.
      // Step 11 adds the full error-handling pass with banners and Crashlytics.
      debugPrint('[LocationService] init/start error: $e');
    }
  }

  @override
  void dispose() {
    // Do NOT stop tracking on dispose — the foreground service must persist
    // after the widget is unmounted (e.g. screen rotation, navigation).
    // Tracking is stopped only on explicit sign-out (Step 13).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    return EmergencyHost(
      child: Scaffold(
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
      ),
    );
  }
}
