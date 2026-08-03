import 'package:equatable/equatable.dart';

class CircleModel extends Equatable {
  final String id;
  final String name;
  final String parentInviteCode;
  final String childInviteCode;
  final String createdBy;
  final List<String> memberIds;
  final DateTime createdAt;

  const CircleModel({
    required this.id,
    required this.name,
    required this.parentInviteCode,
    required this.childInviteCode,
    required this.createdBy,
    required this.memberIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentInviteCode': parentInviteCode,
      'childInviteCode': childInviteCode,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CircleModel.fromMap(Map<String, dynamic> map, String id) {
    return CircleModel(
      id: id,
      name: map['name'] as String? ?? 'Family Circle',
      parentInviteCode: map['parentInviteCode'] as String? ?? '',
      childInviteCode: map['childInviteCode'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        parentInviteCode,
        childInviteCode,
        createdBy,
        memberIds,
        createdAt,
      ];
}
