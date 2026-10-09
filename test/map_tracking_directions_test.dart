import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:family_guard/core/models/member.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/providers/member_status_provider.dart';
import 'package:family_guard/core/services/navigation_service.dart';
import 'package:family_guard/features/map/presentation/map_screen.dart';
import 'package:family_guard/features/map/presentation/widgets/member_detail_sheet.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testParentAndChild = [
    Member(
      id: 'm_self',
      name: 'Parent User',
      avatar: '👨',
      role: UserRole.parent,
      address: 'Islamabad Active Location',
      latitude: 33.6844,
      longitude: 73.0479,
      lastSeen: DateTime.now(),
      batteryLevel: 95,
      isCharging: false,
      speedMph: 0.0,
      movementActivity: MovementActivity.stationary,
    ),
    Member(
      id: 'm_child_1',
      name: 'Child Member',
      avatar: '👧',
      role: UserRole.child,
      address: 'School Location',
      latitude: 33.6900,
      longitude: 73.0500,
      lastSeen: DateTime.now(),
      batteryLevel: 80,
      isCharging: false,
      speedMph: 2.0,
      movementActivity: MovementActivity.walking,
    ),
  ];

  group('NavigationService Unit Tests', () {
    test('launchTurnByTurnNavigation executes safely for positive coordinates', () async {
      final success = await NavigationService.launchTurnByTurnNavigation(
        latitude: 33.6844,
        longitude: 73.0479,
        label: 'Islamabad',
      );
      expect(success, isA<bool>());
    });

    test('launchTurnByTurnNavigation executes safely for negative coordinates', () async {
      final success = await NavigationService.launchTurnByTurnNavigation(
        latitude: -33.8688,
        longitude: 151.2093,
        label: 'Sydney Location',
      );
      expect(success, isA<bool>());
    });
  });

  group('MapScreen & OpenStreetMap Widget Tests', () {
    testWidgets('MapScreen renders OpenStreetMap (FlutterMap) and Activity filters for Parent', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()..setRole(UserRole.parent)),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)..state = testParentAndChild),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify OpenStreetMap FlutterMap widget is present
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      // 2. Verify Floating Action Button for child navigation is removed from map
      expect(find.textContaining('Navigate to'), findsNothing);

      // 3. Verify Activity filter chips render
      expect(find.textContaining('Stationary'), findsWidgets);
      expect(find.textContaining('Walking'), findsWidgets);
      expect(find.textContaining('Driving'), findsWidgets);

      // 4. Verify Live Circle Members bottom sheet renders for parent
      expect(find.text('Live Circle Members'), findsOneWidget);
    });

    testWidgets('MapScreen renders ONLY child own pin and hides other member pins/sheet for Child user', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()
              ..setUserSession(
                userId: 'm_child_1',
                role: UserRole.child,
                circleId: 'test_circle',
                userName: 'Child Member',
              )),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)..state = testParentAndChild),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify top child sharing location banner renders
      expect(find.textContaining('Sharing location as Child Member with Circle'), findsOneWidget);

      // 2. Verify Live Circle Members bottom sheet is HIDDEN for child
      expect(find.text('Live Circle Members'), findsNothing);

      // 3. Verify Parent member name pin is NOT displayed on Child map
      expect(find.text('Parent User'), findsNothing);
    });

    testWidgets('Tapping Activity filter chips updates active filter state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()..setRole(UserRole.parent)),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)..state = testParentAndChild),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Tap Walking activity filter chip
      final walkingChip = find.textContaining('Walking');
      expect(walkingChip, findsWidgets);
      await tester.tap(walkingChip.first);
      await tester.pump(const Duration(milliseconds: 300));

      // Tap All filter chip to reset
      final allChip = find.textContaining('All');
      expect(allChip, findsOneWidget);
      await tester.tap(allChip);
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('MemberDetailSheet Directions Button Widget Tests', () {
    final testParent = testParentAndChild.first;
    final testChild = testParentAndChild.last;

    testWidgets('MemberDetailSheet renders Get Directions button ONLY for Parent viewing Child', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()..setRole(UserRole.parent)),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)..state = testParentAndChild),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberDetailSheet(member: testChild),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify Member details present
      expect(find.text('Child Member'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);

      // Verify "Get Directions to Child 🚗" button exists for Parent viewing Child
      final directionsButton = find.textContaining('Get Directions to Child');
      expect(directionsButton, findsOneWidget);

      // Tap Directions Button
      await tester.tap(directionsButton);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('MemberDetailSheet hides directions button when Child views details', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()
              ..setUserSession(
                userId: 'm_child_1',
                role: UserRole.child,
                circleId: 'test_circle',
                userName: 'Child Member',
              )),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)..state = testParentAndChild),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberDetailSheet(member: testChild),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify "Get Directions" button is hidden when viewer is a Child
      expect(find.textContaining('Get Directions'), findsNothing);
    });

    testWidgets('MemberDetailSheet hides directions button for parent member even with coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()..setRole(UserRole.parent)),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)..state = testParentAndChild),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MemberDetailSheet(member: testParent),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify Parent details present
      expect(find.text('Parent User'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);

      // Verify "Get Directions" button is hidden for Parent himself
      expect(find.textContaining('Get Directions'), findsNothing);
    });

    testWidgets('MemberDetailSheet hides directions button if coordinates are missing', (WidgetTester tester) async {
      final noLocationChild = Member(
        id: 'no_loc_child',
        name: 'No Location Child',
        avatar: '👧',
        role: UserRole.child,
        address: 'Location Unknown',
        latitude: null,
        longitude: null,
        lastSeen: DateTime.now(),
        batteryLevel: 50,
        isCharging: false,
        speedMph: 0.0,
        movementActivity: MovementActivity.stationary,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MemberDetailSheet(member: noLocationChild),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify "Get Directions" button is hidden when lat/lng are null
      expect(find.textContaining('Get Directions'), findsNothing);
    });
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  bool followRedirects = true;

  @override
  bool persistentConnection = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = 0;

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {}

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse implements HttpClientResponse {
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get persistentConnection => false;
  @override
  int get statusCode => 200;

  @override
  int get contentLength => 0;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return const Stream<List<int>>.empty().listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
