import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/member.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../auth/providers/auth_providers.dart';

typedef LeaveCircleAction =
    Future<void> Function(String uid, String circleId, String? successorId);
final leaveCircleActionProvider = Provider<LeaveCircleAction>((ref) {
  return (uid, circleId, successorId) async {
    await ref.read(authServiceProvider).leaveCircle(uid, circleId, successorId);
    ref.read(appStateProvider.notifier).finishLeavingCircle(uid, circleId);
  };
});

class LeaveCircleControl extends ConsumerStatefulWidget {
  const LeaveCircleControl({super.key, required this.members});
  final List<Member> members;

  @override
  ConsumerState<LeaveCircleControl> createState() => _LeaveCircleControlState();
}

class _LeaveCircleControlState extends ConsumerState<LeaveCircleControl> {
  bool _busy = false;
  String? _message;

  Future<void> _leave() async {
    if (_busy) return;
    final session = ref.read(appStateProvider);
    if (widget.members.any(
      (member) => member.id == session.userId && member.isSosActive,
    )) {
      setState(
        () => _message = 'Resolve your active SOS before leaving the circle.',
      );
      return;
    }
    final parents = widget.members
        .where(
          (member) =>
              member.id != session.userId && member.role == UserRole.parent,
        )
        .toList();
    String? successorId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final needsParent =
              session.role == UserRole.parent &&
              widget.members.any((member) => member.id != session.userId);
          return AlertDialog(
            title: const Text('Leave this circle?'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location sharing and access to this circle will stop. '
                  'Your account stays active so you can create or join another circle. '
                  'Leaving does not delete previously recorded history. '
                  'Existing invite codes will be replaced. '
                  'If you are the only member, leaving closes the circle and removes its saved places.',
                ),
                if (session.role == UserRole.parent) ...[
                  const SizedBox(height: 16),
                  if (parents.isEmpty)
                    Text(
                      needsParent
                          ? 'You are the last parent. Invite a trusted adult using the co-parent code, '
                                'wait for them to join, then return here. Children cannot be selected as parents.'
                          : 'If you are the only member, leaving closes the circle and removes its saved places.',
                    )
                  else ...[
                    const Text(
                      'Choose the co-parent who will take responsibility:',
                    ),
                    for (final parent in parents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          successorId == parent.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(parent.name),
                        onTap: () =>
                            setDialogState(() => successorId = parent.id),
                        selected: successorId == parent.id,
                      ),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: needsParent && successorId == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Leave circle'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    final current = ref.read(appStateProvider);
    if (current.userId != session.userId ||
        current.circleId != session.circleId ||
        current.role != session.role) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(leaveCircleActionProvider)(
        session.userId,
        session.circleId,
        successorId,
      );
    } catch (error) {
      if (!mounted) return;
      final current = ref.read(appStateProvider);
      if (current.userId != session.userId ||
          current.circleId != session.circleId) {
        return;
      }
      setState(
        () => _message =
            error is FirebaseFunctionsException &&
                error.code == 'failed-precondition'
            ? 'Sharing may be paused on this device. Resolve any active SOS and check that your selected co-parent is still in the circle. '
                  'The last parent cannot leave children without another parent.'
            : 'Could not confirm that you left. Sharing may be paused on this device. '
                  'Check your connection and circle membership before retrying.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appStateProvider);
    if (session.circleId.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _leave,
          icon: const Icon(Icons.group_remove_outlined),
          label: Text(_busy ? 'Leaving circle…' : 'Leave circle'),
        ),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
      ],
    );
  }
}
