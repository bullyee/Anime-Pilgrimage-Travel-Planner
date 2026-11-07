import 'package:flutter/foundation.dart';

/// A pair of real pilgrimage photo and original anime reference frame.
@immutable
class TraveloguePhotoItem {
  final String? userPhotoPath;
  final String? refImageLocalPath;
  final String? refImageRemoteUrl;
  final String? episode;
  final String? caption;

  const TraveloguePhotoItem({
    this.userPhotoPath,
    this.refImageLocalPath,
    this.refImageRemoteUrl,
    this.episode,
    this.caption,
  });

  bool get hasAnyImage =>
      userPhotoPath != null || refImageLocalPath != null || refImageRemoteUrl != null;
}

/// A documented pilgrimage stop in the travelogue timeline.
@immutable
class TravelogueStopEntry {
  final String stopId;
  final String placeKey;
  final String name;
  final double lat;
  final double lng;
  final String? animeTitle;
  final String? description;
  final String? accessTips;
  final String? note;
  final String? visitDate;
  final DateTime? visitedAt;
  final int stayMinutes;
  final String status;
  final List<TraveloguePhotoItem> photos;

  const TravelogueStopEntry({
    required this.stopId,
    required this.placeKey,
    required this.name,
    required this.lat,
    required this.lng,
    this.animeTitle,
    this.description,
    this.accessTips,
    this.note,
    this.visitDate,
    this.visitedAt,
    this.stayMinutes = 60,
    this.status = 'planned',
    this.photos = const [],
  });

  bool get isCompleted => status == 'done' || visitedAt != null || visitDate != null;

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}

/// A day section within the travelogue report.
@immutable
class TravelogueDaySection {
  final String dayId;
  final String title;
  final String? pinnedDate;
  final List<TravelogueStopEntry> stops;
  final double? walkingDistanceMeters;
  final double? elevationGainMeters;

  const TravelogueDaySection({
    required this.dayId,
    required this.title,
    this.pinnedDate,
    required this.stops,
    this.walkingDistanceMeters,
    this.elevationGainMeters,
  });

  int get completedCount => stops.where((s) => s.isCompleted).length;
}

/// Complete compiled travelogue document for a trip.
@immutable
class TravelogueDocument {
  final String tripId;
  final String title;
  final String? description;
  final String? author;
  final String? startDate;
  final DateTime generatedAt;
  final List<String> animeTitles;
  final int totalStops;
  final int completedStops;
  final List<TravelogueDaySection> days;

  const TravelogueDocument({
    required this.tripId,
    required this.title,
    this.description,
    this.author,
    this.startDate,
    required this.generatedAt,
    required this.animeTitles,
    required this.totalStops,
    required this.completedStops,
    required this.days,
  });

  double get completionRate =>
      totalStops > 0 ? (completedStops / totalStops) : 0.0;

  String get completionRatePercentage =>
      '${(completionRate * 100).toStringAsFixed(1)}%';
}
