import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final isParent = appState.role == UserRole.parent;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Settings & Circle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Circle Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.groups_rounded, size: 28, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.circleName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Active Role: ${isParent ? "Parent / Guardian" : "Child Member"}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Role Switcher for preview / testing
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Preview Role Experience',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment(value: UserRole.parent, label: Text('Parent')),
                            ButtonSegment(value: UserRole.child, label: Text('Child')),
                          ],
                          selected: {appState.role},
                          onSelectionChanged: (Set<UserRole> selection) {
                            ref.read(appStateProvider.notifier).setRole(selection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Circle Members
          const Text('Circle Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _buildMemberRow('Dad (Alex)', 'Parent', '👨', isParent: true),
                const Divider(height: 1, indent: 56),
                _buildMemberRow('Emma', 'Child', '👩‍🦰', isParent: false),
                const Divider(height: 1, indent: 56),
                _buildMemberRow('Lucas', 'Child', '👦', isParent: false),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invite Code (Parent view)
          if (isParent) ...[
            Card(
              color: AppColors.primaryLight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Child Invite Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('FAMILY-7K4X', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.textPrimary)),
                        Icon(Icons.copy_rounded, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Permissions Status Dashboard
          const Text('Permission Status Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPermissionRow('Location Permission', 'Always Allowed', isGranted: true),
                  const Divider(height: 20),
                  _buildPermissionRow('Background Tracking', 'Tracelet Engine Active', isGranted: true),
                  const Divider(height: 20),
                  _buildPermissionRow('Battery Optimization', 'Unrestricted', isGranted: true),
                  const Divider(height: 20),
                  _buildPermissionRow('Notifications', 'Granted', isGranted: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out / Reset
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sosRed,
                side: const BorderSide(color: AppColors.sosRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                ref.read(appStateProvider.notifier).resetToOnboarding();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out / Reset Onboarding', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMemberRow(String name, String role, String avatar, {required bool isParent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(avatar, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isParent ? AppColors.primaryLight : AppColors.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isParent ? AppColors.primary : AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String title, String status, {required bool isGranted}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(status, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        Icon(
          isGranted ? Icons.check_circle_rounded : Icons.warning_rounded,
          color: isGranted ? AppColors.teal : AppColors.sosRed,
          size: 22,
        ),
      ],
    );
  }
}
