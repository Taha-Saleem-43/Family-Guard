import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/place.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/places_provider.dart';

class AddEditPlaceDialog extends ConsumerStatefulWidget {
  final Place? existingPlace;
  final LatLng? initialLocation;

  const AddEditPlaceDialog({
    super.key,
    this.existingPlace,
    this.initialLocation,
  });

  static Future<void> show(
    BuildContext context, {
    Place? existingPlace,
    LatLng? initialLocation,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditPlaceDialog(
        existingPlace: existingPlace,
        initialLocation: initialLocation,
      ),
    );
  }

  @override
  ConsumerState<AddEditPlaceDialog> createState() => _AddEditPlaceDialogState();
}

class _AddEditPlaceDialogState extends ConsumerState<AddEditPlaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final MapController _mapController = MapController();

  late PlaceCategory _selectedCategory;
  late double _radius;
  late LatLng _selectedLocation;
  late Color _selectedColor;
  late bool _notifyArrive;
  late bool _notifyLeave;
  bool _isSaving = false;

  static const List<Color> _colorOptions = [
    AppColors.teal,
    AppColors.primary,
    Color(0xFF8E44AD), // Purple
    Color(0xFFE67E22), // Orange
    Color(0xFFE74C3C), // Red
    Color(0xFF2ECC71), // Green
  ];

  @override
  void initState() {
    super.initState();
    final place = widget.existingPlace;
    if (place != null) {
      _nameController.text = place.name;
      _addressController.text = place.address;
      _selectedCategory = place.category;
      _radius = place.radius;
      _selectedLocation = LatLng(place.latitude, place.longitude);
      _selectedColor = place.color;
      _notifyArrive = place.notifyArrive;
      _notifyLeave = place.notifyLeave;
    } else {
      _nameController.text = '';
      _addressController.text = '';
      _selectedCategory = PlaceCategory.home;
      _radius = 200.0;
      _selectedLocation = widget.initialLocation ?? const LatLng(33.6844, 73.0479);
      _selectedColor = AppColors.teal;
      _notifyArrive = true;
      _notifyLeave = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}';

      final placeToSave = Place(
        id: widget.existingPlace?.id ?? '',
        circleId: widget.existingPlace?.circleId ?? '',
        name: name,
        address: address,
        category: _selectedCategory,
        radius: _radius,
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        color: _selectedColor,
        notifyArrive: _notifyArrive,
        notifyLeave: _notifyLeave,
        createdBy: widget.existingPlace?.createdBy ?? '',
      );

      final controller = ref.read(placesControllerProvider);
      if (widget.existingPlace != null) {
        await controller.updatePlace(placeToSave);
      } else {
        await controller.addPlace(placeToSave);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingPlace != null ? 'Place updated successfully' : 'Saved Place registered!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving place: $e'),
            backgroundColor: AppColors.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPlace != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottomsheet drag handle bar
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
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Saved Place' : 'Add Saved Place',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Place Name',
                  hintText: 'e.g. Home, School, Grandma\'s House',
                  prefixIcon: Icon(_selectedCategory.icon, color: _selectedColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a place name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Category Selector Chips
              const Text(
                'Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PlaceCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(cat.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: _selectedColor.withValues(alpha: 0.15),
                        side: BorderSide(
                          color: isSelected ? _selectedColor : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                              if (_nameController.text.isEmpty && cat != PlaceCategory.custom) {
                                _nameController.text = cat.displayName;
                              }
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Theme Color Picker
              const Text(
                'Pin & Geofence Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: _colorOptions.map((c) {
                  final isSelected = _selectedColor.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Interactive OpenStreetMap Picker with Geofence Radius Overlay
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Set Location on Map',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                  Text(
                    'Tap map to set pin',
                    style: TextStyle(fontSize: 11, color: _selectedColor, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 190,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 15.0,
                      onTap: (tapPos, latLng) {
                        setState(() => _selectedLocation = latLng);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.familyguard.app',
                      ),
                      // Geofence Radius Circle Preview
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedLocation,
                            radius: _radius,
                            useRadiusInMeter: true,
                            color: _selectedColor.withValues(alpha: 0.22),
                            borderColor: _selectedColor,
                            borderStrokeWidth: 2.0,
                          ),
                        ],
                      ),
                      // Selected Location Pin Marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 50,
                            height: 50,
                            child: Column(
                              children: [
                                Icon(_selectedCategory.icon, color: _selectedColor, size: 30),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Address Field (Optional text)
              TextFormField(
                controller: _addressController,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Address Description',
                  hintText: 'e.g. 123 Main Street, Sector F-7',
                  prefixIcon: const Icon(Icons.map_outlined, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),

              // Geofence Radius Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Geofence Alert Radius',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_radius.toInt()} meters',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _selectedColor),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radius,
                min: 100,
                max: 1000,
                divisions: 18,
                activeColor: _selectedColor,
                inactiveColor: AppColors.border,
                label: '${_radius.toInt()}m',
                onChanged: (val) => setState(() => _radius = val),
              ),
              const SizedBox(height: 8),

              // Notification Toggles Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Arrival Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      subtitle: const Text('Notify Circle when members enter this place', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      value: _notifyArrive,
                      activeThumbColor: _selectedColor,
                      onChanged: (val) => setState(() => _notifyArrive = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Departure Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      subtitle: const Text('Notify Circle when members leave this place', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      value: _notifyLeave,
                      activeThumbColor: _selectedColor,
                      onChanged: (val) => setState(() => _notifyLeave = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(isEdit ? Icons.check_circle_rounded : Icons.add_location_alt_rounded),
                  label: Text(
                    _isSaving ? 'Saving Place...' : (isEdit ? 'Save Changes' : 'Save Place & Register Geofence'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
