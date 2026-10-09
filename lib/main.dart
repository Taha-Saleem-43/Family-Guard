import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracelet/tracelet.dart' as tl;
import 'core/providers/app_state_provider.dart';
import 'core/presentation/local_privacy_gate.dart';
import 'core/services/firestore_privacy_service.dart';
import 'core/services/location_service.dart';
import 'core/services/location_sync_service.dart';
import 'core/services/push_runtime.dart';
import 'core/models/push_envelope.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/main_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'firebase_options.dart';
import 'features/auth/services/auth_service.dart';

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
    if (event.name == 'heartbeat') await LocationSyncService.recover();
    await LocationService.appendDebugLog(
      location,
      source: 'HEADLESS:${event.name.toUpperCase()}',
    );
  }
}

@pragma('vm:entry-point')
Future<void> backgroundPushHandler(RemoteMessage message) async {
  final envelope = PushEnvelope.parse(message.data);
  if (envelope == null) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    await FirebaseAuth.instance.authStateChanges().first;
    await PushRuntime.acknowledge(envelope, 'received');
  } catch (_) {
    /* Receipt is best effort; acceptance is never labelled delivery. */
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register headless task FIRST — before Firebase and before runApp.
  // Tracelet requires this to be the very first Tracelet call so it can
  // set up the background isolate entry-point before anything else runs.
  await tl.Tracelet.registerHeadlessTask(backgroundLocationHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(backgroundPushHandler);
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

class _FamilyGuardAppState extends ConsumerState<FamilyGuardApp>
    with WidgetsBindingObserver {
  bool _restoring = true;
  String? _restoreError;
  StreamSubscription<User?>? _authSubscription;
  PushEnvelope? _pendingPush;
  int _pushOpenGeneration = 0;

  Future<void> _openPush(PushEnvelope envelope) async {
    if (!mounted) return;
    final account = ref.read(appStateProvider);
    if (_restoring || account.stage != AppStage.main) {
      _pendingPush = envelope;
      return;
    }
    _pendingPush = null;
    if (account.userId != envelope.recipientUid ||
        account.circleId != envelope.circleId) {
      return;
    }
    final generation = ++_pushOpenGeneration;
    try {
      final active = await PushRuntime.acknowledge(envelope, 'opened');
      if (!mounted || generation != _pushOpenGeneration) return;
      final current = ref.read(appStateProvider);
      if (active &&
          current.userId == envelope.recipientUid &&
          current.circleId == envelope.circleId) {
        ref.read(appStateProvider.notifier).setActiveTab(AppTab.alerts);
      }
    } catch (_) {
      /* The live emergency stream can still present verified alerts. */
    }
  }

  void _bindPush(AppState account) {
    if (Firebase.apps.isEmpty) return;
    final session = !_restoring && account.stage == AppStage.main;
    unawaited(
      ref
          .read(pushCoordinatorProvider.notifier)
          .bind(
            session ? account.userId : null,
            session ? account.circleId : null,
          ),
    );
    final pending = _pendingPush;
    if (session && pending != null) unawaited(_openPush(pending));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Firebase.apps.isNotEmpty) {
      unawaited(ref.read(pushCoordinatorProvider.notifier).refresh());
    }
  }

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
              Firebase.apps.isNotEmpty &&
                  FirebaseAuth.instance.currentUser == null
              ? null
              : 'Unable to verify your account. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_restore);
    if (Firebase.apps.isNotEmpty) {
      ref.read(pushCoordinatorProvider);
      unawaited(
        PushRuntime.active?.start(
              (envelope) => unawaited(_openPush(envelope)),
            ) ??
            Future.value(),
      );
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
    WidgetsBinding.instance.removeObserver(this);
    _pushOpenGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (_, next) => _bindPush(next));
    final appState = ref.watch(appStateProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bindPush(ref.read(appStateProvider));
    });

    return MaterialApp(
      key: ValueKey(
        appState.stage == AppStage.main
            ? ('main', appState.userId, appState.circleId, appState.role)
            : (
                appState.accountUnavailable ? 'blocked' : 'onboarding',
                appState.userId,
              ),
      ),
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
          : appState.accountUnavailable
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Your account or circle is unavailable.'),
                    const Text(
                      'Sharing is paused. Please verify your account again.',
                    ),
                    FilledButton(
                      onPressed: _restore,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await AuthService().signOut();
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _restoreError =
                                  'Could not finish signing out. Please retry.',
                            );
                          }
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            )
          : appState.stage == AppStage.onboarding
          ? const OnboardingScreen()
          : const MainShellScreen(),
    );
  }
}
