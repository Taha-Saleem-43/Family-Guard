import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

/// Always visible on the map; wraps with large text instead of clipping.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.95),
    child: InkWell(
      onTap: () async {
        var opened = false;
        try {
          opened = await launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          // Platform link failures must not become unhandled UI exceptions.
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Could not open map credits. Please try again.'),
            ),
          );
        }
      },
      child: Semantics(
        link: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              '© OpenStreetMap contributors',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
