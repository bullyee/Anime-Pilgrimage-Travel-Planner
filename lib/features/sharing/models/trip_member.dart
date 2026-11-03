import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum TripMemberRole {
  owner,
  editor,
  viewer;

  static TripMemberRole fromString(String? role) {
    switch (role) {
      case 'owner':
        return TripMemberRole.owner;
      case 'editor':
        return TripMemberRole.editor;
      case 'viewer':
      default:
        return TripMemberRole.viewer;
    }
  }

  String toRoleString() {
    switch (this) {
      case TripMemberRole.owner:
        return 'owner';
      case TripMemberRole.editor:
        return 'editor';
      case TripMemberRole.viewer:
        return 'viewer';
    }
  }
}

class TripMember {
  final String userId;
  final String tripId;
  final TripMemberRole role;
  final String displayName;
  final String? avatarUrl;
  final DateTime joinedAt;

  TripMember({
    required this.userId,
    required this.tripId,
    required this.role,
    required this.displayName,
    this.avatarUrl,
    required this.joinedAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory TripMember.fromMap(Map<String, dynamic> data) {
    return TripMember(
      userId: data['userId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      role: TripMemberRole.fromString(data['role'] as String?),
      displayName: data['displayName'] as String? ?? 'Anonymous',
      avatarUrl: data['avatarUrl'] as String?,
      joinedAt: _parseDateTime(data['joinedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tripId': tripId,
      'role': role.toRoleString(),
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}
