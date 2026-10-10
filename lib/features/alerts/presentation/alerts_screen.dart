import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/presentation/screen_header.dart';
import '../../../core/presentation/feedback_panel.dart';
import '../../sos/models/sos_alert.dart';
import '../../sos/providers/sos_provider.dart';
import '../providers/place_events_provider.dart';
import '../../../core/models/alert_event.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sosHistoryAsync = ref.watch(circleSosHistoryProvider);
    final placeEventsAsync = ref.watch(circlePlaceEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ScreenHeader(
        title: 'Activity',
        subtitle: 'SOS alerts and confirmed place updates.',
      ),
      body: sosHistoryAsync.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => FeedbackPanel(
          icon: Icons.cloud_off_rounded,
          title: 'Activity is unavailable',
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () {
            ref.invalidate(circleSosHistoryProvider);
            ref.invalidate(circlePlaceEventsProvider);
          },
        ),
        data: (alerts) {
          final places =
              !placeEventsAsync.isLoading && !placeEventsAsync.hasError
              ? placeEventsAsync.valueOrNull ?? <AlertEvent>[]
              : <AlertEvent>[];
          final items = <({DateTime time, SOSAlert? sos, AlertEvent? place})>[
            for (final alert in alerts)
              (time: alert.timestamp, sos: alert, place: null),
            for (final event in places)
              (time: event.timestamp, sos: null, place: event),
          ]..sort((a, b) => b.time.compareTo(a.time));
          if (items.isEmpty && placeEventsAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty && placeEventsAsync.hasError) {
            return FeedbackPanel(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to Load Place Activity',
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(circlePlaceEventsProvider),
            );
          }
          if (items.isEmpty) {
            return _buildEmptyState(
              title: 'No activity yet',
              subtitle:
                  'SOS emergencies and confirmed place arrivals and departures will appear here.',
            );
          }

          return Column(
            children: [
              if (placeEventsAsync.hasError)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const Text('Place activity is temporarily unavailable.'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(circlePlaceEventsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.sos != null) return _buildSOSAlertCard(item.sos!);
                    final event = item.place!;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          event.type == AlertEventType.arrive
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          color: AppColors.teal,
                        ),
                        title: Text(
                          '${event.memberName} ${event.type == AlertEventType.arrive ? 'arrived at' : 'left'} ${event.placeName}',
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, h:mm a').format(event.timestamp),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return FeedbackPanel(
      icon: Icons.notifications_none_rounded,
      title: title,
      message: subtitle,
    );
  }

  Widget _buildSOSAlertCard(SOSAlert alert) {
    final isActive = alert.isActive;
    final color = isActive ? AppColors.sosRed : AppColors.teal;
    final timeStr = DateFormat('MMM d, h:mm a').format(alert.timestamp);
    final durationText = alert.formattedDuration;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.sosRed : AppColors.border,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.sosRed : Colors.black).withValues(
              alpha: isActive ? 0.15 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.emergency_rounded : Icons.check_circle_rounded,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isActive
                            ? '🚨 SOS EMERGENCY ALERT'
                            : 'Emergency Alert Resolved',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isActive
                              ? AppColors.sosRed
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'RESOLVED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.senderName} broadcasted an emergency SOS',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Duration: $durationText',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (alert.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📍 ${alert.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
