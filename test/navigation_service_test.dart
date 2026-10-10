import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_guard/core/services/navigation_service.dart';

void main() {
  test('search opens exact coordinates without member names', () async {
    late Uri captured;
    expect(
      await NavigationService.openInGoogleMaps(
        latitude: -33.8688,
        longitude: 151.2093,
        launcher: (url, mode) async {
          captured = url;
          expect(mode, LaunchMode.externalApplication);
          return true;
        },
      ),
      true,
    );
    expect(captured.host, 'www.google.com');
    expect(captured.path, '/maps/search/');
    expect(captured.queryParameters, {
      'api': '1',
      'query': '-33.8688,151.2093',
    });
  });
  test(
    'directions request navigation without fixing origin or travel mode',
    () async {
      await NavigationService.launchTurnByTurnNavigation(
        latitude: 0,
        longitude: 0,
        label: 'Private child name',
        launcher: (url, mode) async {
          expect(url.queryParameters, {
            'api': '1',
            'destination': '0.0,0.0',
            'dir_action': 'navigate',
          });
          expect(url.path, '/maps/dir/');
          return true;
        },
      );
    },
  );
  for (final throws in [false, true]) {
    test(
      'browser fallback handles false and exceptions: ' + throws.toString(),
      () async {
        final modes = <LaunchMode>[];
        expect(
          await NavigationService.openInGoogleMaps(
            latitude: 33,
            longitude: 73,
            launcher: (url, mode) async {
              modes.add(mode);
              if (mode == LaunchMode.externalApplication) {
                if (throws) throw StateError('unavailable');
                return false;
              }
              return true;
            },
          ),
          true,
        );
        expect(modes, [
          LaunchMode.externalApplication,
          LaunchMode.platformDefault,
        ]);
      },
    );
  }
  test('both launch failures return false', () async {
    expect(
      await NavigationService.openInGoogleMaps(
        latitude: 33,
        longitude: 73,
        launcher: (_, mode) async => false,
      ),
      false,
    );
    expect(
      await NavigationService.openInGoogleMaps(
        latitude: 33,
        longitude: 73,
        launcher: (_, mode) async => throw StateError('unavailable'),
      ),
      false,
    );
  });
  test('invalid coordinates never reach external applications', () async {
    for (final coords in [
      (double.nan, 1.0),
      (1.0, double.infinity),
      (91.0, 0.0),
      (0.0, -181.0),
    ]) {
      expect(
        await NavigationService.openInGoogleMaps(
          latitude: coords.$1,
          longitude: coords.$2,
          launcher: (_, mode) async => fail('Invalid coordinate launched'),
        ),
        false,
      );
    }
    expect(NavigationService.hasValidCoordinates(null, 0), false);
  });
}
