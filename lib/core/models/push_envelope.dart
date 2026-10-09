class PushEnvelope {
  final String alertId, circleId, recipientUid, installationId;
  final int registrationVersion;
  final String type;
  const PushEnvelope(
    this.alertId,
    this.circleId,
    this.recipientUid,
    this.installationId,
    this.registrationVersion, {
    this.type = 'sos',
  });

  static PushEnvelope? parse(Map<String, dynamic> data) {
    if (!['sos', 'place'].contains(data['type']) ||
        data['schemaVersion'] != '1') {
      return null;
    }
    final id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    for (final key in ['alertId', 'circleId', 'recipientUid']) {
      if (data[key] is! String || !id.hasMatch(data[key] as String)) {
        return null;
      }
    }
    if (data['installationId'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(data['installationId'] as String)) {
      return null;
    }
    final version = int.tryParse('${data['registrationVersion']}');
    if (version == null || version < 1 || version > 9007199254740991) {
      return null;
    }
    return PushEnvelope(
      data['alertId'] as String,
      data['circleId'] as String,
      data['recipientUid'] as String,
      data['installationId'] as String,
      version,
      type: data['type'] as String,
    );
  }

  Map<String, dynamic> acknowledgement(String kind) => {
    'expectedUid': recipientUid,
    'alertId': alertId,
    'installationId': installationId,
    'registrationVersion': registrationVersion,
    'kind': kind,
  };
}
