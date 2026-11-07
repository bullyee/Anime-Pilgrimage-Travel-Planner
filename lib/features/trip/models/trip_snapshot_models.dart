import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Metadata for a saved trip snapshot.
@immutable
class TripSnapshotMetadata {
  final String id;
  final String tripId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final String createdBy;
  final int dayCount;
  final int stopCount;
  final int scheduleItemCount;

  const TripSnapshotMetadata({
    required this.id,
    required this.tripId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.createdBy,
    required this.dayCount,
    required this.stopCount,
    required this.scheduleItemCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'dayCount': dayCount,
        'stopCount': stopCount,
        'scheduleItemCount': scheduleItemCount,
      };

  factory TripSnapshotMetadata.fromJson(Map<String, dynamic> json) => TripSnapshotMetadata(
        id: json['id'] as String,
        tripId: json['tripId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        dayCount: json['dayCount'] as int? ?? 1,
        stopCount: json['stopCount'] as int? ?? 0,
        scheduleItemCount: json['scheduleItemCount'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripSnapshotMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tripId == other.tripId &&
          name == other.name &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, tripId, name, createdAt);
}

/// Snapshot of the core trip attributes.
@immutable
class TripDataSnapshot {
  final String title;
  final String? description;
  final String? startDate;
  final int dayCount;

  const TripDataSnapshot({
    required this.title,
    this.description,
    this.startDate,
    this.dayCount = 1,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'startDate': startDate,
        'dayCount': dayCount,
      };

  factory TripDataSnapshot.fromJson(Map<String, dynamic> json) => TripDataSnapshot(
        title: json['title'] as String,
        description: json['description'] as String?,
        startDate: json['startDate'] as String?,
        dayCount: json['dayCount'] as int? ?? 1,
      );
}

/// Snapshot of a day block within a trip.
@immutable
class TripDaySnapshot {
  final String id;
  final String sortKey;
  final String? title;
  final String? pinnedDate;

  const TripDaySnapshot({
    required this.id,
    required this.sortKey,
    this.title,
    this.pinnedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sortKey': sortKey,
        'title': title,
        'pinnedDate': pinnedDate,
      };

  factory TripDaySnapshot.fromJson(Map<String, dynamic> json) => TripDaySnapshot(
        id: json['id'] as String,
        sortKey: json['sortKey'] as String,
        title: json['title'] as String?,
        pinnedDate: json['pinnedDate'] as String?,
      );
}

/// Snapshot of a stop within a trip.
@immutable
class StopSnapshot {
  final String id;
  final String placeKey;
  final String name;
  final double lat;
  final double lng;
  final String? description;
  final String? address;
  final String? businessHours;
  final String? contactInfo;
  final String? accessTips;
  final String? links;
  final String? coverLocalPath;
  final String? coverRemoteUrl;
  final String? source;
  final String? sourceUrl;
  final String? area;
  final String? note;
  final String addedBy;
  final List<String> labelIds;

  const StopSnapshot({
    required this.id,
    required this.placeKey,
    required this.name,
    required this.lat,
    required this.lng,
    this.description,
    this.address,
    this.businessHours,
    this.contactInfo,
    this.accessTips,
    this.links,
    this.coverLocalPath,
    this.coverRemoteUrl,
    this.source,
    this.sourceUrl,
    this.area,
    this.note,
    this.addedBy = 'snapshot',
    this.labelIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeKey': placeKey,
        'name': name,
        'lat': lat,
        'lng': lng,
        'description': description,
        'address': address,
        'businessHours': businessHours,
        'contactInfo': contactInfo,
        'accessTips': accessTips,
        'links': links,
        'coverLocalPath': coverLocalPath,
        'coverRemoteUrl': coverRemoteUrl,
        'source': source,
        'sourceUrl': sourceUrl,
        'area': area,
        'note': note,
        'addedBy': addedBy,
        'labelIds': labelIds,
      };

  factory StopSnapshot.fromJson(Map<String, dynamic> json) => StopSnapshot(
        id: json['id'] as String,
        placeKey: json['placeKey'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        description: json['description'] as String?,
        address: json['address'] as String?,
        businessHours: json['businessHours'] as String?,
        contactInfo: json['contactInfo'] as String?,
        accessTips: json['accessTips'] as String?,
        links: json['links'] as String?,
        coverLocalPath: json['coverLocalPath'] as String?,
        coverRemoteUrl: json['coverRemoteUrl'] as String?,
        source: json['source'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        area: json['area'] as String?,
        note: json['note'] as String?,
        addedBy: json['addedBy'] as String? ?? 'snapshot',
        labelIds: (json['labelIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      );
}

/// Snapshot of a schedule item assignment.
@immutable
class ScheduleItemSnapshot {
  final String id;
  final String stopId;
  final String dayId;
  final String sortKey;
  final int stayMinutes;
  final int transitMinutes;
  final int? fixedTime;
  final String status;

  const ScheduleItemSnapshot({
    required this.id,
    required this.stopId,
    required this.dayId,
    required this.sortKey,
    this.stayMinutes = 60,
    this.transitMinutes = 0,
    this.fixedTime,
    this.status = 'planned',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'stopId': stopId,
        'dayId': dayId,
        'sortKey': sortKey,
        'stayMinutes': stayMinutes,
        'transitMinutes': transitMinutes,
        'fixedTime': fixedTime,
        'status': status,
      };

  factory ScheduleItemSnapshot.fromJson(Map<String, dynamic> json) => ScheduleItemSnapshot(
        id: json['id'] as String,
        stopId: json['stopId'] as String,
        dayId: json['dayId'] as String,
        sortKey: json['sortKey'] as String,
        stayMinutes: json['stayMinutes'] as int? ?? 60,
        transitMinutes: json['transitMinutes'] as int? ?? 0,
        fixedTime: json['fixedTime'] as int?,
        status: json['status'] as String? ?? 'planned',
      );
}

/// Complete immutable payload for a trip snapshot.
@immutable
class TripSnapshotPayload {
  final TripSnapshotMetadata metadata;
  final TripDataSnapshot trip;
  final List<TripDaySnapshot> days;
  final List<StopSnapshot> stops;
  final List<ScheduleItemSnapshot> scheduleItems;

  const TripSnapshotPayload({
    required this.metadata,
    required this.trip,
    required this.days,
    required this.stops,
    required this.scheduleItems,
  });

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'trip': trip.toJson(),
        'days': days.map((d) => d.toJson()).toList(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'scheduleItems': scheduleItems.map((i) => i.toJson()).toList(),
      };

  factory TripSnapshotPayload.fromJson(Map<String, dynamic> json) => TripSnapshotPayload(
        metadata: TripSnapshotMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
        trip: TripDataSnapshot.fromJson(json['trip'] as Map<String, dynamic>),
        days: (json['days'] as List<dynamic>).map((d) => TripDaySnapshot.fromJson(d as Map<String, dynamic>)).toList(),
        stops: (json['stops'] as List<dynamic>).map((s) => StopSnapshot.fromJson(s as Map<String, dynamic>)).toList(),
        scheduleItems: (json['scheduleItems'] as List<dynamic>)
            .map((i) => ScheduleItemSnapshot.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory TripSnapshotPayload.fromJsonString(String raw) =>
      TripSnapshotPayload.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Details of modifications to a stop between snapshot and current state.
@immutable
class StopDiffDetail {
  final String stopId;
  final String name;
  final List<String> changedFields;

  const StopDiffDetail({
    required this.stopId,
    required this.name,
    required this.changedFields,
  });
}

/// Details of schedule differences between snapshot and current state.
@immutable
class ScheduleDiffDetail {
  final String stopId;
  final String stopName;
  final String description;

  const ScheduleDiffDetail({
    required this.stopId,
    required this.stopName,
    required this.description,
  });
}

/// Detailed semantic diff report between a historical snapshot and current trip state.
@immutable
class SnapshotDiffReport {
  final String tripId;
  final String snapshotId;
  final String snapshotName;
  final List<String> addedStopNames;
  final List<String> removedStopNames;
  final List<StopDiffDetail> modifiedStops;
  final List<String> addedDayTitles;
  final List<String> removedDayTitles;
  final List<ScheduleDiffDetail> scheduleChanges;

  const SnapshotDiffReport({
    required this.tripId,
    required this.snapshotId,
    required this.snapshotName,
    this.addedStopNames = const [],
    this.removedStopNames = const [],
    this.modifiedStops = const [],
    this.addedDayTitles = const [],
    this.removedDayTitles = const [],
    this.scheduleChanges = const [],
  });

  bool get hasChanges =>
      addedStopNames.isNotEmpty ||
      removedStopNames.isNotEmpty ||
      modifiedStops.isNotEmpty ||
      addedDayTitles.isNotEmpty ||
      removedDayTitles.isNotEmpty ||
      scheduleChanges.isNotEmpty;
}

/// Result of rolling back a trip to a historical snapshot.
@immutable
class RollbackResult {
  final bool success;
  final String tripId;
  final String snapshotId;
  final int restoredDays;
  final int restoredStops;
  final int restoredScheduleItems;
  final String? backupSnapshotId;
  final String? error;

  const RollbackResult({
    required this.success,
    required this.tripId,
    required this.snapshotId,
    this.restoredDays = 0,
    this.restoredStops = 0,
    this.restoredScheduleItems = 0,
    this.backupSnapshotId,
    this.error,
  });
}
