import 'package:flutter/material.dart';

/// Does not mount account providers or screens until local cache cleanup passes.
class LocalPrivacyGate extends StatefulWidget {
  final Future<void> Function() prepare;
  final Widget child;
  const LocalPrivacyGate({
    super.key,
    required this.prepare,
    required this.child,
  });

  @override
  State<LocalPrivacyGate> createState() => _LocalPrivacyGateState();
}

class _LocalPrivacyGateState extends State<LocalPrivacyGate> {
  bool _ready = false;
  bool _failed = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (_running) return;
    setState(() {
      _running = true;
      _failed = false;
    });
    try {
      await widget.prepare();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Local privacy cleanup could not finish. Close other app instances and retry. Your account will open after cleanup succeeds.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _running ? null : _prepare,
                          child: const Text('Retry cleanup'),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Preparing private storage…'),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
