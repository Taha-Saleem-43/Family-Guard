import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/history_timeline_item.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/member_status_provider.dart';
import '../../../core/services/history_cron_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedHistoryTimeframeProvider);
    final members = ref.watch(memberStateProvider);
    final appState = ref.watch(appStateProvider);
    final selectedMemberId = ref.watch(selectedHistoryMemberIdProvider) ?? appState.userId;
    final timelineItems = ref.watch(historyTimelineProvider);
    final polylinePoints = ref.watch(historyRoutePolylineProvider);
    final cronStatus = ref.watch(historyCronStatusProvider);

    final selectedMember = members.firstWhere(
      (m) => m.id == selectedMemberId || m.id == 'm_self',
      orElse: () => members.isNotEmpty ? members.first : members.first,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Location History'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rawLocationHistoryProvider);
          await HistoryCronService.instance.runPurgeIfNeeded(uid: selectedMemberId);
        },
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Member Selector Bar (compact horizontal chips)
            if (members.length > 1)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isSelected = member.id == selectedMemberId || (selectedMemberId.isEmpty && index == 0);

                    return ChoiceChip(
                      avatar: Text(member.avatar, style: const TextStyle(fontSize: 14)),
                      label: Text(member.name),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(selectedHistoryMemberIdProvider.notifier).state = member.id;
                        }
                      },
                    );
                  },
                ),
              ),
            if (members.length > 1) const SizedBox(height: 10),

            // Timeframe Selection Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['Today', '7 Days', '30 Days'].asMap().entries.map((entry) {
                  final idx = entry.key;
                  final text = entry.value;
                  final isSelected = selectedTab == idx;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(selectedHistoryTimeframeProvider.notifier).state = idx;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
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
            const SizedBox(height: 8),
            // Route Map Preview Header
            Container(
              height: 180,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Map preview with polyline route
                    if (polylinePoints.isNotEmpty)
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: polylinePoints.first,
                          initialZoom: 13.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.familyguard.app',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: polylinePoints,
                                strokeWidth: 4.0,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: polylinePoints.first,
                                width: 28,
                                height: 28,
                                child: const Icon(Icons.location_on_rounded, color: AppColors.sosRed, size: 28),
                              ),
                              if (polylinePoints.length > 1)
                                Marker(
                                  point: polylinePoints.last,
                                  width: 28,
                                  height: 28,
                                  child: const Icon(Icons.flag_rounded, color: AppColors.teal, size: 28),
                                ),
                            ],
                          ),
                        ],
                      )
                    else
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

                    // Stats Overlay Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              selectedMember.avatar,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${timelineItems.length} Event(s)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 30-Day Auto Retention Badge
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              cronStatus.value != null
                                  ? 'Purged ${DateFormat('MMM d').format(cronStatus.value!)} (<30d)'
                                  : 'Auto-Clean <30d Active',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Timeline List / Empty State
            Expanded(
              child: timelineItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.textMuted),
                            SizedBox(height: 16),
                            Text(
                              'No Location History Yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Location movements and timeline trips will appear here as your Circle travels.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: timelineItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = timelineItems[index];

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(item.icon, size: 24, color: item.color),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('h:mm a').format(item.startTime),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.address,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.durationText,
                                            style: TextStyle(fontSize: 11, color: item.color, fontWeight: FontWeight.w800),
                                          ),
                                          if (item.type == TimelineItemType.trip && item.distanceMiles > 0)
                                            Text(
                                              '~${item.distanceMiles.toStringAsFixed(1)} mi',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                                            ),
                                        ],
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
      ),
    );
  }
}
