import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/features/settings/presentation/settings_screen.dart';
import 'package:family_guard/core/providers/member_status_provider.dart';
import 'package:family_guard/core/models/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/services/permission_service.dart';
import 'package:family_guard/features/onboarding/presentation/onboarding_screen.dart';
import 'package:family_guard/features/onboarding/presentation/permission_gate_screen.dart';

class _SettingsPermissions extends PermissionService {
  bool granted = false;
  @override
  Future<PermissionStatus> requestForegroundLocation() async =>
      PermissionStatus.permanentlyDenied;
  @override
  Future<PermissionStatus> foregroundLocationStatus() async =>
      granted ? PermissionStatus.granted : PermissionStatus.permanentlyDenied;
  @override
  Future<bool> openSystemAppSettings() async => true;
}

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double inset = 0,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: inset),
            ),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('setup remains reachable with large text and a keyboard', (
    tester,
  ) async {
    await show(tester, const OnboardingScreen(), inset: 220);
    for (final label in ['Get started']) {
      final action = find.widgetWithText(ElevatedButton, label);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final reveal = find.byTooltip('Show password');
    await tester.ensureVisible(reveal);
    await tester.tap(reveal);
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    final password = tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(password.obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreground permission recovers after returning from settings', (
    tester,
  ) async {
    final service = _SettingsPermissions();
    await show(
      tester,
      PermissionGateScreen(role: UserRole.child, service: service),
    );
    final allow = find.widgetWithText(ElevatedButton, 'Allow location');
    await tester.ensureVisible(allow);
    await tester.tap(allow);
    await tester.pumpAndSettle();
    final settings = find.widgetWithText(ElevatedButton, 'Open settings');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    service.granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Allow background location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings handles long names and unavailable invite codes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier()..setRole(UserRole.parent),
          ),
          memberStateProvider.overrideWith(
            (ref) => MemberStateNotifier(ref)
              ..state = [
                Member(
                  id: 'relative',
                  address: '',
                  lastSeen: DateTime.now(),
                  batteryLevel: 75,
                  speedMph: 0,
                  movementActivity: MovementActivity.stationary,
                  name: 'A very long family member name that wraps safely',
                  avatar: 'A',
                  role: UserRole.parent,
                ),
              ],
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byTooltip('Copy Child Invite Code'),
      150,
    );
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Copy Child Invite Code'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Copy Parent Invite Code'),
      150,
    );
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Copy Parent Invite Code'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Code unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
