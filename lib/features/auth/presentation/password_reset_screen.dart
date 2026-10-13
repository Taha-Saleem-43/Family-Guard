import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    required this.sendReset,
    this.initialEmail = '',
  });

  final Future<void> Function(String) sendReset;
  final String initialEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.sendReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      final code = error is FirebaseAuthException ? error.code : '';
      setState(
        () => _error = switch (code) {
          'invalid-email' => 'Enter a valid email address.',
          'too-many-requests' =>
            'Too many attempts. Please wait before trying again.',
          'network-request-failed' =>
            'Check your internet connection and try again.',
          _ => 'Unable to request a reset email. Please try again.',
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your account email to request a password reset link.',
              ),
              const SizedBox(height: 24),
              if (!_sent) ...[
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (value) =>
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a valid email address.',
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(_busy ? 'Requesting reset…' : 'Send reset link'),
                ),
              ],
              if (_error != null || _sent) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _sent
                        ? 'If an account uses this email, you will receive a reset link. Check your inbox and spam folder, then return to sign in.'
                        : _error!,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
