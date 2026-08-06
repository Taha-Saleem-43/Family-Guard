import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/sos_alert.dart';
import '../../providers/sos_provider.dart';

class SOSReceiverDialog extends ConsumerStatefulWidget {
  final SOSAlert alert;

  const SOSReceiverDialog({
    super.key,
    required this.alert,
  });

  @override
  ConsumerState<SOSReceiverDialog> createState() => _SOSReceiverDialogState();
}

class _SOSReceiverDialogState extends ConsumerState<SOSReceiverDialog> {
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    // Update live duration ticker on receiver dialog every second
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _dismissAlarm() {
    ref.read(sosProvider.notifier).dismissReceiverAlert(widget.alert.id);
  }

  Future<void> _handleGetDirections() async {
    final alert = widget.alert;
    if (alert.latitude != null && alert.longitude != null) {
      _dismissAlarm();
      final success = await NavigationService.launchTurnByTurnNavigation(
        latitude: alert.latitude!,
        longitude: alert.longitude!,
        label: alert.senderName,
      );
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to launch navigation map app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final liveDuration = alert.formattedTicker;
    final hasCoordinates = alert.latitude != null && alert.longitude != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.sosRed, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emergency Header Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.sosRedLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_rounded, size: 44, color: AppColors.sosRed),
              ),
              const SizedBox(height: 14),
              const Text(
                'EMERGENCY SOS ALERT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sosRed,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${alert.senderName} triggered an emergency!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Live Duration Tag Ticker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sosRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.sosRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Duration • $liveDuration',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.sosRed,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Location Address Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.sosRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.address,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Primary Action: Get Directions (Turn-by-turn Navigation) ──
              if (hasCoordinates) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleGetDirections,
                    icon: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
                    label: Text(
                      'Get Directions to ${alert.senderName.split(' ').first} 🚗',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── Secondary Action: Dismiss Alarm ──────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _dismissAlarm,
                  icon: const Icon(Icons.notifications_off_rounded, size: 18, color: AppColors.textSecondary),
                  label: const Text(
                    'Dismiss Alarm',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
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
