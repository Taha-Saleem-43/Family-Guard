import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/member.dart';
import '../../../core/models/movement_activity.dart';
import '../../../core/models/place.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/member_status_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../places/providers/places_provider.dart';
import '../../sos/presentation/widgets/emergency_host.dart';
import 'widgets/member_detail_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  String? _selectedMemberId = 'm_self';

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

    // Parent sees all circle members on the map canvas. Child sees only their own pin.
    final visibleMembers = isParent
        ? allMembers
        : allMembers.where((m) => m.id == selfId).toList();

    // Apply activity filter if selected
    final members = selectedFilter == null
        ? visibleMembers
        : visibleMembers.where((m) => m.movementActivity == selectedFilter).toList();


    return Stack(
      children: [
        // ── 100% Free OpenStreetMap Interactive Canvas ──────────────────
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
        Positioned(
          top: 0,
          left: 12,
          right: 12,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: isParent ? 8 : 12),
              child: _buildActivityFilterHeader(visibleMembers, selectedFilter),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sharing location as ${appState.userName} with Circle',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Floating SOS Button ───────────────────────────────────────
        Positioned(
          right: 16,
          bottom: isParent ? 275 : 120,
          child: GestureDetector(
            onTap: () => ref.read(sosComposerProvider.notifier).state = true,
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
              child: const Icon(Icons.sos_rounded, size: 30, color: Colors.white),
            ),
          ),
        ),

        // ── Bottom Member Cards Sheet (Parent View) ──────────────────
        if (isParent)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 260,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Text(
                        appState.circleName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Live Circle Members',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: members.isEmpty
                        ? const Center(
                            child: Text(
                              'No members with selected activity',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: members.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final isSelected = _selectedMemberId == member.id;

                              return _buildMemberSheetCard(member, isSelected);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

      ],
    );
  }

  // ── Activity Filter Header ────────────────────────────────────────
  Widget _buildActivityFilterHeader(List<Member> allMembers, MovementActivity? selectedFilter) {
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
              onTap: () => ref.read(selectedActivityFilterProvider.notifier).state = null,
            ),
            const SizedBox(width: 6),
            _buildFilterChip(
              label: 'Stationary (${countFor(MovementActivity.stationary)})',
              emoji: MovementActivity.stationary.emoji,
              isSelected: selectedFilter == MovementActivity.stationary,
              color: MovementActivity.stationary.color,
              onTap: () => ref.read(selectedActivityFilterProvider.notifier).state = MovementActivity.stationary,
            ),
            const SizedBox(width: 6),
            _buildFilterChip(
              label: 'Walking (${countFor(MovementActivity.walking)})',
              emoji: MovementActivity.walking.emoji,
              isSelected: selectedFilter == MovementActivity.walking,
              color: MovementActivity.walking.color,
              onTap: () => ref.read(selectedActivityFilterProvider.notifier).state = MovementActivity.walking,
            ),
            const SizedBox(width: 6),
            _buildFilterChip(
              label: 'Driving (${countFor(MovementActivity.driving)})',
              emoji: MovementActivity.driving.emoji,
              isSelected: selectedFilter == MovementActivity.driving,
              color: MovementActivity.driving.color,
              onTap: () => ref.read(selectedActivityFilterProvider.notifier).state = MovementActivity.driving,
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
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
          ),
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
    final batIcon = BatteryHelper.getIcon(member.batteryLevel, isCharging: member.isCharging);
    final isSos = member.isSosActive;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMemberId = member.id);
        if (member.latitude != null && member.longitude != null) {
          _mapController.move(LatLng(member.latitude!, member.longitude!), 15.5);
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
                  border: Border.all(color: member.pinColor, width: isSos ? 4 : 3),
                  boxShadow: [
                    BoxShadow(
                      color: member.pinColor.withValues(alpha: isSos ? 0.6 : 0.35),
                      blurRadius: isSos ? 20 : (isSelected ? 14 : 6),
                      spreadRadius: isSos ? 6 : (isSelected ? 3 : 1),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: isSelected ? 20 : 16,
                  backgroundColor: member.pinColor.withValues(alpha: 0.15),
                  child: Text(member.avatar, style: TextStyle(fontSize: isSelected ? 20 : 16)),
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
                    border: Border.all(color: isSos ? Colors.white : activity.color, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: (isSos ? AppColors.sosRed : activity.color).withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: isSos
                      ? const Icon(Icons.emergency_rounded, size: 10, color: Colors.white)
                      : Text(activity.emoji, style: const TextStyle(fontSize: 10)),
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
              border: Border.all(color: isSos ? Colors.white : (isSelected ? member.pinColor : Colors.grey.shade200), width: isSelected ? 1.5 : 1.0),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSos ? Colors.white.withValues(alpha: 0.2) : batColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(batIcon, size: 10, color: isSos ? Colors.white : batColor),
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
    final activity = member.movementActivity;
    final batColor = BatteryHelper.getColor(member.batteryLevel);
    final batIcon = BatteryHelper.getIcon(member.batteryLevel, isCharging: member.isCharging);
    final isSos = member.isSosActive;

    String speedText = '';
    if (activity == MovementActivity.walking) {
      speedText = ' • ${member.speedMph.toStringAsFixed(1)} mph';
    } else if (activity == MovementActivity.driving) {
      speedText = ' • ${member.speedMph.toStringAsFixed(0)} mph';
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMemberId = member.id);
        if (member.latitude != null && member.longitude != null) {
          _mapController.move(LatLng(member.latitude!, member.longitude!), 15.5);
        }
        MemberDetailSheet.show(context, member);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 175,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSos ? AppColors.sosRedLight : (isSelected ? AppColors.primaryLight : AppColors.bg),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSos ? AppColors.sosRed : (isSelected ? AppColors.primary : AppColors.border),
            width: isSos || isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar & Live Battery Badge
            Row(
              children: [
                Text(member.avatar, style: const TextStyle(fontSize: 24)),
                const Spacer(),

                // Live Battery Level Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: batColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: batColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(batIcon, size: 13, color: batColor),
                      const SizedBox(width: 3),
                      Text(
                        BatteryHelper.label(member.batteryLevel),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: batColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Member Name
            Text(
              isSos ? '🚨 ${member.name}' : member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isSos ? AppColors.sosRed : AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            // Movement Activity Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSos ? AppColors.sosRed.withValues(alpha: 0.15) : activity.bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSos ? AppColors.sosRed : activity.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isSos ? '🚨' : activity.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isSos ? 'SOS EMERGENCY' : '${activity.label}$speedText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSos ? AppColors.sosRed : activity.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Location Address
            Text(
              member.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
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

