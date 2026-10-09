import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracelet/tracelet.dart' as tl;
import 'core/providers/app_state_provider.dart';
import 'core/presentation/local_privacy_gate.dart';
import 'core/services/firestore_privacy_service.dart';
import 'core/services/location_service.dart';
import 'core/services/location_sync_service.dart';
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
// Reuses the authenticated sync path without requiring the widget tree.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void backgroundLocationHandler(tl.HeadlessEvent event) async {
  if (event.name == 'location' || event.name == 'heartbeat') {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
    }
    await FirebaseAuth.instance.authStateChanges().first;
    FirestorePrivacyService.configureMemoryCache();
    final location = event.name == 'heartbeat'
        ? tl.HeartbeatEvent.fromMap(event.event).location
        : tl.Location.fromMap(event.event);
    await LocationSyncService.ingest(location);
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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
  runApp(
    LocalPrivacyGate(
      prepare: FirestorePrivacyService.prepareForeground,
      child: const ProviderScope(child: FamilyGuardApp()),
    ),
  );
}

class FamilyGuardApp extends ConsumerStatefulWidget {
  const FamilyGuardApp({super.key});

  @override
  ConsumerState<FamilyGuardApp> createState() => _FamilyGuardAppState();
}

class _FamilyGuardAppState extends ConsumerState<FamilyGuardApp> {
  bool _restoring = true;
  String? _restoreError;
  StreamSubscription<User?>? _authSubscription;

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _restoreError = null;
    });
    try {
      await ref.read(appStateProvider.notifier).checkRestoreSession();
    } catch (_) {
      if (mounted) {
        setState(
          () => _restoreError =
              'Unable to verify your account. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
    if (Firebase.apps.isNotEmpty) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (user == null && mounted) {
          ref.read(appStateProvider.notifier).resetToOnboarding();
          unawaited(LocationService.instance.stop().catchError((Object _) {}));
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    return MaterialApp(
      title: 'Family Guard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _restoreError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_restoreError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _restore,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : appState.stage == AppStage.onboarding
          ? const OnboardingScreen()
          : const MainShellScreen(),
    );
  }
}
