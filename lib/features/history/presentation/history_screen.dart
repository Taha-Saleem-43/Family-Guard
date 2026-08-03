import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedTab = 0; // 0: Today, 1: 7 Days, 2: 30 Days

  final List<Map<String, dynamic>> _mockTimeline = [
    {
      'time': '3:15 PM',
      'title': 'Arrived at Home',
      'address': '742 Evergreen Terrace',
      'duration': 'Current location',
      'icon': Icons.home_rounded,
      'color': AppColors.teal,
    },
    {
      'time': '2:45 PM - 3:15 PM',
      'title': 'In Transit (Drive)',
      'address': 'Springfield High School ➔ Home',
      'duration': '3.2 miles • 30 mins',
      'icon': Icons.directions_car_rounded,
      'color': AppColors.primary,
    },
    {
      'time': '8:30 AM - 2:45 PM',
      'title': 'Springfield High School',
      'address': '123 Education Lane',
      'duration': '6 hrs 15 mins',
      'icon': Icons.school_rounded,
      'color': const Color(0xFF8B5CF6),
    },
    {
      'time': '8:10 AM - 8:30 AM',
      'title': 'In Transit (Walk)',
      'address': 'Home ➔ Springfield High School',
      'duration': '0.8 miles • 20 mins',
      'icon': Icons.directions_walk_rounded,
      'color': AppColors.primary,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Location History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Today', '7 Days', '30 Days'].asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;
                final isSelected = _selectedTab == idx;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Route Map Graphic Header
          Container(
            height: 140,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.route_rounded, size: 40, color: AppColors.primary),
                      SizedBox(height: 4),
                      Text(
                        'Route Map Timeline',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Timeline Log List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _mockTimeline.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _mockTimeline[index];
                final icon = item['icon'] as IconData;
                final color = item['color'] as Color;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, size: 24, color: color),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['title'],
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    item['time'],
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['address'],
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['duration'],
                                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
