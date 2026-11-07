/// Quantitative pilgrimage progress statistics for a specific anime work.
class AnimeCompletionStat {
  final String animeLabelId;
  final String animeTitle;
  final String? bangumiId;
  final int totalSpotCount;
  final int visitedSpotCount;
  final int photoCount;
  final List<String> unvisitedPlaceKeys;

  const AnimeCompletionStat({
    required this.animeLabelId,
    required this.animeTitle,
    this.bangumiId,
    required this.totalSpotCount,
    required this.visitedSpotCount,
    required this.photoCount,
    this.unvisitedPlaceKeys = const [],
  });

  /// Ratio of visited spots to total spots in this anime (0.0 to 1.0).
  double get completionRatio =>
      totalSpotCount > 0 ? visitedSpotCount / totalSpotCount : 0.0;

  /// Percentage of visited spots (0.0% to 100.0%).
  double get completionPercentage =>
      double.parse((completionRatio * 100.0).toStringAsFixed(1));

  /// True if every holy ground / spot in this anime has been visited.
  bool get isCompleted =>
      totalSpotCount > 0 && visitedSpotCount >= totalSpotCount;

  @override
  String toString() =>
      'AnimeCompletionStat($animeTitle, $visitedSpotCount/$totalSpotCount ($completionPercentage%), photos: $photoCount)';
}

/// Pilgrimage progress statistics aggregated across a geographic region or prefecture.
class RegionCompletionStat {
  final String regionName;
  final int totalSpotCount;
  final int visitedSpotCount;

  const RegionCompletionStat({
    required this.regionName,
    required this.totalSpotCount,
    required this.visitedSpotCount,
  });

  double get completionRatio =>
      totalSpotCount > 0 ? visitedSpotCount / totalSpotCount : 0.0;

  double get completionPercentage =>
      double.parse((completionRatio * 100.0).toStringAsFixed(1));

  @override
  String toString() =>
      'RegionCompletionStat($regionName: $visitedSpotCount/$totalSpotCount ($completionPercentage%))';
}

/// Completion and execution status for an active or past trip itinerary.
class TripCompletionStat {
  final String tripId;
  final String tripTitle;
  final int totalStops;
  final int plannedStops;
  final int doneStops;
  final int skippedStops;
  final int photoCount;

  const TripCompletionStat({
    required this.tripId,
    required this.tripTitle,
    required this.totalStops,
    required this.plannedStops,
    required this.doneStops,
    required this.skippedStops,
    required this.photoCount,
  });

  double get completionRatio =>
      totalStops > 0 ? doneStops / totalStops : 0.0;

  double get completionPercentage =>
      double.parse((completionRatio * 100.0).toStringAsFixed(1));

  @override
  String toString() =>
      'TripCompletionStat($tripTitle, done: $doneStops/$totalStops ($completionPercentage%), photos: $photoCount)';
}

/// Overall high-level dashboard metrics for the traveler's personal pilgrimage library.
class OverallPilgrimageSummary {
  final int totalDistinctAnime;
  final int totalPlaces;
  final int totalVisitedPlaces;
  final int totalPhotosTaken;
  final List<AnimeCompletionStat> animeStats;
  final List<RegionCompletionStat> regionStats;

  const OverallPilgrimageSummary({
    required this.totalDistinctAnime,
    required this.totalPlaces,
    required this.totalVisitedPlaces,
    required this.totalPhotosTaken,
    required this.animeStats,
    required this.regionStats,
  });

  double get overallCompletionRatio =>
      totalPlaces > 0 ? totalVisitedPlaces / totalPlaces : 0.0;

  double get overallCompletionPercentage =>
      double.parse((overallCompletionRatio * 100.0).toStringAsFixed(1));

  @override
  String toString() =>
      'OverallPilgrimageSummary(anime: $totalDistinctAnime, places: $totalVisitedPlaces/$totalPlaces ($overallCompletionPercentage%), photos: $totalPhotosTaken)';
}
