import 'package:url_launcher/url_launcher.dart';

enum SupportDestination { privacy, deletion, email }

typedef SupportUrlLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

class SupportLinks {
  SupportLinks._();
  static const email = 'tahasaleemdev@gmail.com';
  static const origin =
      'https://familyguard-privacy-support.paleluck4097.chatgpt.site';

  static Uri uri(SupportDestination destination) => switch (destination) {
    SupportDestination.privacy => Uri.parse('$origin/privacy/'),
    SupportDestination.deletion => Uri.parse('$origin/delete-account/'),
    SupportDestination.email => Uri(scheme: 'mailto', path: email),
  };

  static Future<bool> open(
    SupportDestination destination, {
    SupportUrlLauncher? launcher,
  }) async {
    final launch =
        launcher ?? (Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);
    try {
      return await launch(uri(destination), LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
