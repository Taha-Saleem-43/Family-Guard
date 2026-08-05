import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../../../../core/theme/app_colors.dart';

class SOSOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onActivated;

  const SOSOverlay({
    super.key,
    required this.onCancel,
    required this.onActivated,
  });

  @override
  State<SOSOverlay> createState() => _SOSOverlayState();
}

class _SOSOverlayState extends State<SOSOverlay> {
  int _countdown = 3;
  Timer? _timer;
  Timer? _vibrationTimer;
  bool _isActive = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
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
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
        _triggerEmergencyAlert();
      }
    });
  }

  Future<void> _triggerEmergencyAlert() async {
    setState(() => _isActive = true);
    widget.onActivated();

    // 1. Play Emergency Siren Sound in loop
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/siren.wav'));
    } catch (e) {
      debugPrint('Error playing siren sound: $e');
    }

    // 2. Trigger Continuous Alarm Vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 600, 200, 600], repeat: 0);
      } else {
        _vibrationTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
          HapticFeedback.vibrate();
        });
      }
    } catch (e) {
      debugPrint('Error starting vibration: $e');
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        HapticFeedback.vibrate();
      });
    }
  }

  void _stopEmergencyAlert() {
    _timer?.cancel();
    _vibrationTimer?.cancel();
    try {
      Vibration.cancel();
    } catch (_) {}
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  void _handleCancel() {
    _stopEmergencyAlert();
    widget.onCancel();
  }

  @override
  void dispose() {
    _stopEmergencyAlert();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            if (!_isActive) ...[
              const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Sending SOS Alert',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Notifying all family members with your live location...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
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
                  '$_countdown',
                  style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _handleCancel,
                  child: const Text('CANCEL SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ] else ...[
              const Icon(Icons.emergency_rounded, size: 90, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'SOS ALERT ACTIVE',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              Text(
                'Emergency broadcast sent to all Circle members.\nLive high-accuracy location tracking active.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, height: 1.4),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _handleCancel,
                  child: const Text('Resolve / Dismiss Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
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

