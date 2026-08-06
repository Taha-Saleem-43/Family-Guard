import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/place.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/places_provider.dart';
import 'widgets/add_edit_place_dialog.dart';

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(circlePlacesStreamProvider);
    final selectedFilter = ref.watch(selectedPlaceCategoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Saved Places'),
      ),
      body: placesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => _buildErrorState(err.toString()),
        data: (allPlaces) {
          final places = selectedFilter == null
              ? allPlaces
              : allPlaces.where((p) => p.category == selectedFilter).toList();

          return Column(
            children: [
              // Top Category Filters Header
              _buildCategoryFilterHeader(context, ref, allPlaces, selectedFilter),

              // Main List Content / Empty State
              Expanded(
                child: places.isEmpty
                    ? _buildEmptyState(hasPlacesInCircle: allPlaces.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: places.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final place = places[index];
                          return _buildPlaceCard(context, ref, place);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => AddEditPlaceDialog.show(context),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Place', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildCategoryFilterHeader(
    BuildContext context,
    WidgetRef ref,
    List<Place> allPlaces,
    PlaceCategory? selectedFilter,
  ) {
    int countFor(PlaceCategory? cat) {
      if (cat == null) return allPlaces.length;
      return allPlaces.where((p) => p.category == cat).length;
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'All (${countFor(null)})',
              emoji: '🗺️',
              isSelected: selectedFilter == null,
              onTap: () => ref.read(selectedPlaceCategoryFilterProvider.notifier).state = null,
            ),
            const SizedBox(width: 8),
            ...PlaceCategory.values.map((cat) {
              final count = countFor(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: '${cat.displayName} ($count)',
                  emoji: cat.emoji,
                  isSelected: selectedFilter == cat,
                  onTap: () => ref.read(selectedPlaceCategoryFilterProvider.notifier).state = cat,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.bg,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildEmptyState({required bool hasPlacesInCircle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.place_outlined, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              hasPlacesInCircle ? 'No Places in Category' : 'No Saved Places Yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              hasPlacesInCircle
                  ? 'No places match the selected category filter.'
                  : 'Add places like Home, School, or Work to receive arrival and departure alerts for your Circle.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.sosRed),
            const SizedBox(height: 12),
            const Text(
              'Failed to load saved places',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, WidgetRef ref, Place place) {
    final color = place.color;
    final icon = place.iconData;
    final controller = ref.read(placesControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            place.category.displayName,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Radius Badge & Context Menu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${place.radius.toInt()}m',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                onSelected: (action) {
                  if (action == 'edit') {
                    AddEditPlaceDialog.show(context, existingPlace: place);
                  } else if (action == 'delete') {
                    _confirmDelete(context, controller, place);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                        SizedBox(width: 8),
                        Text('Edit Place', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.sosRed),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.sosRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 20),

          // Notification Toggles Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Arrival Alert Toggle Chip
              InkWell(
                onTap: () => controller.toggleArrivalNotification(place),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: place.notifyArrive ? AppColors.teal.withValues(alpha: 0.1) : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: place.notifyArrive ? AppColors.teal : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        place.notifyArrive ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 16,
                        color: place.notifyArrive ? AppColors.teal : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Arrival alerts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: place.notifyArrive ? AppColors.teal : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Departure Alert Toggle Chip
              InkWell(
                onTap: () => controller.toggleDepartureNotification(place),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: place.notifyLeave ? AppColors.teal.withValues(alpha: 0.1) : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: place.notifyLeave ? AppColors.teal : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        place.notifyLeave ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 16,
                        color: place.notifyLeave ? AppColors.teal : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Departure alerts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: place.notifyLeave ? AppColors.teal : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlacesController controller, Place place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Place?'),
        content: Text('Are you sure you want to remove "${place.name}" from your circle\'s saved places?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await controller.deletePlace(place.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Place deleted'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
