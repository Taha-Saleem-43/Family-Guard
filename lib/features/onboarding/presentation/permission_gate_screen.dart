import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/permission_summary.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';

// ── Internal sub-step enum ───────────────────────────────────────────────────

enum _PermStep { foreground, background, notifications, battery, oem, allSet }

// ── Screen ───────────────────────────────────────────────────────────────────

/// Full permission gate shown at the end of onboarding (after circle setup).
///
/// Walks the user through 4–5 pre-prompt cards in strict sequence and ends
/// on an "All set" confirmation that calls [AppStateNotifier.completeOnboarding].
class PermissionGateScreen extends ConsumerStatefulWidget {
  /// The role already determined by the onboarding flow.
  final UserRole role;
  final PermissionService? service;

  const PermissionGateScreen({super.key, required this.role, this.service});

  @override
  ConsumerState<PermissionGateScreen> createState() =>
      _PermissionGateScreenState();
}

class _PermissionGateScreenState extends ConsumerState<PermissionGateScreen> {
  late final PermissionService _service;
  late final String _initialUid;
  bool get _sharesLocation => widget.role == UserRole.child;

  _PermStep _step = _PermStep.foreground;
  bool _isLoading = false;

  // Accumulates the result of each permission request.
  bool _fgGranted = false;
  bool _bgGranted = false;
  bool _notifGranted = false;
  bool _batteryGranted = false;
  bool _requiresOem = false;

  // Set to true when foreground location is permanently denied.
  bool _fgPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PermissionService();
    _initialUid = ref.read(appStateProvider).userId;
    if (_sharesLocation) {
      _checkOem();
    } else {
      _step = _PermStep.notifications;
    }
  }

  Future<void> _checkOem() async {
    try {
      final isOem = await _service.requiresOemAutoStartStep;
      if (mounted) setState(() => _requiresOem = isOem);
    } catch (_) {
      /* Optional OEM advice must not block onboarding. */
    }
  }

  // ── Step handlers ──────────────────────────────────────────────────────────

  Future<void> _request(
    Future<PermissionStatus> Function() action,
    void Function(PermissionStatus) apply,
  ) async {
    if (_isLoading || ref.read(appStateProvider).userId != _initialUid) return;
    setState(() => _isLoading = true);
    try {
      final status = await action();
      if (!mounted || ref.read(appStateProvider).userId != _initialUid) return;
      setState(() => apply(status));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not request permission. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestForeground() =>
      _request(_service.requestForegroundLocation, (status) {
        _fgGranted = status.isGranted;
        _fgPermanentlyDenied = status.isPermanentlyDenied;
        if (_fgGranted) _step = _PermStep.background;
      });

  Future<void> _requestBackground() => _request(
    () => _service.requestBackgroundLocation(foregroundGranted: _fgGranted),
    (status) {
      _bgGranted = status.isGranted;
      _step = _PermStep.notifications;
    },
  );

  Future<void> _requestNotifications() =>
      _request(_service.requestNotifications, (status) {
        _notifGranted = status.isGranted;
        _step = _sharesLocation ? _PermStep.battery : _PermStep.allSet;
      });

  Future<void> _requestBattery() =>
      _request(_service.requestBatteryOptimization, (status) {
        _batteryGranted = status.isGranted;
        _step = _requiresOem ? _PermStep.oem : _PermStep.allSet;
      });

  void _skipOem() => setState(() => _step = _PermStep.allSet);

  void _finishOnboarding() {
    if (ref.read(appStateProvider).userId != _initialUid) return;
    ref.read(appStateProvider.notifier).completeOnboarding(widget.role);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _PermStep.foreground:
        return _buildForegroundStep();
      case _PermStep.background:
        return _buildBackgroundStep();
      case _PermStep.notifications:
        return _buildNotificationsStep();
      case _PermStep.battery:
        return _buildBatteryStep();
      case _PermStep.oem:
        return _buildOemStep();
      case _PermStep.allSet:
        return _buildAllSet();
    }
  }

  // ── Step 1: Foreground Location ────────────────────────────────────────────

  Widget _buildForegroundStep() {
    return _PrePromptCard(
      key: const ValueKey('perm_fg'),
      stepNumber: '1 of 4',
      icon: Icons.my_location_rounded,
      iconColor: AppColors.primary,
      title: 'Allow location access',
      body:
          'FamilyGuard needs to know where you are so family members can find '
          'each other on the map. Select "While using the app" on the next screen.',
      primaryLabel: 'Continue',
      isLoading: _isLoading,
      onPrimary: _requestForeground,
      // Blocking state: shown after a denial
      blocker: _fgPermanentlyDenied
          ? _BlockerBanner(
              message:
                  'Location permission was permanently denied. Please open '
                  'Settings and allow it manually.',
              onOpenSettings: () async {
                await _service.openSystemAppSettings();
                // Re-check after returning from Settings
                final status = await _service.foregroundLocationStatus();
                if (status.isGranted && mounted) {
                  setState(() {
                    _fgGranted = true;
                    _fgPermanentlyDenied = false;
                    _step = _PermStep.background;
                  });
                }
              },
            )
          : (!_fgGranted &&
                    !_fgPermanentlyDenied &&
                    _isLoading == false &&
                    _step == _PermStep.foreground
                ? null
                : null),
    );
  }

  // ── Step 2: Background Location ────────────────────────────────────────────

  Widget _buildBackgroundStep() {
    return _PrePromptCard(
      key: const ValueKey('perm_bg'),
      stepNumber: '2 of 4',
      icon: Icons.location_searching_rounded,
      iconColor: AppColors.teal,
      title: 'Allow "All the time" access',
      body:
          'To track location when the app is closed or the screen is off, '
          'select "Allow all the time" on the next screen. '
          'Without this, tracking pauses when you switch apps.',
      primaryLabel: 'Continue',
      secondaryLabel: 'Skip (foreground only)',
      isLoading: _isLoading,
      onPrimary: _requestBackground,
      onSecondary: () => setState(() {
        _bgGranted = false;
        _step = _PermStep.notifications;
      }),
    );
  }

  // ── Step 3: Notifications ──────────────────────────────────────────────────

  Widget _buildNotificationsStep() {
    return _PrePromptCard(
      key: const ValueKey('perm_notif'),
      stepNumber: _sharesLocation ? '3 of 4' : '1 of 1',
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'Allow notifications',
      body:
          'We send alerts when a family member arrives at a saved place, '
          'when the SOS button is pressed, and a persistent notification '
          'while location sharing is active.',
      primaryLabel: 'Allow notifications',
      secondaryLabel: 'Not now',
      isLoading: _isLoading,
      onPrimary: _requestNotifications,
      onSecondary: () => setState(() {
        _notifGranted = false;
        _step = _sharesLocation ? _PermStep.battery : _PermStep.allSet;
      }),
    );
  }

  // ── Step 4: Battery Optimization ──────────────────────────────────────────

  Widget _buildBatteryStep() {
    return _PrePromptCard(
      key: const ValueKey('perm_battery'),
      stepNumber: '4 of 4',
      icon: Icons.battery_charging_full_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Keep tracking reliable',
      body:
          'Android can put FamilyGuard to sleep to save battery. Tap "Allow" '
          'to prevent this — otherwise location updates may stop after the '
          'screen turns off.',
      primaryLabel: 'Allow',
      secondaryLabel: 'Skip',
      isLoading: _isLoading,
      onPrimary: _requestBattery,
      onSecondary: () => setState(() {
        _batteryGranted = false;
        _step = _requiresOem ? _PermStep.oem : _PermStep.allSet;
      }),
    );
  }

  // ── OEM Auto-start Step (Samsung / Xiaomi only) ────────────────────────────

  Widget _buildOemStep() {
    return Container(
      key: const ValueKey('perm_oem'),
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Progress chip
          _ProgressChip(label: 'One more setting'),
          const SizedBox(height: 32),
          // Icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_power_rounded,
              size: 40,
              color: Color(0xFFF97316),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Let's fix one more setting",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your device manufacturer adds an extra battery restriction that '
            'can stop FamilyGuard from running in the background.\n\n'
            'On the next screen, find FamilyGuard and enable "Auto-start" '
            'or "Allow background activity".',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const Spacer(),
          // Info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This setting is only available on certain devices '
                    '(Samsung, Xiaomi, etc.).',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _service.openSystemAppSettings();
                if (mounted) setState(() => _step = _PermStep.allSet);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Open settings',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _skipOem,
              child: const Text(
                "I'll do this later",
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── All Set Screen ─────────────────────────────────────────────────────────

  Widget _buildAllSet() {
    final summary = PermissionSummary(
      foregroundLocation: _fgGranted,
      backgroundLocation: _bgGranted,
      notifications: _notifGranted,
      batteryOptimization: _batteryGranted,
    );

    return Container(
      key: const ValueKey('perm_allset'),
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 48,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "You're all set!",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'FamilyGuard is ready. Here\'s your permission summary:',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // Permission summary rows
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (_sharesLocation)
                    _SummaryRow(
                      icon: Icons.my_location_rounded,
                      label: 'Location (foreground)',
                      granted: summary.foregroundLocation,
                    ),
                  if (_sharesLocation)
                    _SummaryRow(
                      icon: Icons.location_searching_rounded,
                      label: 'Location (background)',
                      granted: summary.backgroundLocation,
                      warnIfMissing: true,
                    ),
                  _SummaryRow(
                    icon: Icons.notifications_active_rounded,
                    label: 'Notifications',
                    granted: summary.notifications,
                  ),
                  if (_sharesLocation)
                    _SummaryRow(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Battery optimization',
                      granted: summary.batteryOptimization,
                    ),
                ],
              ),
            ),
          ),
          // Degraded-mode warning (test T2)
          if (_sharesLocation && summary.isDegraded) ...[
            const SizedBox(height: 16),
            _DegradedModeBanner(
              onFixTap: () async {
                final status = await _service.requestBackgroundLocation(
                  foregroundGranted: _fgGranted,
                );
                if (mounted) {
                  setState(() => _bgGranted = status.isGranted);
                }
              },
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Open FamilyGuard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _ProgressChip extends StatelessWidget {
  final String label;
  const _ProgressChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Pre-prompt card template — used for steps 1–4.
class _PrePromptCard extends StatelessWidget {
  final String stepNumber;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel;
  final bool isLoading;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final Widget? blocker;

  const _PrePromptCard({
    super.key,
    required this.stepNumber,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.secondaryLabel,
    required this.isLoading,
    required this.onPrimary,
    this.onSecondary,
    this.blocker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _ProgressChip(label: stepNumber),
          const SizedBox(height: 32),
          // Icon circle
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (blocker != null) ...[const SizedBox(height: 16), blocker!],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isLoading ? null : onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Blocking red banner shown when foreground location is permanently denied.
class _BlockerBanner extends StatelessWidget {
  final String message;
  final VoidCallback onOpenSettings;

  const _BlockerBanner({required this.message, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sosRedLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_rounded, color: AppColors.sosRed, size: 18),
              SizedBox(width: 8),
              Text(
                'Permission required',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sosRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.sosRed,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Settings'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.sosRed,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow warning banner on the All Set screen when background location
/// was denied — test T2 (degraded mode, not a dead-end).
class _DegradedModeBanner extends StatelessWidget {
  final VoidCallback onFixTap;
  const _DegradedModeBanner({required this.onFixTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Foreground-only mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Background location was not granted. Location tracking will '
            'pause when FamilyGuard is not in the foreground. '
            'You can fix this in Settings anytime.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onFixTap,
            icon: const Icon(Icons.location_on_rounded, size: 16),
            label: const Text('Grant background access'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row in the All Set permission summary card.
class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool granted;
  final bool warnIfMissing;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.granted,
    this.warnIfMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = granted
        ? const Color(0xFF10B981)
        : warnIfMissing
        ? const Color(0xFFD97706)
        : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Icon(
            granted
                ? Icons.check_circle_rounded
                : warnIfMissing
                ? Icons.warning_amber_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            granted
                ? 'Granted'
                : warnIfMissing
                ? 'Limited'
                : 'Skipped',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
