import 'package:flutter/foundation.dart';

import '../../../core/database/database.dart';

/// A candidate pilgrimage place nearby the user's current GPS position (within ~150m).
@immutable
class NearbyShootingPlace {
  final Place place;
  final double distanceMeters;
  final bool isTodayStop;
  final Stop? todayStop;
  final ScheduleItem? todayScheduleItem;
  final List<NewReferenceImage> referenceFrames;
  final String? animeTitle;

  const NearbyShootingPlace({
    required this.place,
    required this.distanceMeters,
    this.isTodayStop = false,
    this.todayStop,
    this.todayScheduleItem,
    this.referenceFrames = const [],
    this.animeTitle,
  });

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
