import 'package:flutter/material.dart';
import '../services/support_links.dart';

/// Available before account creation as well as from signed-in settings.
class PrivacySupportLinks extends StatelessWidget {
  const PrivacySupportLinks({super.key, this.launcher, this.showEmail = true});
  final SupportUrlLauncher? launcher;
  final bool showEmail;

  Future<void> _open(
    BuildContext context,
    SupportDestination destination,
  ) async {
    if (!await SupportLinks.open(destination, launcher: launcher) &&
        context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            destination == SupportDestination.email
                ? 'Could not open email. Contact ${SupportLinks.email} using your email app.'
                : 'Could not open the page. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final item in [
        (SupportDestination.privacy, 'Privacy policy'),
        (SupportDestination.deletion, 'Account deletion'),
        if (showEmail) (SupportDestination.email, 'Contact support'),
      ])
        TextButton(
          onPressed: () => _open(context, item.$1),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(item.$2, textAlign: TextAlign.center),
        ),
    ],
  );
}
