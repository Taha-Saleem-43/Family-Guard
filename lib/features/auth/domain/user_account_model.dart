import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/member.dart';

class UserAccountModel extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? circleId;
  final DateTime createdAt;

  const UserAccountModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.circleId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role == UserRole.parent ? 'parent' : 'child',
      'circleId': circleId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserAccountModel.fromMap(Map<String, dynamic> map, String id) {
    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt)
        : null;
    return UserAccountModel(
      uid: id,
      email: map['email'] is String ? map['email'] as String : '',
      displayName: map['displayName'] is String
          ? map['displayName'] as String
          : '',
      role: map['role'] == 'parent' ? UserRole.parent : UserRole.child,
      circleId: map['circleId'] is String ? map['circleId'] as String : null,
      createdAt:
          createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  UserAccountModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? circleId,
    DateTime? createdAt,
  }) {
    return UserAccountModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      circleId: circleId ?? this.circleId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    displayName,
    role,
    circleId,
    createdAt,
  ];
}
