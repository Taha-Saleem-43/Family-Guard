import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/member.dart';
import '../../../core/models/movement_activity.dart';
import '../../../core/models/place.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/member_status_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../places/providers/places_provider.dart';

import 'widgets/member_detail_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  String? _selectedMemberId = 'm_self';

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _getInitialCenter(List<Member> members) {
    for (final member in members) {
      if (member.latitude != null && member.longitude != null) {
        return LatLng(member.latitude!, member.longitude!);
      }
    }
    return const LatLng(33.6844, 73.0479); // Pakistan default coordinates
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final isParent = appState.role == UserRole.parent;
    final allMembers = ref.watch(memberStateProvider);
    final selectedFilter = ref.watch(selectedActivityFilterProvider);

    // Watch Saved Places for the circle
    final placesAsync = ref.watch(circlePlacesStreamProvider);
    final savedPlaces = placesAsync.value ?? <Place>[];

    final selfId = appState.userId.isNotEmpty ? appState.userId : 'm_self';
    final self = allMembers.where((member) => member.id == selfId).firstOrNull;
    final ownLocationAvailable =
        self?.latitude != null && self?.longitude != null;

    // Parent sees all circle members on the map canvas. Child sees only their own pin.
    final visibleMembers = isParent
        ? allMembers
        : allMembers.where((m) => m.id == selfId).toList();

    // Apply activity filter if selected
    final members = selectedFilter == null
        ? visibleMembers
        : visibleMembers
              .where((m) => m.movementActivity == selectedFilter)
              .toList();
    final located = visibleMembers
        .where((member) => member.latitude != null && member.longitude != null)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          // OpenStreetMap canvas; hosting capacity follows the tile provider policy.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _getInitialCenter(members),
              initialZoom: 14.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              // Zero-API-Key TileLayer from OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.familyguard.app',
              ),

              // Reported horizontal uncertainty, not a guaranteed boundary.
              CircleLayer(
                circles: [
                  for (final member in members)
                    if (member.latitude != null &&
                        member.longitude != null &&
                        member.accuracyMeters != null &&
                        member.accuracyMeters!.isFinite &&
                        member.accuracyMeters! > 0 &&
                        member.accuracyMeters! <= 100)
                      CircleMarker(
                        point: LatLng(member.latitude!, member.longitude!),
                        radius: member.accuracyMeters!,
                        useRadiusInMeter: true,
                        color: member.pinColor.withValues(
                          alpha: member.isStale ? 0.04 : 0.12,
                        ),
                        borderColor: member.pinColor.withValues(alpha: 0.4),
                        borderStrokeWidth: 1,
                      ),
                ],
              ),

              // Saved Places Geofence Radius Circles Layer
              if (savedPlaces.isNotEmpty)
                CircleLayer(
                  circles: [
                    for (final place in savedPlaces)
                      CircleMarker(
                        point: LatLng(place.latitude, place.longitude),
                        radius: place.radius,
                        useRadiusInMeter: true,
                        color: place.color.withValues(alpha: 0.16),
                        borderColor: place.color,
                        borderStrokeWidth: 2.0,
                      ),
                  ],
                ),

              // Saved Places Pin Markers Layer
              if (savedPlaces.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final place in savedPlaces)
                      Marker(
                        point: LatLng(place.latitude, place.longitude),
                        width: 90,
                        height: 55,
                        child: _buildPlaceMapMarker(place),
                      ),
                  ],
                ),

              // Live Custom Pins for Circle Members
              MarkerLayer(
                markers: [
                  for (final member in members)
                    if (member.latitude != null && member.longitude != null)
                      Marker(
                        point: LatLng(member.latitude!, member.longitude!),
                        width: 140,
                        height: 85,
                        child: _buildMapPin(
                          member,
                          isSelected: _selectedMemberId == member.id,
                        ),
                      ),
                ],
              ),
            ],
          ),

          // ── Top Bar: Activity Filter Chips ────────────────────────────
          if (isParent)
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(top: isParent ? 8 : 12),
                  child: _buildActivityFilterHeader(
                    visibleMembers,
                    selectedFilter,
                  ),
                ),
              ),
            ),

          // ── Child Top Notification Banner ─────────────────────────────
          if (!isParent)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !ownLocationAvailable
                            ? 'Your location is not available yet. Check sharing in Settings.'
                            : self!.isStale
                            ? 'Your last location may be outdated. Check sharing in Settings.'
                            : 'Latest location captured for ${appState.circleName}.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sharing settings',
                      onPressed: () => ref
                          .read(appStateProvider.notifier)
                          .setActiveTab(AppTab.settings),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            left: 12,
            right: 12,
            bottom: isParent
                ? (constraints.maxHeight * 0.42).clamp(140.0, 260.0) + 8
                : 12,
            child: Row(
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: IconButton(
                    tooltip: located.isEmpty
                        ? 'No location available to center'
                        : 'Center on a member',
                    onPressed: located.isEmpty
                        ? null
                        : () {
                            final target =
                                located
                                    .where(
                                      (member) =>
                                          member.id == _selectedMemberId,
                                    )
                                    .firstOrNull ??
                                located.first;
                            _mapController.move(
                              LatLng(target.latitude!, target.longitude!),
                              15,
                            );
                          },
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: TextButton(
                    onPressed: () async {
                      await launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Member Cards Sheet (Parent View) ──────────────────
          if (isParent)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: (constraints.maxHeight * 0.42).clamp(140.0, 260.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            appState.circleName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${members.length} members',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: members.isEmpty
                          ? const Center(
                              child: Text(
                                'No members with selected activity',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: members.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final isSelected =
                                    _selectedMemberId == member.id;

                                return _buildMemberSheetCard(
                                  member,
                                  isSelected,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Activity Filter Header ────────────────────────────────────────
  Widget _buildActivityFilterHeader(
    List<Member> allMembers,
    MovementActivity? selectedFilter,
  ) {
    int countFor(MovementActivity? filter) {
      if (filter == null) return allMembers.length;
      return allMembers.where((m) => m.movementActivity == filter).length;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'All (${countFor(null)})',
              emoji: '👥',
              isSelected: selectedFilter == null,
              color: AppColors.primary,
              onTap: () =>
                  ref.read(selectedActivityFilterProvider.notifier).state =
                      null,
            ),
            const SizedBox(width: 6),
            _buildFilterChip(
              label: 'Stationary (${countFor(MovementActivity.stationary)})',
              emoji: MovementActivity.stationary.emoji,
              isSelected: selectedFilter == MovementActivity.stationary,
              color: MovementActivity.stationary.color,
              onTap: () =>
                  ref.read(selectedActivityFilterProvider.notifier).state =
                      MovementActivity.stationary,
            ),
            const SizedBox(width: 6),
            _buildFilterChip(
              label: 'Walking (${countFor(MovementActivity.walking)})',
              emoji: MovementActivity.walking.emoji,
              isSelected: selectedFilter == MovementActivity.walking,
              color: MovementActivity.walking.color,
              onTap: () =>
                  ref.read(selectedActivityFilterProvider.notifier).state =
                      MovementActivity.walking,
            ),
            const SizedBox(width: 6),
            _buildFilterChip(
              label: 'Driving (${countFor(MovementActivity.driving)})',
              emoji: MovementActivity.driving.emoji,
              isSelected: selectedFilter == MovementActivity.driving,
              color: MovementActivity.driving.color,
              onTap: () =>
                  ref.read(selectedActivityFilterProvider.notifier).state =
                      MovementActivity.driving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Map Pin Marker Widget ─────────────────────────────────────────
  Widget _buildMapPin(Member member, {required bool isSelected}) {
    final activity = member.movementActivity;
    final batColor = BatteryHelper.getColor(member.batteryLevel);
    final batIcon = BatteryHelper.getIcon(
      member.batteryLevel,
      isCharging: member.isCharging,
    );
    final isSos = member.isSosActive;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMemberId = member.id);
        if (member.latitude != null && member.longitude != null) {
          _mapController.move(
            LatLng(member.latitude!, member.longitude!),
            15.5,
          );
        }
        MemberDetailSheet.show(context, member);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with Floating Movement Badge or SOS Pulse Ring
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: member.pinColor,
                    width: isSos ? 4 : 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: member.pinColor.withValues(
                        alpha: isSos ? 0.6 : 0.35,
                      ),
                      blurRadius: isSos ? 20 : (isSelected ? 14 : 6),
                      spreadRadius: isSos ? 6 : (isSelected ? 3 : 1),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: isSelected ? 20 : 16,
                  backgroundColor: member.pinColor.withValues(alpha: 0.15),
                  child: Text(
                    member.avatar,
                    style: TextStyle(fontSize: isSelected ? 20 : 16),
                  ),
                ),
              ),

              // Floating SOS Badge or Movement Indicator Badge
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSos ? AppColors.sosRed : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSos ? Colors.white : activity.color,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSos ? AppColors.sosRed : activity.color)
                            .withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: isSos
                      ? const Icon(
                          Icons.emergency_rounded,
                          size: 10,
                          color: Colors.white,
                        )
                      : Text(
                          activity.emoji,
                          style: const TextStyle(fontSize: 10),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Member Name + Battery Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isSos ? AppColors.sosRed : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSos
                    ? Colors.white
                    : (isSelected ? member.pinColor : Colors.grey.shade200),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    isSos ? '🚨 ${member.name}' : member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isSos ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                // Live Battery Level % Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSos
                        ? Colors.white.withValues(alpha: 0.2)
                        : batColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        batIcon,
                        size: 10,
                        color: isSos ? Colors.white : batColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        BatteryHelper.label(member.batteryLevel),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: isSos ? Colors.white : batColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Member Card in Bottom Sheet ───────────────────────────────────
  Widget _buildMemberSheetCard(Member member, bool isSelected) {
    final hasLocation = member.latitude != null && member.longitude != null;
    final status = member.isSosActive
        ? 'SOS active'
        : !hasLocation
        ? 'Location not available yet'
        : member.isStale
        ? 'Last location may be outdated'
        : member.movementActivity.label;
    return Material(
      color: member.isSosActive
          ? AppColors.sosRedLight
          : isSelected
          ? AppColors.primaryLight
          : AppColors.bg,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Text(member.avatar, style: const TextStyle(fontSize: 28)),
        title: Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          status,
          style: TextStyle(
            color: member.isSosActive
                ? AppColors.sosRed
                : AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          setState(() => _selectedMemberId = member.id);
          if (hasLocation) {
            _mapController.move(
              LatLng(member.latitude!, member.longitude!),
              15.5,
            );
          }
          MemberDetailSheet.show(context, member);
        },
      ),
    );
  }

  Widget _buildPlaceMapMarker(Place place) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: place.color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: place.color.withValues(alpha: 0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(place.iconData, size: 16, color: place.color),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: place.color.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
