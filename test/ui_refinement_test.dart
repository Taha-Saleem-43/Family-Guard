import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_guard/core/models/place.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/theme/app_theme.dart';
import 'package:family_guard/features/home/presentation/widgets/bottom_nav.dart';
import 'package:family_guard/features/places/providers/places_provider.dart';
import 'package:family_guard/features/places/presentation/places_screen.dart';
import 'package:family_guard/features/alerts/presentation/alerts_screen.dart';

final _place = Place(
  id: 'home',
  circleId: 'family',
  name: 'Family home',
  address: 'A familiar place for your circle',
  category: PlaceCategory.home,
  radius: 200,
  latitude: 1,
  longitude: 2,
);

class _OfflinePlaces extends PlacesController {
  _OfflinePlaces(super.ref);
  @override
  Future<void> toggleArrivalNotification(Place place) async =>
      throw StateError('private detail');
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> showPlaces(
    WidgetTester tester,
    UserRole role, {
    double scale = 1,
    bool offline = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (offline)
            placesControllerProvider.overrideWith((ref) => _OfflinePlaces(ref)),
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier()
              ..setUserSession(
                userId: 'member',
                circleId: 'family',
                role: role,
              ),
          ),
          circlePlacesStreamProvider.overrideWith(
            (ref) => Stream.value([_place]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const PlacesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('children view places without editing or notification actions', (
    tester,
  ) async {
    await showPlaces(tester, UserRole.child);
    expect(find.text('Family home'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    final arrival = find.ancestor(
      of: find.text('Arrival alerts'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(arrival).onTap, isNull);
  });

  testWidgets('failed place edits show a recoverable message', (tester) async {
    await showPlaces(tester, UserRole.parent, offline: true);
    await tester.tap(find.text('Arrival alerts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not update this place'), findsOneWidget);
    expect(find.textContaining('private detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent place controls fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showPlaces(tester, UserRole.parent, scale: 1.6);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation and SOS remain actionable with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppTab? selected;
    var sos = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            bottomNavigationBar: BottomNav(
              activeTab: AppTab.map,
              onTabChanged: (tab) => selected = tab,
              onSos: () => sos = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Activity'));
    expect(selected, AppTab.alerts);
    await tester.tap(find.text('Send SOS'));
    expect(sos, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('places errors offer retry without technical error details', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circlePlacesStreamProvider.overrideWith((ref) {
            attempts++;
            return Stream<List<Place>>.error(
              StateError('private backend detail'),
            );
          }),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlacesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('private backend detail'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  // Export production widgets with fixture data for visual review; no golden baseline to maintain.
  testWidgets('export UI previews when explicitly enabled', (tester) async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    const fontDirectory = String.fromEnvironment('UI_PREVIEW_FONT_DIR');
    if (fontDirectory.isEmpty) {
      throw StateError('Set UI_PREVIEW_FONT_DIR to existing local SDK fonts.');
    }
    await tester.runAsync(() async {
      final fontData = ByteData.sublistView(
        await File('$fontDirectory/roboto-regular.ttf').readAsBytes(),
      );
      final theme = AppTheme.light();
      final families = <String>{
        for (final style in [
          theme.textTheme.bodyLarge,
          theme.textTheme.bodyMedium,
          theme.textTheme.bodySmall,
          theme.textTheme.titleLarge,
          theme.textTheme.titleMedium,
          theme.textTheme.titleSmall,
          theme.textTheme.labelLarge,
          theme.textTheme.labelMedium,
          theme.textTheme.labelSmall,
          theme.appBarTheme.titleTextStyle,
          GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ])
          if (style?.fontFamily != null) style!.fontFamily!,
      };
      for (final family in families) {
        await (FontLoader(family)..addFont(Future.value(fontData))).load();
      }
      await (FontLoader('MaterialIcons')..addFont(
            File(
              '$fontDirectory/materialicons-regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final activity in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith(
              (ref) => AppStateNotifier()
                ..setUserSession(
                  userId: 'member',
                  circleId: 'family',
                  role: UserRole.parent,
                ),
            ),
            circlePlacesStreamProvider.overrideWith(
              (ref) => Stream.value([_place]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: activity
                          ? const AlertsScreen()
                          : const PlacesScreen(),
                    ),
                    BottomNav(
                      activeTab: activity ? AppTab.alerts : AppTab.places,
                      onTabChanged: (_) {},
                      onSos: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'build/ui-previews/${activity ? 'activity' : 'places'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    debugDisableShadows = previousShadows;
  });
}
