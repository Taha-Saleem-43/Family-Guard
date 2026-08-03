import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../sos/presentation/widgets/sos_overlay.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showSOS = false;
  String? _selectedMemberId = 'm1';

  final List<Map<String, dynamic>> _mockMembers = [
    {
      'id': 'm1',
      'name': 'Emma (You)',
      'role': 'Child',
      'avatar': '👩‍🦰',
      'location': 'At School',
      'address': '742 Evergreen Terrace, Springfield',
      'battery': 88,
      'status': 'Stationary',
      'lastSeen': 'Just now',
      'color': AppColors.teal,
    },
    {
      'id': 'm2',
      'name': 'Lucas',
      'role': 'Child',
      'avatar': '👦',
      'location': 'En route to Soccer Practice',
      'address': 'Main Street & 5th Ave',
      'battery': 42,
      'status': 'Moving (18 mph)',
      'lastSeen': '2 mins ago',
      'color': AppColors.primary,
    },
    {
      'id': 'm3',
      'name': 'Dad (Alex)',
      'role': 'Parent',
      'avatar': '👨',
      'location': 'At Work',
      'address': 'Tech Park Tower 4',
      'battery': 95,
      'status': 'Stationary',
      'lastSeen': '5 mins ago',
      'color': const Color(0xFF8B5CF6),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final isParent = appState.role == UserRole.parent;

    return Stack(
      children: [
        // Simulated Interactive Map Canvas
        Container(
          color: const Color(0xFFE2E8F0),
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // Grid background decoration for map look
              CustomPaint(
                size: Size.infinite,
                painter: _MapGridPainter(),
              ),
              // Location Pin Markers
              Positioned(
                top: 180,
                left: 100,
                child: _buildMapPin(_mockMembers[0], isSelected: _selectedMemberId == 'm1'),
              ),
              if (isParent) ...[
                Positioned(
                  top: 280,
                  right: 90,
                  child: _buildMapPin(_mockMembers[1], isSelected: _selectedMemberId == 'm2'),
                ),
                Positioned(
                  top: 120,
                  right: 140,
                  child: _buildMapPin(_mockMembers[2], isSelected: _selectedMemberId == 'm3'),
                ),
              ],
            ],
          ),
        ),

        // Child Top Notification Chip
        if (!isParent)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sharing location with Dad (Parent)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),

        // Floating SOS Button (Always Accessible)
        Positioned(
          right: 16,
          bottom: isParent ? 260 : 120,
          child: GestureDetector(
            onTap: () => setState(() => _showSOS = true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.sosRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sosRed.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.sos_rounded, size: 32, color: Colors.white),
            ),
          ),
        ),

        // Parent Bottom Member Sheet
        if (isParent)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 240,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appState.circleName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_mockMembers.length} members',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mockMembers.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final member = _mockMembers[index];
                        final isSelected = _selectedMemberId == member['id'];

                        return GestureDetector(
                          onTap: () => setState(() => _selectedMemberId = member['id']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryLight : AppColors.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(member['avatar'], style: const TextStyle(fontSize: 24)),
                                    const Spacer(),
                                    Icon(Icons.battery_4_bar_rounded, size: 16, color: (member['battery'] as int) < 50 ? AppColors.sosRed : AppColors.teal),
                                    Text('${member['battery']}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  member['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  member['location'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
            ),
          ),

        // SOS Overlay Trigger
        if (_showSOS)
          SOSOverlay(
            onCancel: () => setState(() => _showSOS = false),
            onActivated: () {
              // SOS alert callback
            },
          ),
      ],
    );
  }

  Widget _buildMapPin(Map<String, dynamic> member, {required bool isSelected}) {
    final color = member['color'] as Color;

    return GestureDetector(
      onTap: () => setState(() => _selectedMemberId = member['id']),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 3 : 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: isSelected ? 22 : 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(member['avatar'], style: TextStyle(fontSize: isSelected ? 22 : 18)),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Text(
              member['name'],
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
