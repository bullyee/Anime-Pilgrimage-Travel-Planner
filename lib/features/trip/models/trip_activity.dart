import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported activity action types in Phase 2 Safety Net.
enum TripActivityAction {
  createTrip('create_trip'),
  updateTrip('update_trip'),
  addDay('add_day'),
  reorderDays('reorder_days'),
  removeDay('remove_day'),
  restoreDay('restore_day'),
  addStop('add_stop'),
  updateStop('update_stop'),
  removeStop('remove_stop'),
  restoreStop('restore_stop'),
  scheduleStop('schedule_stop'),
  unscheduleStop('unschedule_stop'),
  setVisited('set_visited'),
  memberJoined('member_joined'),
  memberLeft('member_left'),
  roleChanged('role_changed');

  final String value;
  const TripActivityAction(this.value);

  static TripActivityAction fromString(String val) {
    return TripActivityAction.values.firstWhere(
      (a) => a.value == val,
      orElse: () => TripActivityAction.updateTrip,
    );
  }
}

/// Represents an audit log entry in `tripsV2/{tripId}/activity/{activityId}`.
class TripActivity {
  final String id;
  final String tripId;
  final String actorId;
  final String? actorName;
  final TripActivityAction action;
  final String entityType; // 'trip', 'day', 'stop', 'schedule_item', 'member'
  final String entityId;
  final String summary;
  final Map<String, dynamic>? details;
  final DateTime createdAt;
  final DateTime expireAt;

  const TripActivity({
    required this.id,
    required this.tripId,
    required this.actorId,
    this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.summary,
    this.details,
    required this.createdAt,
    required this.expireAt,
  });

  /// Factory to create a new activity with automatic 30-day TTL expiration.
  factory TripActivity.create({
    required String id,
    required String tripId,
    required String actorId,
    String? actorName,
    required TripActivityAction action,
    required String entityType,
    required String entityId,
    required String summary,
    Map<String, dynamic>? details,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return TripActivity(
      id: id,
      tripId: tripId,
      actorId: actorId,
      actorName: actorName,
      action: action,
      entityType: entityType,
      entityId: entityId,
      summary: summary,
      details: details,
      createdAt: now,
      expireAt: now.add(const Duration(days: 30)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'actorId': actorId,
      if (actorName != null) 'actorName': actorName,
      'action': action.value,
      'entityType': entityType,
      'entityId': entityId,
      'summary': summary,
      if (details != null) 'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
      'expireAt': Timestamp.fromDate(expireAt),
    };
  }

  factory TripActivity.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = parseDate(map['createdAt']);
    final expireAt = map['expireAt'] != null
        ? parseDate(map['expireAt'])
        : createdAt.add(const Duration(days: 30));

    return TripActivity(
      id: map['id'] as String? ?? '',
      tripId: map['tripId'] as String? ?? '',
      actorId: map['actorId'] as String? ?? '',
      actorName: map['actorName'] as String?,
      action: TripActivityAction.fromString(map['action'] as String? ?? ''),
      entityType: map['entityType'] as String? ?? '',
      entityId: map['entityId'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      details: map['details'] is Map ? Map<String, dynamic>.from(map['details'] as Map) : null,
      createdAt: createdAt,
      expireAt: expireAt,
    );
  }
}

