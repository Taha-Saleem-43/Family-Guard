import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/services/navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationService Unit Tests', () {
    test('launchTurnByTurnNavigation handles valid coordinates without crashing', () async {
      // In unit test environment, url_launcher cannot open external apps, but should handle call gracefully without throwing exceptions
      final result = await NavigationService.launchTurnByTurnNavigation(
        latitude: 33.7490,
        longitude: -84.3880,
        label: 'Test Child',
      );
      expect(result, isA<bool>());
    });
  });
}
