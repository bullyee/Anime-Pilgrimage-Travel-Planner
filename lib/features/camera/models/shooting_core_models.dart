import 'package:flutter/foundation.dart';

import '../../../core/database/database.dart';

/// Orientation and relative directional guidance toward a pilgrimage spot.
@immutable
class SpotBearingInfo {
  /// Straight-line distance in meters.
  final double distanceMeters;

  /// True North bearing angle in degrees (0.0 to 359.9).
  final double bearingDegrees;

  /// 8-point cardinal abbreviation: 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'.
  final String cardinal;

  /// Localized cardinal name: '北', '東北', '東', '東南', '南', '西南', '西', '西北'.
  final String cardinalZh;

  /// Clock position relative to device heading (1 to 12), or null if heading unknown.
  final int? clockHour;

  /// Relative angle in degrees (0.0 to 359.9) from current heading, or null if heading unknown.
  final double? relativeAngleDegrees;

  /// True when the user is within arrival threshold (default <= 15 meters).
  final bool isArrived;

  const SpotBearingInfo({
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.cardinal,
    required this.cardinalZh,
    this.clockHour,
    this.relativeAngleDegrees,
    this.isArrived = false,
  });

  /// Human-friendly description e.g. "NE 45m" or "2 o'clock · 45m", with km past 1000m.
  String description({bool preferClock = true}) {
    final String distText;
    if (distanceMeters < 10) {
      distText = '${distanceMeters.toStringAsFixed(1)}m';
    } else if (distanceMeters < 1000) {
      distText = '${distanceMeters.round()}m';
    } else {
      final km = distanceMeters / 1000.0;
      distText = km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km';
    }

    if (isArrived) {
      return 'Arrived ($distText)';
    }
    if (preferClock && clockHour != null) {
      return "$clockHour o'clock · $distText";
    }
    return '$cardinal $distText';
  }
}

/// A candidate pilgrimage place nearby the user's current GPS position (within ~150m).
@immutable
class NearbyShootingPlace {
  final Place? place;
  final String? _name;
  final double? _lat;
  final double? _lng;
  final String? _placeKey;
  final double distanceMeters;
  final bool isTargetDayStop;
  final Stop? todayStop;
  final ScheduleItem? todayScheduleItem;
  final String? dayId;
  final int? dayNumber;
  final List<NewReferenceImage> referenceFrames;
  final String? animeTitle;
  final SpotBearingInfo? bearingInfo;

  const NearbyShootingPlace({
    this.place,
    String? name,
    double? lat,
    double? lng,
    String? placeKey,
    required this.distanceMeters,
    bool isTodayStop = false,
    bool? isTargetDayStop,
    this.todayStop,
    this.todayScheduleItem,
    this.dayId,
    this.dayNumber,
    this.referenceFrames = const [],
    this.animeTitle,
    this.bearingInfo,
  })  : isTargetDayStop = isTargetDayStop ?? isTodayStop,
        _name = name,
        _lat = lat,
        _lng = lng,
        _placeKey = placeKey;

  bool get isTodayStop => isTargetDayStop;
  String get name => _name ?? place?.name ?? todayStop?.name ?? '';
  double get lat => _lat ?? place?.lat ?? todayStop?.lat ?? 0.0;
  double get lng => _lng ?? place?.lng ?? todayStop?.lng ?? 0.0;
  String get placeKey => _placeKey ?? place?.placeKey ?? todayStop?.placeKey ?? '';

  /// Primary reference frame (first one available) for floating camera viewfinder.
  NewReferenceImage? get primaryFrame =>
      referenceFrames.isNotEmpty ? referenceFrames.first : null;
}

/// Resolved active trip and day block for today's calendar date.
@immutable
class TodayTripInfo {
  final Trip trip;
  final TripDay day;
  final List<Stop> stops;
  final List<ScheduleItem> scheduleItems;
  final Map<String, Stop> stopMap;

  const TodayTripInfo({
    required this.trip,
    required this.day,
    required this.stops,
    required this.scheduleItems,
    required this.stopMap,
  });

  int get completedCount =>
      scheduleItems.where((i) => i.status == 'done').length;

  int get totalCount => scheduleItems.length;

  double get progress => totalCount > 0 ? (completedCount / totalCount) : 0.0;
}

/// Result returned after capturing and recording a shot in the field.
@immutable
class ShotRecordResult {
  final Photo photo;
  final PlaceVisit visit;
  final Stop? stop;
  final ScheduleItem? scheduleItem;
  final bool wasOffPlan;

  const ShotRecordResult({
    required this.photo,
    required this.visit,
    this.stop,
    this.scheduleItem,
    required this.wasOffPlan,
  });
}

/// Result returned after checking in at a pilgrimage spot without a photo.
@immutable
class CheckInResult {
  final PlaceVisit visit;
  final Stop? stop;
  final ScheduleItem? scheduleItem;
  final bool wasOffPlan;

  const CheckInResult({
    required this.visit,
    this.stop,
    this.scheduleItem,
    required this.wasOffPlan,
  });
}

/// A fully hydrated stop node on today's active pilgrimage route.
@immutable
class LivePilgrimageStop {
  /// The schedule item defining the order and status ('planned', 'done', 'skipped').
  final ScheduleItem scheduleItem;

  /// The stop definition containing trip-level notes and coordinates.
  final Stop stop;

  /// The underlying library place facts (if linked).
  final Place? place;

  /// Reference anime frames for camera overlay and comparison.
  final List<NewReferenceImage> referenceFrames;

  /// Anime title from labels.
  final String? animeTitle;

  /// Real-time distance and orientation from current GPS position (if coordinates known).
  final SpotBearingInfo? bearingInfo;

  /// Whether this is the immediate next pending target on the itinerary.
  final bool isNextTarget;

  /// Whether this is the geographically closest stop to the user's current GPS position.
  final bool isNearest;

  const LivePilgrimageStop({
    required this.scheduleItem,
    required this.stop,
    this.place,
    this.referenceFrames = const [],
    this.animeTitle,
    this.bearingInfo,
    this.isNextTarget = false,
    this.isNearest = false,
  });

  /// Primary reference frame (first one available) for floating camera viewfinder.
  NewReferenceImage? get primaryFrame =>
      referenceFrames.isNotEmpty ? referenceFrames.first : null;

  /// Status convenience getters.
  bool get isDone => scheduleItem.status == 'done';
  bool get isSkipped => scheduleItem.status == 'skipped';
  bool get isPlanned => scheduleItem.status == 'planned';
}

/// Complete live state of today's pilgrimage route for in-situ navigation.
@immutable
class TodayPilgrimageFeed {
  final Trip trip;
  final TripDay day;
  final List<LivePilgrimageStop> stops;

  const TodayPilgrimageFeed({
    required this.trip,
    required this.day,
    required this.stops,
  });

  /// Number of completed stops.
  int get completedCount => stops.where((s) => s.isDone).length;

  /// Number of skipped stops.
  int get skippedCount => stops.where((s) => s.isSkipped).length;

  /// Total stops planned for today.
  int get totalCount => stops.length;

  /// Completion progress ratio (0.0 to 1.0).
  double get progress => totalCount > 0 ? (completedCount / totalCount) : 0.0;

  /// The next pending stop on the day's route, or null if all are done/skipped.
  LivePilgrimageStop? get nextTarget =>
      stops.where((s) => s.isPlanned).firstOrNull;

  /// The geographically closest stop to current GPS location, or null if no coordinates available.
  LivePilgrimageStop? get nearestStop =>
      stops.where((s) => s.isNearest).firstOrNull;
}

/// Generic alias for pilgrimage route feed across any day.
typedef PilgrimageFeed = TodayPilgrimageFeed;

/// A photo in the "Photos to edit" inbox waiting for post-pilgrimage editing at home.
@immutable
class PhotoToEditItem {
  final Photo photo;
  final Place? place;
  final NewReferenceImage? referenceFrame;

  const PhotoToEditItem({
    required this.photo,
    this.place,
    this.referenceFrame,
  });
}
