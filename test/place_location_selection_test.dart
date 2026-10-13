import 'package:family_guard/core/models/member.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/providers/member_status_provider.dart';
import 'package:family_guard/features/places/presentation/widgets/add_edit_place_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
    'place picker explicitly selects fresh member and recenters after manual pin movement',
    (tester) async {
      final fresh = Member(
        id: 'child',
        name: 'Alex',
        avatar: 'A',
        role: UserRole.child,
        latitude: 34,
        longitude: 74,
        address: '',
        lastSeen: DateTime.now(),
        batteryLevel: 80,
        speedMph: 0,
        movementActivity: MovementActivity.stationary,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith(
              (ref) => AppStateNotifier()..setRole(UserRole.parent),
            ),
            memberStateProvider.overrideWith(
              (ref) => MemberStateNotifier(ref)
                ..state = [
                  fresh,
                  fresh.copyWith(id: 'old', name: 'Outdated', isStale: true),
                ],
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: AddEditPlaceDialog())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      var dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      final button = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(button.items!.map((item) => item.value), ['child']);
      expect(find.textContaining('Last shared by'), findsNothing);
      dropdown.onChanged!('child');
      await tester.pump();
      expect(find.textContaining('Last shared by Alex'), findsOneWidget);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markers.markers.single.point.latitude, 34);
      map.options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(35, 75),
      );
      await tester.pump();
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point
            .latitude,
        35,
      );
      final recenter = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Recenter on selected member'),
      );
      recenter.onPressed!();
      await tester.pump();
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point
            .latitude,
        34,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
