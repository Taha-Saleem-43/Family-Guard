import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  final List<Map<String, dynamic>> _alerts = const [
    {
      'type': 'arrival',
      'title': 'Emma arrived at Home',
      'subtitle': 'Entered geofence (150m radius)',
      'time': '3:15 PM',
      'icon': Icons.where_to_vote_rounded,
      'color': AppColors.teal,
    },
    {
      'type': 'departure',
      'title': 'Emma left Springfield High School',
      'subtitle': 'Exited geofence',
      'time': '2:45 PM',
      'icon': Icons.directions_run_rounded,
      'color': AppColors.primary,
    },
    {
      'type': 'battery',
      'title': 'Lucas phone battery low (15%)',
      'subtitle': 'Remind Lucas to charge their device',
      'time': '1:20 PM',
      'icon': Icons.battery_alert_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'type': 'arrival',
      'title': 'Lucas arrived at Downtown Gym',
      'subtitle': 'Entered geofence',
      'time': '11:00 AM',
      'icon': Icons.where_to_vote_rounded,
      'color': AppColors.teal,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Activity Alerts'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final icon = alert['icon'] as IconData;
          final color = alert['color'] as Color;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'],
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert['subtitle'],
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    alert['time'],
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
