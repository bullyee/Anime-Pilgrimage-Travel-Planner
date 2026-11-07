import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/pilgrimage_stats_models.dart';

/// Service that computes objective quantitative pilgrimage completion metrics,
/// anime-by-anime progress tracking, and trip execution statistics.
class PilgrimageAnalyticsService {
  const PilgrimageAnalyticsService();

  static const List<String> _jpPrefectures = [
    '京都', '滋賀', '東京', '埼玉', '神奈川', '岐阜', '静岡', '長野',
    '兵庫', '大阪', '奈良', '愛知', '千葉', '茨城', '栃木', '群馬',
    '広島', '福岡', '北海道', '沖縄', '富山', '石川', '福井', '山梨',
    '鳥取', '島根', '岡山', '山口', '徳島', '香川', '愛媛', '高知',
    '佐賀', '長崎', '熊本', '大分', '宮崎', '鹿児島', '青森', '岩手',
    '宮城', '秋田', '山形', '福島', '新潟', '三重', '和歌山'
  ];

  /// Compiles comprehensive statistics for the user's entire saved library.
  Future<OverallPilgrimageSummary> getLibrarySummary(AppDatabase db) async {
    // 1. Fetch saved places
    final places = await (db.select(db.places)
          ..where((tbl) => tbl.visibility.equals('saved')))
        .get();

    if (places.isEmpty) {
      return const OverallPilgrimageSummary(
        totalDistinctAnime: 0,
        totalPlaces: 0,
        totalVisitedPlaces: 0,
        totalPhotosTaken: 0,
        animeStats: [],
        regionStats: [],
      );
    }

    final placeKeys = places.map((p) => p.placeKey).toSet();

    // 2. Fetch photos to identify visited places and photo counts
    final photos = await (db.select(db.photos)
          ..where((tbl) => tbl.placeKey.isIn(placeKeys)))
        .get();

    final photosPerPlace = <String, int>{};
    final visitedPlaceKeys = <String>{};
    for (final photo in photos) {
      photosPerPlace[photo.placeKey] = (photosPerPlace[photo.placeKey] ?? 0) + 1;
      visitedPlaceKeys.add(photo.placeKey);
    }

    // 3. Fetch anime labels and region labels
    final placeLabelsQuery = (db.select(db.placeLabels)
          ..where((tbl) => tbl.placeKey.isIn(placeKeys)))
        .join([
      innerJoin(
        db.labels,
        db.labels.id.equalsExp(db.placeLabels.labelId),
      ),
    ]);

    final labelRows = await placeLabelsQuery.get();
    final animeLabelsByPlace = <String, List<Label>>{};
    final regionLabelsByPlace = <String, List<Label>>{};

    for (final row in labelRows) {
      final placeLabel = row.readTable(db.placeLabels);
      final label = row.readTable(db.labels);

      if (label.kind == 'anime') {
        (animeLabelsByPlace[placeLabel.placeKey] ??= []).add(label);
      } else if (label.kind == 'region') {
        (regionLabelsByPlace[placeLabel.placeKey] ??= []).add(label);
      }
    }

    // 4. Compute per-anime statistics
    final animeBuckets = <String, ({Label label, List<Place> places})>{};
    for (final place in places) {
      final animeList = animeLabelsByPlace[place.placeKey] ?? [];
      for (final anime in animeList) {
        final bucket = animeBuckets[anime.id];
        if (bucket == null) {
          animeBuckets[anime.id] = (label: anime, places: [place]);
        } else {
          bucket.places.add(place);
        }
      }
    }

    final animeStats = <AnimeCompletionStat>[];
    for (final bucket in animeBuckets.values) {
      final anime = bucket.label;
      final animePlaces = bucket.places;

      var visitedCount = 0;
      var photoCount = 0;
      final unvisitedKeys = <String>[];

      for (final p in animePlaces) {
        if (visitedPlaceKeys.contains(p.placeKey)) {
          visitedCount++;
          photoCount += photosPerPlace[p.placeKey] ?? 0;
        } else {
          unvisitedKeys.add(p.placeKey);
        }
      }

      animeStats.add(
        AnimeCompletionStat(
          animeLabelId: anime.id,
          animeTitle: anime.name,
          bangumiId: anime.bangumiId,
          totalSpotCount: animePlaces.length,
          visitedSpotCount: visitedCount,
          photoCount: photoCount,
          unvisitedPlaceKeys: unvisitedKeys,
        ),
      );
    }
    animeStats.sort((a, b) => b.totalSpotCount.compareTo(a.totalSpotCount));

    // 5. Compute per-region statistics
    final regionBuckets = <String, List<Place>>{};
    for (final place in places) {
      final regionLabel = regionLabelsByPlace[place.placeKey]?.firstOrNull;
      final regionName = regionLabel?.name ?? _detectRegion(place.address) ?? 'Other';
      (regionBuckets[regionName] ??= []).add(place);
    }

    final regionStats = <RegionCompletionStat>[];
    for (final entry in regionBuckets.entries) {
      final rPlaces = entry.value;
      final visitedCount = rPlaces.where((p) => visitedPlaceKeys.contains(p.placeKey)).length;
      regionStats.add(
        RegionCompletionStat(
          regionName: entry.key,
          totalSpotCount: rPlaces.length,
          visitedSpotCount: visitedCount,
        ),
      );
    }
    regionStats.sort((a, b) => b.totalSpotCount.compareTo(a.totalSpotCount));

    return OverallPilgrimageSummary(
      totalDistinctAnime: animeStats.length,
      totalPlaces: places.length,
      totalVisitedPlaces: visitedPlaceKeys.length,
      totalPhotosTaken: photos.length,
      animeStats: animeStats,
      regionStats: regionStats,
    );
  }

  /// Evaluates detailed completion metrics for a single anime work by its [animeLabelId].
  Future<AnimeCompletionStat?> getAnimeCompletion(
    AppDatabase db,
    String animeLabelId,
  ) async {
    final label = await (db.select(db.labels)
          ..where((tbl) => tbl.id.equals(animeLabelId) & tbl.kind.equals('anime')))
        .getSingleOrNull();

    if (label == null) return null;

    final placeKeysQuery = db.select(db.placeLabels)
      ..where((tbl) => tbl.labelId.equals(animeLabelId));
    final placeLabelRows = await placeKeysQuery.get();
    final placeKeys = placeLabelRows.map((r) => r.placeKey).toSet();

    if (placeKeys.isEmpty) {
      return AnimeCompletionStat(
        animeLabelId: label.id,
        animeTitle: label.name,
        bangumiId: label.bangumiId,
        totalSpotCount: 0,
        visitedSpotCount: 0,
        photoCount: 0,
        unvisitedPlaceKeys: const [],
      );
    }

    final photos = await (db.select(db.photos)
          ..where((tbl) => tbl.placeKey.isIn(placeKeys)))
        .get();

    final visitedKeys = photos.map((p) => p.placeKey).toSet();
    final unvisited = placeKeys.difference(visitedKeys).toList();

    return AnimeCompletionStat(
      animeLabelId: label.id,
      animeTitle: label.name,
      bangumiId: label.bangumiId,
      totalSpotCount: placeKeys.length,
      visitedSpotCount: visitedKeys.length,
      photoCount: photos.length,
      unvisitedPlaceKeys: unvisited,
    );
  }

  /// Evaluates completion and execution metrics for a trip by [tripId].
  Future<TripCompletionStat> getTripCompletion(
    AppDatabase db,
    String tripId,
  ) async {
    // Entity Scope Isolation: query trip strictly by tripId
    final trip = await (db.select(db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
    final tripTitle = trip?.title ?? 'Trip';

    final stops = await (db.select(db.stops)..where((tbl) => tbl.tripId.equals(tripId))).get();
    final items = await (db.select(db.scheduleItems)..where((tbl) => tbl.tripId.equals(tripId))).get();
    final photos = await (db.select(db.photos)..where((tbl) => tbl.tripId.equals(tripId))).get();

    var plannedCount = 0;
    var doneCount = 0;
    var skippedCount = 0;

    for (final item in items) {
      switch (item.status) {
        case 'done':
          doneCount++;
          break;
        case 'skipped':
          skippedCount++;
          break;
        default:
          plannedCount++;
          break;
      }
    }

    return TripCompletionStat(
      tripId: tripId,
      tripTitle: tripTitle,
      totalStops: stops.length,
      plannedStops: plannedCount,
      doneStops: doneCount,
      skippedStops: skippedCount,
      photoCount: photos.length,
    );
  }

  static String? _detectRegion(String? address) {
    if (address == null || address.isEmpty) return null;
    for (final pref in _jpPrefectures) {
      if (address.contains(pref)) {
        return pref;
      }
    }
    return null;
  }
}
