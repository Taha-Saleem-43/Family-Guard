import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/account_deletion_service.dart';

typedef AccountDeletionAction =
    Future<AccountDeletionReceipt> Function(String uid, String password);
final accountDeletionActionProvider = Provider<AccountDeletionAction>((ref) {
  return (uid, password) async {
    final auth = ref.read(authServiceProvider);
    final service = AccountDeletionService(
      verify: auth.verifyDeletionSignIn,
      pauseSharing: auth.pauseDeletionSharing,
      enqueue: auth.enqueueAccountDeletion,
      clearLocal: auth.clearDeletedAccountLocalData,
      signOut: auth.signOutDeletedAccount,
    );
    final receipt = await service.request(uid, password);
    if (ref.read(appStateProvider).userId == uid) {
      ref.read(appStateProvider.notifier).resetToOnboarding();
    }
    return receipt;
  };
});

class AccountDeletionControl extends ConsumerStatefulWidget {
  const AccountDeletionControl({super.key});
  @override
  ConsumerState<AccountDeletionControl> createState() =>
      _AccountDeletionControlState();
}

class _AccountDeletionControlState
    extends ConsumerState<AccountDeletionControl> {
  bool _busy = false;
  String? _error;
  Future<void> _request() async {
    final uid = ref.read(appStateProvider).userId;
    if (uid.isEmpty || _busy) return;
    final password = TextEditingController();
    final confirmation = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your account, location history, alerts and places you created will be removed. '
                'You will leave your circle. Other members keep their accounts and data. '
                'An empty circle will close. This cannot be undone. Enter your password to verify your sign-in.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (password.text.isNotEmpty) {
                Navigator.pop(context, password.text);
              }
            },
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );
    final value = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(confirmation);
    unawaited(confirmation.completed.then((_) => password.dispose()));
    if (!mounted || value == null) return;
    final action = ref.read(accountDeletionActionProvider);
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Requesting account deletion…')),
            ],
          ),
        ),
      ),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    unawaited(navigator.push(progress));
    try {
      final receipt = await action(uid, value);
      final currentUid = ref.read(appStateProvider).userId;
      if (messenger.mounted && (currentUid.isEmpty || currentUid == uid)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              receipt.localCleanupComplete
                  ? 'Account deletion requested. Backend cleanup will continue in the background.'
                  : 'Account deletion requested. Some local tracking data could not be cleared; remove the app to clear its local storage.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AccountDeletionFailure
              ? error.message
              : 'Could not request account deletion. Try again.';
        });
      }
    } finally {
      if (navigator.mounted && progress.isActive) {
        navigator.removeRoute(progress);
      }
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(appStateProvider.select((state) => state.userId));
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        TextButton.icon(
          onPressed: _busy || uid.isEmpty ? null : _request,
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Delete account'),
          style: TextButton.styleFrom(foregroundColor: AppColors.sosRed),
        ),
      ],
    );
  }
}
