import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_state_provider.dart';
import '../../models/push_delivery_summary.dart';
import '../../services/sos_service.dart';

final pushDeliverySummaryProvider = StreamProvider.autoDispose
    .family<PushDeliverySummary, String>((ref, id) {
      ref.watch(appStateProvider.select((account) => account.userId));
      final circleId = ref.watch(
        appStateProvider.select((account) => account.circleId),
      );
      return SOSService().streamPushDeliverySummary(id, circleId);
    });

class PushDeliveryStatus extends ConsumerWidget {
  final String alertId;
  const PushDeliveryStatus({super.key, required this.alertId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(pushDeliverySummaryProvider(alertId));
    final String message;
    if (summary.hasError) {
      message = 'Push delivery updates unavailable.';
    } else if (summary.isLoading || summary.value == null) {
      message = 'Checking push delivery…';
    } else {
      final value = summary.value!;
      message =
          'Push accepted: ${value.accepted} devices · Opened: ${value.opened} devices'
          '${value.pending > 0 ? '\n${value.pending} device notifications pending.' : ''}'
          '${value.failed > 0 ? '\n${value.failed} device notifications could not be completed.' : ''}'
          '\nPush acceptance does not confirm someone has received help.';
    }
    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: Colors.white),
    );
  }
}
