import 'package:flutter/material.dart';
import '../../../core/models/permission_summary.dart';
import '../../../core/services/permission_service.dart';

class PermissionStatusCard extends StatefulWidget {
  const PermissionStatusCard({super.key});
  @override
  State<PermissionStatusCard> createState() => _PermissionStatusCardState();
}

class _PermissionStatusCardState extends State<PermissionStatusCard>
    with WidgetsBindingObserver {
  final _service = PermissionService();
  late Future<PermissionSummary> _status;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = _service.getPermissionSummary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    setState(() => _status = _service.getPermissionSummary());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _row(String label, bool granted) => ListTile(
    title: Text(label),
    subtitle: Text(granted ? 'Granted' : 'Not granted'),
    trailing: Icon(
      granted ? Icons.check_circle_outline : Icons.warning_amber_rounded,
      color: granted ? Colors.teal : Colors.orange,
    ),
  );
  @override
  Widget build(BuildContext context) => Card(
    child: FutureBuilder<PermissionSummary>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ListTile(
            title: const Text('Unable to check permissions'),
            trailing: IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          );
        }
        final status = snapshot.data!;
        return Column(
          children: [
            _row('Location permission', status.foregroundLocation),
            _row('Background location permission', status.backgroundLocation),
            _row('Battery optimization exemption', status.batteryOptimization),
            _row('Notifications', status.notifications),
            TextButton(
              onPressed: _service.openSystemAppSettings,
              child: const Text('Open app settings'),
            ),
          ],
        );
      },
    ),
  );
}
