import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/presentation/member_activity_status.dart';
import '../../../core/models/member.dart';
import '../../../core/models/movement_activity.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/providers/member_status_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/presentation/screen_header.dart';
import '../../auth/providers/auth_providers.dart';
import '../../map/presentation/widgets/member_detail_sheet.dart';
import 'permission_status_card.dart';
import 'invite_rotation_control.dart';
import 'account_deletion_control.dart';
import 'push_status_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final isParent = appState.role == UserRole.parent;
    final members = ref.watch(memberStateProvider);

    Future<void> copyToClipboard(
      BuildContext context,
      String code,
      String label,
    ) async {
      if (code.trim().isEmpty) return;
      try {
        await Clipboard.setData(ClipboardData(text: code));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not copy the invite code. Please try again.',
              ),
            ),
          );
        }
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('$label code copied to clipboard.')),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ScreenHeader(
        title: 'Settings',
        subtitle: 'Your circle, sharing and account preferences.',
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
                        child: const Icon(
                          Icons.groups_rounded,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.circleName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isParent ? 'Parent / Guardian' : 'Child member',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
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

          // Circle Members
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                isParent ? 'Circle members' : 'Your profile',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isParent)
                Text(
                  '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < members.length; i++) ...[
                  _buildMemberRow(context, ref, members[i]),
                  if (i < members.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invite Codes (Parent view)
          if (isParent) ...[
            Card(
              color: AppColors.primaryLight,
              child: InkWell(
                onTap: appState.childInviteCode.trim().isEmpty
                    ? null
                    : () => copyToClipboard(
                        context,
                        appState.childInviteCode,
                        'Child Invite',
                      ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Child Member Invite Code',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.childInviteCode.trim().isEmpty
                                  ? 'Code unavailable'
                                  : appState.childInviteCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: appState.childInviteCode.trim().isEmpty
                            ? null
                            : () => copyToClipboard(
                                context,
                                appState.childInviteCode,
                                'Child Invite',
                              ),
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Copy Child Invite Code',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: AppColors.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              child: InkWell(
                onTap: appState.parentInviteCode.trim().isEmpty
                    ? null
                    : () => copyToClipboard(
                        context,
                        appState.parentInviteCode,
                        'Co-Parent Invite',
                      ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Co-Parent Invite Code (Full Admin)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appState.parentInviteCode.trim().isEmpty
                                  ? 'Code unavailable'
                                  : appState.parentInviteCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: appState.parentInviteCode.trim().isEmpty
                            ? null
                            : () => copyToClipboard(
                                context,
                                appState.parentInviteCode,
                                'Co-Parent Invite',
                              ),
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Copy Parent Invite Code',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Permissions Status Dashboard
          if (isParent) ...[
            const InviteRotationControl(),
            const SizedBox(height: 16),
          ],
          const Text(
            'Sharing and notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const PermissionStatusCard(),
                  const PushStatusCard(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out / Reset
          const AccountDeletionControl(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sosRed,
                side: const BorderSide(color: AppColors.sosRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                try {
                  await ref.read(authServiceProvider).signOut();
                  ref.read(appStateProvider.notifier).resetToOnboarding();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to stop sharing and sign out. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Sign out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMemberRow(BuildContext context, WidgetRef ref, Member member) {
    final activity = member.currentActivity;
    final batColor = BatteryHelper.getColor(member.batteryLevel);
    final batIcon = BatteryHelper.getIcon(
      member.batteryLevel,
      isCharging: member.isCharging,
    );
    final isParentRole = member.role == UserRole.parent;

    return InkWell(
      onTap: () => MemberDetailSheet.show(context, member),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(member.avatar, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isParentRole
                              ? AppColors.primaryLight
                              : AppColors.tealLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isParentRole ? 'Parent' : 'Child',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isParentRole
                                ? AppColors.primary
                                : AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Allow status badges to wrap with larger text.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Movement Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (activity?.bgColor ?? Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (activity?.color ?? AppColors.textMuted)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (activity?.emoji ?? '🕓'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                (activity?.label ?? 'Activity unknown'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      (activity?.color ?? AppColors.textMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Battery Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: batColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(batIcon, size: 12, color: batColor),
                            const SizedBox(width: 2),
                            Text(
                              BatteryHelper.label(member.batteryLevel),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: batColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
