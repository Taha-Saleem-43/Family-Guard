import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/member.dart';
import '../../../../core/models/movement_activity.dart';
import '../../../../core/providers/app_state_provider.dart';
import '../../../../core/providers/member_status_provider.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/theme/app_colors.dart';

class MemberDetailSheet extends ConsumerWidget {
  final Member member;

  const MemberDetailSheet({super.key, required this.member});

  static void show(BuildContext context, Member member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberDetailSheet(member: member),
    );
  }

  String _getRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final isViewerParent = appState.role == UserRole.parent;
    final selfId = appState.userId.isNotEmpty ? appState.userId : 'm_self';

    // Watch current member list in case state changes live
    final members = ref.watch(memberStateProvider);
    final currentMember = members.firstWhere((m) => m.id == member.id, orElse: () => member);

    final activity = currentMember.movementActivity;
    final batColor = BatteryHelper.getColor(currentMember.batteryLevel);
    final batIcon = BatteryHelper.getIcon(currentMember.batteryLevel, isCharging: currentMember.isCharging);
    final isTargetParent = currentMember.role == UserRole.parent;
    final isSelf = currentMember.id == selfId ||
        currentMember.id == 'm_self' ||
        currentMember.name.contains('(You)') ||
        (appState.userId.isNotEmpty && currentMember.id == appState.userId);

    // Get Directions is ONLY available when a Parent is viewing ANOTHER member who is a Child
    final canGetDirections = isViewerParent &&
        !isSelf &&
        currentMember.role == UserRole.child &&
        currentMember.latitude != null &&
        currentMember.longitude != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag handle indicator bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Avatar, Name, Role Badge, and Close Button
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: currentMember.pinColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: currentMember.pinColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: currentMember.pinColor.withValues(alpha: 0.15),
                      child: Text(currentMember.avatar, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: activity.color, width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text(activity.emoji, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          currentMember.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isTargetParent ? AppColors.primaryLight : AppColors.tealLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isTargetParent ? 'Parent' : 'Child',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isTargetParent ? AppColors.primary : AppColors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live Tracking Details',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary "Get Directions" Button (Only available for Parent viewing Child)
          if (canGetDirections) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final success = await NavigationService.launchTurnByTurnNavigation(
                    latitude: currentMember.latitude!,
                    longitude: currentMember.longitude!,
                    label: currentMember.name,
                  );
                  if (context.mounted && !success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to launch navigation maps app.')),
                    );
                  }
                },
                icon: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Get Directions to ${currentMember.name.split(' ').first} 🚗',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2x2 Grid of Status Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              // 1. Speed & Movement Activity Card
              _buildDetailCard(
                icon: activity.icon,
                iconColor: activity.color,
                bgColor: activity.bgColor,
                title: 'Speed & Motion',
                value: '${currentMember.speedMph.toStringAsFixed(1)} mph',
                subtitle: '${activity.emoji} ${activity.label}',
              ),

              // 2. Battery Status Badge Card
              _buildBatteryCard(
                batLevel: currentMember.batteryLevel,
                isCharging: currentMember.isCharging,
                batColor: batColor,
                batIcon: batIcon,
              ),

              // 3. Location Address Card
              _buildDetailCard(
                icon: Icons.location_on_rounded,
                iconColor: AppColors.primary,
                bgColor: AppColors.primaryLight,
                title: 'Address',
                value: currentMember.address,
                subtitle: 'Lat: ${currentMember.latitude?.toStringAsFixed(4) ?? "33.6844"} • Lng: ${currentMember.longitude?.toStringAsFixed(4) ?? "73.0479"}',
              ),

              // 4. Timestamp Card
              _buildDetailCard(
                icon: Icons.access_time_filled_rounded,
                iconColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                title: 'Timestamp',
                value: _getRelativeTime(currentMember.lastSeen),
                subtitle: DateFormat('h:mm:ss a').format(currentMember.lastSeen),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard({
    required int batLevel,
    required bool isCharging,
    required Color batColor,
    required IconData batIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: batColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: batColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(batIcon, size: 18, color: batColor),
              const SizedBox(width: 6),
              Text(
                'Battery Status',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
              ),
            ],
          ),

          Row(
            children: [
              Text(
                '$batLevel%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: batColor),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: batColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCharging ? 'Charging ⚡' : (batLevel < 20 ? 'Low 🪫' : 'Good 🔋'),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: batColor),
                ),
              ),
            ],
          ),

          // Visual Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: batLevel / 100.0,
              backgroundColor: batColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(batColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
