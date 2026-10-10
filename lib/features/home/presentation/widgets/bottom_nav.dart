import 'package:flutter/material.dart';
import '../../../../core/providers/app_state_provider.dart';
import '../../../../core/theme/app_colors.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    this.onSos,
  });
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabChanged;
  final VoidCallback? onSos;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppColors.border),
        if (onSos != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Emergency help',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onSos,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.sosRed,
                    minimumSize: const Size(88, 48),
                  ),
                  icon: const Icon(Icons.sos_rounded),
                  label: const Text('Send SOS'),
                ),
              ],
            ),
          ),
        NavigationBar(
          height: 76,
          selectedIndex: AppTab.values.indexOf(activeTab),
          onDestinationSelected: (index) => onTabChanged(AppTab.values[index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place_rounded),
              label: 'Places',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ],
    ),
  );
}
