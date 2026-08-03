import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final List<Map<String, dynamic>> _places = [
    {
      'name': 'Home',
      'category': 'Home',
      'address': '742 Evergreen Terrace',
      'radius': '150 meters',
      'icon': Icons.home_rounded,
      'color': AppColors.teal,
      'notifyArrive': true,
      'notifyLeave': true,
    },
    {
      'name': 'Springfield High School',
      'category': 'School',
      'address': '123 Education Lane',
      'radius': '200 meters',
      'icon': Icons.school_rounded,
      'color': AppColors.primary,
      'notifyArrive': true,
      'notifyLeave': true,
    },
    {
      'name': 'Downtown Gym',
      'category': 'Custom',
      'address': '45 Fitness Boulevard',
      'radius': '100 meters',
      'icon': Icons.fitness_center_rounded,
      'color': const Color(0xFF8B5CF6),
      'notifyArrive': false,
      'notifyLeave': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Saved Places'),
        actions: [
          IconButton(
            onPressed: () => _showAddPlaceDialog(context),
            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _places.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final place = _places[index];
          final icon = place['icon'] as IconData;
          final color = place['color'] as Color;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            Text(
                              place['name'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              place['address'],
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          place['radius'],
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            place['notifyArrive'] ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 16,
                            color: place['notifyArrive'] ? AppColors.teal : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          const Text('Arrival alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            place['notifyLeave'] ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 16,
                            color: place['notifyLeave'] ? AppColors.teal : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          const Text('Departure alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPlaceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add New Place', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Place Name (e.g. Grandma\'s House)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Address or Tap on Map',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save Place & Register Geofence'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
