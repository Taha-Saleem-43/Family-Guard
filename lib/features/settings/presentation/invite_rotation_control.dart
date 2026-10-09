import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../auth/providers/auth_providers.dart';

final inviteRotationProvider = Provider<Future<DateTime> Function(String)>(
  (ref) => ref.read(authServiceProvider).rotateCircleInvites,
);

class InviteRotationControl extends ConsumerStatefulWidget {
  const InviteRotationControl({super.key});
  @override
  ConsumerState<InviteRotationControl> createState() =>
      _InviteRotationControlState();
}

class _InviteRotationControlState extends ConsumerState<InviteRotationControl> {
  bool _busy = false;
  String? _message;
  Future<void> _rotate() async {
    final session = ref.read(appStateProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace invite codes?'),
        content: const Text(
          'Both current codes will stop working. New codes expire in seven days. Existing members stay in the circle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace codes'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    final current = ref.read(appStateProvider);
    if (current.userId != session.userId ||
        current.circleId != session.circleId ||
        current.role != UserRole.parent) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(inviteRotationProvider)(session.circleId);
      if (!mounted) return;
      final current = ref.read(appStateProvider);
      if (current.userId != session.userId ||
          current.circleId != session.circleId) {
        return;
      }
      // Displayed codes are owned by the existing private-invite server stream.
      setState(
        () => _message =
            'Previous codes are invalid. New codes expire in seven days.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not confirm code replacement. Check the displayed codes and retry when connected.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiry = ref.watch(
      appStateProvider.select((state) => state.inviteExpiresAt),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          expiry == null
              ? 'Invite expiry is unavailable. Replace codes if they do not work.'
              : expiry.isBefore(DateTime.now())
              ? 'Invite codes have expired. Replace them to invite new members.'
              : 'Codes expire ${DateFormat.yMMMd().add_jm().format(expiry.toLocal())}.',
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _rotate,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Replace invite codes'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!),
          ),
      ],
    );
  }
}
