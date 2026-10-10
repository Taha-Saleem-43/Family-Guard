import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/services/permission_service.dart';
import 'package:family_guard/features/onboarding/presentation/permission_gate_screen.dart';

class _Permissions extends PermissionService {
  final foreground = Completer<PermissionStatus>();
  final notifications = Completer<PermissionStatus>();
  int oemQueries = 0;
  int foregroundRequests = 0;
  @override
  Future<bool> get requiresOemAutoStartStep async {
    oemQueries++;
    return false;
  }

  @override
  Future<PermissionStatus> requestForegroundLocation() {
    foregroundRequests++;
    return foreground.future;
  }

  @override
  Future<PermissionStatus> requestNotifications() => notifications.future;
}

void main() {
  Widget gate(UserRole role, _Permissions service) => ProviderScope(
    child: MaterialApp(
      home: PermissionGateScreen(role: role, service: service),
    ),
  );
  testWidgets(
    'parents can finish with notifications only and no tracking prompts',
    (tester) async {
      final service = _Permissions();
      await tester.pumpWidget(gate(UserRole.parent, service));
      expect(find.text('Allow location access'), findsNothing);
      expect(find.text('1 of 1'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Allow notifications'),
      );
      service.notifications.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();
      expect(find.text("You're all set!"), findsOneWidget);
      expect(find.text('Location (foreground)'), findsNothing);
      expect(find.text('Keep tracking reliable'), findsNothing);
      expect(service.oemQueries, 0);
      expect(service.foregroundRequests, 0);
    },
  );
  testWidgets(
    'permission response after route disposal does not update disposed state',
    (tester) async {
      final service = _Permissions();
      await tester.pumpWidget(gate(UserRole.child, service));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Allow location'));
      await tester.pumpWidget(const SizedBox());
      service.foreground.complete(PermissionStatus.granted);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('platform failure releases the permission button for retry', (
    tester,
  ) async {
    final service = _Permissions();
    await tester.pumpWidget(gate(UserRole.parent, service));
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Allow notifications'),
    );
    service.notifications.completeError(StateError('platform unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not request permission. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Allow notifications'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
