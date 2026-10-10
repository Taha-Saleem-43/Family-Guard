import 'package:url_launcher/url_launcher.dart';

typedef MapsUrlLauncher = Future<bool> Function(Uri url, LaunchMode mode);

/// Opens Google Maps using universal URLs, without an API key or Maps SDK.
class NavigationService {
  NavigationService._();

  static bool hasValidCoordinates(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  static Future<bool> openInGoogleMaps({
    required double latitude,
    required double longitude,
    MapsUrlLauncher? launcher,
  }) => _open(latitude, longitude, directions: false, launcher: launcher);

  static Future<bool> launchTurnByTurnNavigation({
    required double latitude,
    required double longitude,
    String? label,
    MapsUrlLauncher? launcher,
  }) => _open(latitude, longitude, directions: true, launcher: launcher);

  static Future<bool> _open(
    double latitude,
    double longitude, {
    required bool directions,
    MapsUrlLauncher? launcher,
  }) async {
    if (!hasValidCoordinates(latitude, longitude)) return false;
    final coordinates = '$latitude,$longitude';
    final url = Uri.https(
      'www.google.com',
      directions ? '/maps/dir/' : '/maps/search/',
      {
        'api': '1',
        if (directions) 'destination': coordinates else 'query': coordinates,
        if (directions) 'dir_action': 'navigate',
      },
    );
    final launch =
        launcher ?? (Uri url, LaunchMode mode) => launchUrl(url, mode: mode);
    // Universal links open the Google Maps app when installed, or a browser.
    // A false return and a platform exception both need a fallback.
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launch(url, mode)) return true;
      } catch (_) {
        // Do not log family coordinates or URLs.
      }
    }
    return false;
  }
}
