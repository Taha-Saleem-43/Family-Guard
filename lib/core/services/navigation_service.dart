import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  NavigationService._();

  /// Launches native turn-by-turn navigation (Google Maps / Apple Maps / Web fallback)
  /// to the target latitude and longitude coordinates.
  static Future<bool> launchTurnByTurnNavigation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final String labelQuery = Uri.encodeComponent(label ?? "Child Location");
    final Uri geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($labelQuery)');
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');

    // 1. Try native geo URI scheme (native Google Maps / Apple Maps intent)
    try {
      if (await canLaunchUrl(geoUri)) {
        final bool launched = await launchUrl(
          geoUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (e) {
      debugPrint('[NavigationService] Geo URI check failed: $e');
    }

    // 2. Try standard Google Maps web/app deep link with canLaunchUrl check
    try {
      if (await canLaunchUrl(googleMapsUri)) {
        final bool launched = await launchUrl(
          googleMapsUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (e) {
      debugPrint('[NavigationService] Google Maps URI check failed: $e');
    }

    // 3. Direct launch fallbacks (bypasses canLaunchUrl restriction on Android 11+ / iOS)
    try {
      return await launchUrl(
        googleMapsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      try {
        return await launchUrl(
          googleMapsUri,
          mode: LaunchMode.platformDefault,
        );
      } catch (err) {
        debugPrint('[NavigationService] All navigation launch fallbacks failed: $err');
        return false;
      }
    }
  }
}
