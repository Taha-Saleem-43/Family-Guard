import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_state_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/main_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
