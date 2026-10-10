import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/member.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/providers/member_status_provider.dart';
import 'package:family_guard/features/map/presentation/widgets/member_detail_sheet.dart';
import 'package:family_guard/core/presentation/member_activity_status.dart';

void main() {
  Member member({
    String id = 'other',
    UserRole role = UserRole.child,
    bool stale = false,
    bool located = true,
  }) => Member(
    id: id,
    name: 'Family member with a very long name (You)',
    avatar: 'A',
    role: role,
    latitude: located ? 33 : null,
    longitude: located ? 73 : null,
    accuracyMeters: located ? 18 : null,
    address: 'Last shared coordinates',
    lastSeen: DateTime.now().subtract(Duration(minutes: stale ? 30 : 0)),
    batteryLevel: 80,
    speedMph: 0,
    movementActivity: MovementActivity.stationary,
  );
  Future<void> show(WidgetTester tester, Member target, UserRole viewer) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier()..setRole(viewer),
          ),
          memberStateProvider.overrideWith(
            (ref) => MemberStateNotifier(ref)..state = [target],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberDetailSheet(member: target),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  test('current movement requires fresh valid coordinates', () {
    final fresh = member().copyWith(movementActivity: MovementActivity.walking);
    expect(fresh.currentActivity, MovementActivity.walking);
    expect(fresh.copyWith(isStale: true).currentActivity, isNull);
    expect(member(stale: true).currentActivity, isNull);
    expect(member(located: false).currentActivity, isNull);
    expect(fresh.copyWith(latitude: 100).currentActivity, isNull);
    expect(
      fresh
          .copyWith(lastSeen: DateTime.now().add(const Duration(minutes: 2)))
          .currentActivity,
      isNull,
    );
    // Aging changes presentation without deleting the captured movement.
    expect(
      fresh.copyWith(isStale: true).movementActivity,
      MovementActivity.walking,
    );
  });

  testWidgets(
    'stale positions keep Maps available with an explicit warning and accuracy',
    (tester) async {
      await show(tester, member(stale: true), UserRole.parent);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      expect(find.textContaining('Location may be outdated'), findsOneWidget);
      expect(find.text('Reported accuracy: ±18 m'), findsOneWidget);
      expect(find.textContaining('Activity unknown'), findsOneWidget);
      expect(find.text('0.0 mph'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('parents can open another parent location', (tester) async {
    await show(tester, member(role: UserRole.parent), UserRole.parent);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('Get directions'), findsOneWidget);
  });
  testWidgets(
    'children can open self but cannot hand off another member location',
    (tester) async {
      await show(tester, member(id: 'm_self'), UserRole.child);
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.text('Get directions'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await show(tester, member(), UserRole.child);
      expect(find.text('Open in Google Maps'), findsNothing);
      expect(find.text('Get directions'), findsNothing);
    },
  );
  testWidgets(
    'missing positions have no external action or invented coordinates',
    (tester) async {
      await show(tester, member(located: false), UserRole.parent);
      expect(find.text('Open in Google Maps'), findsNothing);
      expect(find.text('Get directions'), findsNothing);
      expect(find.text('Coordinates unavailable'), findsOneWidget);
      expect(find.text('Location not available yet.'), findsOneWidget);
    },
  );
}
