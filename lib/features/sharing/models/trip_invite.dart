import 'trip_member.dart';

class TripInvite {
  final String token;
  final String shortCode;
  final String tripId;
  final TripMemberRole role;
  final String createdBy;
  final String inviterName;
  final String? inviterAvatarUrl;
  final String tripTitle;
  final String? tripDates;
  final int stopCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isRevoked;
  final List<String> emailAllowlist;

  TripInvite({
    required this.token,
    required this.shortCode,
    required this.tripId,
    required this.role,
    required this.createdBy,
    required this.inviterName,
    this.inviterAvatarUrl,
    required this.tripTitle,
    this.tripDates,
    required this.stopCount,
    required this.createdAt,
    required this.expiresAt,
    this.isRevoked = false,
    this.emailAllowlist = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isRevoked && !isExpired;

  factory TripInvite.fromMap(Map<String, dynamic> data) {
    return TripInvite(
      token: data['token'] as String? ?? '',
      shortCode: data['shortCode'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      role: TripMemberRole.fromString(data['role'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      inviterName: data['inviterName'] as String? ?? 'Collaborator',
      inviterAvatarUrl: data['inviterAvatarUrl'] as String?,
      tripTitle: data['tripTitle'] as String? ?? 'Trip Pilgrimage',
      tripDates: data['tripDates'] as String?,
      stopCount: (data['stopCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] is DateTime)
          ? data['createdAt'] as DateTime
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: (data['expiresAt'] is DateTime)
          ? data['expiresAt'] as DateTime
          : DateTime.tryParse(data['expiresAt']?.toString() ?? '') ??
              DateTime.now().add(const Duration(days: 7)),
      isRevoked: data['isRevoked'] as bool? ?? false,
      emailAllowlist: List<String>.from(data['emailAllowlist'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'shortCode': shortCode,
      'tripId': tripId,
      'role': role.toRoleString(),
      'createdBy': createdBy,
      'inviterName': inviterName,
      'inviterAvatarUrl': inviterAvatarUrl,
      'tripTitle': tripTitle,
      'tripDates': tripDates,
      'stopCount': stopCount,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isRevoked': isRevoked,
      'emailAllowlist': emailAllowlist,
    };
  }
}

