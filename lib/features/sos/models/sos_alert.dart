import 'package:equatable/equatable.dart';

class SOSAlert extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String circleId;
  final double? latitude;
  final double? longitude;
  final String address;
  final DateTime timestamp;
  final String status; // 'active' | 'resolved'
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final int durationSeconds;

  const SOSAlert({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.circleId,
    this.latitude,
    this.longitude,
    this.address = 'Unknown location',
    required this.timestamp,
    this.status = 'active',
    this.resolvedAt,
    this.resolvedBy,
    this.durationSeconds = 0,
  });

  bool get isActive => status == 'active';

  /// Computes current live duration if active, or returns stored durationSeconds if resolved
  int get currentDurationSeconds {
    if (!isActive && durationSeconds > 0) return durationSeconds;
    if (resolvedAt != null) {
      return resolvedAt!.difference(timestamp).inSeconds;
    }
    return DateTime.now().difference(timestamp).inSeconds;
  }

  /// Formatted duration string (e.g. "02:45" or "4m 12s")
  String get formattedDuration {
    final secs = currentDurationSeconds;
    final mins = secs ~/ 60;
    final remainderSecs = secs % 60;
    if (mins > 0) {
      return '${mins}m ${remainderSecs}s';
    }
    return '${remainderSecs}s';
  }

  /// Formatted ticker string (e.g., "02:45")
  String get formattedTicker {
    final secs = currentDurationSeconds;
    final mins = secs ~/ 60;
    final remainderSecs = secs % 60;
    final mStr = mins.toString().padLeft(2, '0');
    final sStr = remainderSecs.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  factory SOSAlert.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return SOSAlert(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Family Member',
      circleId: map['circleId'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'] as String? ?? 'Location Pending',
      timestamp: parseDate(map['timestamp']),
      status: map['status'] as String? ?? 'active',
      resolvedAt: map['resolvedAt'] != null ? parseDate(map['resolvedAt']) : null,
      resolvedBy: map['resolvedBy'] as String?,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'circleId': circleId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'durationSeconds': durationSeconds,
    };
  }

  SOSAlert copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? circleId,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? timestamp,
    String? status,
    DateTime? resolvedAt,
    String? resolvedBy,
    int? durationSeconds,
  }) {
    return SOSAlert(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      circleId: circleId ?? this.circleId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        senderName,
        circleId,
        latitude,
        longitude,
        address,
        timestamp,
        status,
        resolvedAt,
        resolvedBy,
        durationSeconds,
      ];
}
