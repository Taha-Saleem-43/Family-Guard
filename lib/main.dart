import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracelet/tracelet.dart' as tl;
import 'core/providers/app_state_provider.dart';
import 'core/services/location_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/main_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'firebase_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Headless location callback — fires when Tracelet wakes the isolate
// after a reboot (startOnBoot: true) without a UI being active.
//
// Must be:
//   • A top-level function (not a method)
//   • Annotated @pragma('vm:entry-point') to survive release-build tree-shaking
//   • Registered with Tracelet.registerHeadlessTask() before runApp()
//
// Step 6 scope: writes to local SharedPreferences debug log only.
// Step 7 will add a Firestore write here once the sync layer is built.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void backgroundLocationHandler(tl.HeadlessEvent event) async {
  if (event.name == 'location' || event.name == 'heartbeat') {
    final location = tl.Location.fromMap(event.event);
    await LocationService.appendDebugLog(
      location,
      source: 'HEADLESS:${event.name.toUpperCase()}',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register headless task FIRST — before Firebase and before runApp.
  // Tracelet requires this to be the very first Tracelet call so it can
  // set up the background isolate entry-point before anything else runs.
  await tl.Tracelet.registerHeadlessTask(backgroundLocationHandler);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: FamilyGuardApp(),
    ),
  );
}

class FamilyGuardApp extends ConsumerWidget {
  const FamilyGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return MaterialApp(
      title: 'Family Guard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: appState.stage == AppStage.onboarding
          ? const OnboardingScreen()
          : const MainShellScreen(),
    );
  }
}
