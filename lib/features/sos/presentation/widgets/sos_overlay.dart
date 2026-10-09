import 'dart:async';
import 'package:flutter/material.dart';
import 'push_delivery_status.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/sos_provider.dart';

class SOSOverlay extends ConsumerStatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback? onActivated;

  const SOSOverlay({super.key, required this.onCancel, this.onActivated});

  @override
  ConsumerState<SOSOverlay> createState() => _SOSOverlayState();
}

class _SOSOverlayState extends ConsumerState<SOSOverlay> {
  int _countdown = 3;
  Timer? _timer;
  bool _isActive = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isActive = ref.read(sosProvider).isSelfSosActive;
    if (_isActive) return;
    _playCountdownTick();
    _startCountdown();
  }

  void _playCountdownTick() {
    HapticFeedback.heavyImpact();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        _playCountdownTick();
        if (mounted) setState(() => _countdown--);
      } else {
        _timer?.cancel();
        _triggerEmergencyAlert();
      }
    });
  }

  Future<void> _triggerEmergencyAlert() async {
    if (!mounted) return;
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    // Trigger backend SOS via Riverpod (Silent Mode on sender device: no audio siren or vibration)
    final sent = await ref.read(sosProvider.notifier).triggerEmergency();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _isActive = sent;
      _error = sent
          ? null
          : 'Could not confirm the alert. Check your connection and retry.';
    });
    if (sent) widget.onActivated?.call();
  }

  Future<void> _handleResolve() async {
    _timer?.cancel();
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final resolved = await ref.read(sosProvider.notifier).resolveEmergency();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = resolved
          ? null
          : 'Could not resolve the alert. It remains active. Retry when connected.';
    });
    if (resolved) widget.onCancel();
  }

  void _handleCancelCountdown() {
    _timer?.cancel();
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);
    final durationFormatted = sosState.formattedActiveDuration;

    return Container(
      color: AppColors.sosRed,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              if (!_isActive)
                TextButton(
                  onPressed: _busy ? null : _triggerEmergencyAlert,
                  child: const Text(
                    'RETRY SOS',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (!_isActive) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sending SOS Alert',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Broadcasting emergency alert & live location to family circle...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _busy ? '…' : '$_countdown',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.sosRed,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _busy ? null : _handleCancelCountdown,
                  child: const Text(
                    'CANCEL SOS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.emergency_rounded,
                size: 90,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'SOS ALERT ACTIVE',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              // Live SOS duration ticker display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Active Duration • $durationFormatted',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your emergency alert is saved for your circle.\nDelivery to each device has not been confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (sosState.activeAlertId != null) ...[
                const SizedBox(height: 12),
                PushDeliveryStatus(alertId: sosState.activeAlertId!),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _busy ? null : _handleResolve,
                  child: const Text(
                    'Resolve / Dismiss Alert',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
