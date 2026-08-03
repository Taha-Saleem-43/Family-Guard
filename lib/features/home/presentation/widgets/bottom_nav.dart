import 'package:flutter/material.dart';
import '../../../../core/providers/app_state_provider.dart';
import '../../../../core/theme/app_colors.dart';

class BottomNav extends StatelessWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabChanged;

  const BottomNav({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'tab': AppTab.map, 'label': 'Map', 'icon': Icons.map_rounded},
      {'tab': AppTab.history, 'label': 'History', 'icon': Icons.history_rounded},
      {'tab': AppTab.places, 'label': 'Places', 'icon': Icons.place_rounded},
      {'tab': AppTab.alerts, 'label': 'Alerts', 'icon': Icons.notifications_rounded},
      {'tab': AppTab.settings, 'label': 'Settings', 'icon': Icons.settings_rounded},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final tab = item['tab'] as AppTab;
          final isSelected = activeTab == tab;
          final icon = item['icon'] as IconData;
          final label = item['label'] as String;

          return InkWell(
            onTap: () => onTabChanged(tab),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
