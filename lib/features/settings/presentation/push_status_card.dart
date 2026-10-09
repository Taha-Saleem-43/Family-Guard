import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/push_coordinator.dart';
import '../../../core/services/push_runtime.dart';

class PushStatusCard extends ConsumerWidget {
  const PushStatusCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pushCoordinatorProvider).status;
    final message = switch (status) {
      PushStatus.ready =>
        'Emergency push notifications are registered on this device.',
      PushStatus.registering => 'Registering emergency push notifications…',
      PushStatus.denied =>
        'Notifications are disabled. Enable them in device settings to receive background alerts.',
      PushStatus.unavailable =>
        'Push registration could not be confirmed. Check your connection and retry.',
      PushStatus.signedOut =>
        'Join a circle to register emergency push notifications.',
    };
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('Emergency notifications'),
      subtitle: Text(message),
      trailing: status == PushStatus.unavailable || status == PushStatus.denied
          ? IconButton(
              tooltip: 'Retry push registration',
              icon: const Icon(Icons.refresh),
              onPressed: () => PushRuntime.active?.retry(),
            )
          : null,
    );
  }
}
