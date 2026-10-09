import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_state_provider.dart';
import '../../providers/sos_provider.dart';
import 'sos_overlay.dart';
import 'sos_receiver_dialog.dart';

final sosComposerProvider = StateProvider<bool>((ref) => false);

/// Keeps emergency handling mounted while the user changes app tabs.
class EmergencyHost extends ConsumerWidget {
  final Widget child;
  const EmergencyHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AppState>(appStateProvider, (previous, next) {
      if (previous?.userId != next.userId ||
          previous?.circleId != next.circleId) {
        ref.read(sosComposerProvider.notifier).state = false;
      }
    });
    final emergency = ref.watch(sosProvider);
    final composing = ref.watch(sosComposerProvider);
    final incoming = emergency.unhandledCircleEmergency;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (emergency.updatesUnavailable)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Colors.amber,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Emergency updates unavailable. Check your connection.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        if (composing || emergency.isSelfSosActive)
          SOSOverlay(
            onCancel: () =>
                ref.read(sosComposerProvider.notifier).state = false,
          )
        else if (incoming != null) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: SOSReceiverDialog(
              key: ValueKey(incoming.id),
              alert: incoming,
            ),
          ),
        ],
      ],
    );
  }
}
