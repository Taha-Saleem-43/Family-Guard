import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/place.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/presentation/screen_header.dart';
import '../../../core/presentation/feedback_panel.dart';
import '../providers/places_provider.dart';
import 'widgets/add_edit_place_dialog.dart';

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(circlePlacesStreamProvider);
    final selectedFilter = ref.watch(selectedPlaceCategoryFilterProvider);
    final isParent =
        ref.watch(appStateProvider.select((state) => state.role)) ==
        UserRole.parent;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ScreenHeader(
        title: 'Places',
        subtitle: isParent
            ? 'Manage familiar places and arrival alerts.'
            : 'Places your family has saved for your circle.',
      ),
      body: placesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => FeedbackPanel(
          icon: Icons.cloud_off_rounded,
          title: 'Places are unavailable',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(circlePlacesStreamProvider),
        ),
        data: (allPlaces) {
          final places = selectedFilter == null
              ? allPlaces
              : allPlaces.where((p) => p.category == selectedFilter).toList();

          return Column(
            children: [
              // Top Category Filters Header
              _buildCategoryFilterHeader(
                context,
                ref,
                allPlaces,
                selectedFilter,
              ),

              // Main List Content / Empty State
              Expanded(
                child: places.isEmpty
                    ? FeedbackPanel(
                        icon: Icons.place_outlined,
                        title: allPlaces.isEmpty
                            ? 'Make familiar places easier to find'
                            : 'No places in this category',
                        message: allPlaces.isNotEmpty
                            ? 'Try another category to see your saved places.'
                            : isParent
                            ? 'Save home, school or another familiar spot to set up arrival and departure alerts.'
                            : 'A parent can add home, school and other places for your circle.',
                        actionLabel: allPlaces.isNotEmpty
                            ? 'Show all places'
                            : isParent
                            ? 'Add your first place'
                            : null,
                        onAction: allPlaces.isNotEmpty
                            ? () =>
                                  ref
                                          .read(
                                            selectedPlaceCategoryFilterProvider
                                                .notifier,
                                          )
                                          .state =
                                      null
                            : isParent
                            ? () => AddEditPlaceDialog.show(context)
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: places.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
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
      floatingActionButton: !isParent
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => AddEditPlaceDialog.show(context),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text(
                'Add Place',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
              icon: Icons.grid_view_rounded,
              isSelected: selectedFilter == null,
              onTap: () =>
                  ref.read(selectedPlaceCategoryFilterProvider.notifier).state =
                      null,
            ),
            const SizedBox(width: 8),
            ...PlaceCategory.values.map((cat) {
              final count = countFor(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: '${cat.displayName} ($count)',
                  icon: cat.icon,
                  isSelected: selectedFilter == cat,
                  onTap: () =>
                      ref
                              .read(
                                selectedPlaceCategoryFilterProvider.notifier,
                              )
                              .state =
                          cat,
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
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
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

  Widget _buildPlaceCard(BuildContext context, WidgetRef ref, Place place) {
    final isParent =
        ref.watch(appStateProvider.select((state) => state.role)) ==
        UserRole.parent;
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
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${place.category.displayName} · ${place.radius.toInt()} m boundary',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (isParent)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
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
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Edit Place',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.sosRed,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.sosRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const Divider(height: 20),

          // Notification Toggles Row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Arrival Alert Toggle Chip
              InkWell(
                onTap: !isParent
                    ? null
                    : () => _updatePlace(
                        context,
                        () => controller.toggleArrivalNotification(place),
                      ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: place.notifyArrive
                        ? AppColors.teal.withValues(alpha: 0.1)
                        : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: place.notifyArrive
                          ? AppColors.teal
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        place.notifyArrive
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 16,
                        color: place.notifyArrive
                            ? AppColors.teal
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Arrival alerts',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: place.notifyArrive
                                ? AppColors.teal
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Departure Alert Toggle Chip
              InkWell(
                onTap: !isParent
                    ? null
                    : () => _updatePlace(
                        context,
                        () => controller.toggleDepartureNotification(place),
                      ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: place.notifyLeave
                        ? AppColors.teal.withValues(alpha: 0.1)
                        : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: place.notifyLeave
                          ? AppColors.teal
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        place.notifyLeave
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 16,
                        color: place.notifyLeave
                            ? AppColors.teal
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Departure alerts',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: place.notifyLeave
                                ? AppColors.teal
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!isParent)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Notification settings are managed by a parent.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    PlacesController controller,
    Place place,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Saved Place?'),
        content: Text(
          'Are you sure you want to remove "${place.name}" from your circle\'s saved places?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final removed = await _updatePlace(
                context,
                () => controller.deletePlace(place.id),
              );
              if (!removed) return;
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

  Future<bool> _updatePlace(
    BuildContext context,
    Future<void> Function() update,
  ) async {
    try {
      await update();
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update this place. Check your connection and try again.',
            ),
          ),
        );
      }
      return false;
    }
  }
}
