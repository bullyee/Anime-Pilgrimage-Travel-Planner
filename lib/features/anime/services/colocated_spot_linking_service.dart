import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/colocated_spot_models.dart';
import 'geohash_helper.dart';

/// Service that discovers and links co-located pilgrimage spots across different anime works
/// using spatial grid bucketing and geodesic distance clustering.
class ColocatedSpotLinkingService {
  const ColocatedSpotLinkingService();

  /// Groups [spots] within [radiusMeters] into physical landmark clusters and identifies
  /// multi-anime shared pilgrimage hubs.
  CrossAnimeLinkResult findColocatedHubs({
    required List<ColocatedSpotItem> spots,
    double radiusMeters = 35.0,
  }) {
    if (spots.isEmpty) {
      return const CrossAnimeLinkResult(
        hubs: [],
        allGroups: [],
        coLocatedMap: {},
      );
    }

    // 1. Build spatial grid index
    final grid = <String, List<ColocatedSpotItem>>{};
    for (final spot in spots) {
      final cell = GeohashHelper.gridCell(
        spot.lat,
        spot.lng,
        cellSizeMeters: radiusMeters,
      );
      final key = '${cell.row}:${cell.col}';
      (grid[key] ??= []).add(spot);
    }

    // 2. Clustering via Connected Components (BFS over spatial neighborhood)
    final visited = <String>{};
    final allGroups = <ColocatedSpotGroup>[];
    final coLocatedMap = <String, List<ColocatedSpotItem>>{};

    for (final spot in spots) {
      if (visited.contains(spot.spotId)) continue;

      final clusterSpots = <ColocatedSpotItem>[];
      final queue = <ColocatedSpotItem>[spot];
      visited.add(spot.spotId);

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        clusterSpots.add(current);

        // Find candidate spots in neighboring grid cells
        final neighborKeys = GeohashHelper.neighborGridKeys(
          current.lat,
          current.lng,
          cellSizeMeters: radiusMeters,
        );

        for (final nKey in neighborKeys) {
          final bucket = grid[nKey];
          if (bucket == null) continue;

          for (final candidate in bucket) {
            if (visited.contains(candidate.spotId)) continue;

            final dist = _haversineDistance(
              current.lat,
              current.lng,
              candidate.lat,
              candidate.lng,
            );

            if (dist <= radiusMeters) {
              visited.add(candidate.spotId);
              queue.add(candidate);
            }
          }
        }
      }

      // 3. Compute cluster centroid and attributes
      final count = clusterSpots.length;
      var sumLat = 0.0;
      var sumLng = 0.0;
      for (final s in clusterSpots) {
        sumLat += s.lat;
        sumLng += s.lng;
      }
      final centroidLat = sumLat / count;
      final centroidLng = sumLng / count;

      // Calculate distances to centroid and cluster max span
      var maxDist = 0.0;
      final enrichedSpots = <ColocatedSpotItem>[];
      final animeTitles = <String>{};

      for (final s in clusterSpots) {
        final dToCentroid = _haversineDistance(
          s.lat,
          s.lng,
          centroidLat,
          centroidLng,
        );
        if (dToCentroid > maxDist) maxDist = dToCentroid;
        enrichedSpots.add(s.copyWith(distanceToCentroidMeters: dToCentroid));
        if (s.animeTitle.isNotEmpty) {
          animeTitles.add(s.animeTitle);
        }
      }

      final geohash = GeohashHelper.encode(
        centroidLat,
        centroidLng,
        precision: 8,
      );

      // Primary name: pick shortest name or most recurring name in cluster
      final primaryName = _pickPrimaryName(enrichedSpots);

      final group = ColocatedSpotGroup(
        id: 'colocated_$geohash',
        primaryName: primaryName,
        centroidLat: centroidLat,
        centroidLng: centroidLng,
        spots: enrichedSpots,
        animeTitles: animeTitles,
        maxDistanceMeters: maxDist * 2,
        geohash: geohash,
      );

      allGroups.add(group);

      // 4. Build cross-anime lookup mapping
      for (final s in enrichedSpots) {
        final otherAnimeSpots = enrichedSpots
            .where((other) =>
                other.spotId != s.spotId && other.animeTitle != s.animeTitle)
            .toList();
        if (otherAnimeSpots.isNotEmpty) {
          coLocatedMap[s.spotId] = otherAnimeSpots;
        }
      }
    }

    // 5. Separate multi-anime hubs (at least 2 different anime works)
    final hubs = allGroups.where((g) => g.isMultiAnime).toList()
      ..sort((a, b) {
        final c = b.animeCount.compareTo(a.animeCount);
        if (c != 0) return c;
        return b.spots.length.compareTo(a.spots.length);
      });

    return CrossAnimeLinkResult(
      hubs: hubs,
      allGroups: allGroups,
      coLocatedMap: coLocatedMap,
    );
  }

  /// Finds other anime scenes located near a specific [target] spot.
  List<ColocatedSpotItem> findNearbyCrossAnimeSpots(
    ColocatedSpotItem target,
    List<ColocatedSpotItem> candidates, {
    double radiusMeters = 50.0,
  }) {
    final results = <ColocatedSpotItem>[];
    for (final c in candidates) {
      if (c.spotId == target.spotId) continue;
      if (c.animeTitle == target.animeTitle) continue;

      final dist = _haversineDistance(target.lat, target.lng, c.lat, c.lng);
      if (dist <= radiusMeters) {
        results.add(c.copyWith(distanceToCentroidMeters: dist));
      }
    }

    results.sort((a, b) => (a.distanceToCentroidMeters ?? 0)
        .compareTo(b.distanceToCentroidMeters ?? 0));
    return results;
  }

  /// Discovers co-located multi-anime hubs across all places in the personal library.
  Future<CrossAnimeLinkResult> findLibraryColocatedHubs(
    AppDatabase db, {
    double radiusMeters = 35.0,
  }) async {
    // Query places joined with placeLabels and labels of kind == 'anime'
    final query = db.select(db.places).join([
      leftOuterJoin(
        db.placeLabels,
        db.placeLabels.placeKey.equalsExp(db.places.placeKey),
      ),
      leftOuterJoin(
        db.labels,
        db.labels.id.equalsExp(db.placeLabels.labelId) &
            db.labels.kind.equals('anime'),
      ),
    ]);

    final rows = await query.get();
    final spots = <ColocatedSpotItem>[];

    for (final row in rows) {
      final place = row.readTable(db.places);
      final label = row.readTableOrNull(db.labels);

      spots.add(
        ColocatedSpotItem(
          spotId: place.placeKey,
          placeKey: place.placeKey,
          name: place.name,
          animeTitle: label?.name ?? 'Unknown Anime',
          bangumiId: label?.bangumiId,
          lat: place.lat,
          lng: place.lng,
          coverUrl: place.coverRemoteUrl ?? place.coverLocalPath,
          sceneDescription: place.description,
        ),
      );
    }

    return findColocatedHubs(spots: spots, radiusMeters: radiusMeters);
  }

  /// Discovers co-located multi-anime hubs across stops within a specific [tripId].
  Future<CrossAnimeLinkResult> findTripColocatedHubs(
    AppDatabase db,
    String tripId, {
    double radiusMeters = 35.0,
  }) async {
    // Entity Scope Isolation: filter stops strictly by tripId
    final query = (db.select(db.stops)..where((tbl) => tbl.tripId.equals(tripId)))
        .join([
      leftOuterJoin(
        db.stopLabels,
        db.stopLabels.stopId.equalsExp(db.stops.id),
      ),
      leftOuterJoin(
        db.labels,
        db.labels.id.equalsExp(db.stopLabels.labelId) &
            db.labels.kind.equals('anime'),
      ),
    ]);

    final rows = await query.get();
    final spots = <ColocatedSpotItem>[];

    for (final row in rows) {
      final stop = row.readTable(db.stops);
      final label = row.readTableOrNull(db.labels);

      spots.add(
        ColocatedSpotItem(
          spotId: stop.id,
          placeKey: stop.placeKey,
          name: stop.name,
          animeTitle: label?.name ?? 'Unknown Anime',
          bangumiId: label?.bangumiId,
          lat: stop.lat,
          lng: stop.lng,
          coverUrl: stop.coverRemoteUrl ?? stop.coverLocalPath,
          sceneDescription: stop.description,
        ),
      );
    }

    return findColocatedHubs(spots: spots, radiusMeters: radiusMeters);
  }

  /// Calculates geodesic distance between two points in meters using the Haversine formula.
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Picks the most descriptive name among a list of clustered spots.
  static String _pickPrimaryName(List<ColocatedSpotItem> spots) {
    if (spots.isEmpty) return 'Landmark';
    // Frequency count of base names
    final counts = <String, int>{};
    for (final s in spots) {
      counts[s.name] = (counts[s.name] ?? 0) + 1;
    }
    // Return most frequent name, breaking ties with shortest name
    var bestName = spots.first.name;
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount ||
          (entry.value == bestCount && entry.key.length < bestName.length)) {
        bestName = entry.key;
        bestCount = entry.value;
      }
    }
    return bestName;
  }
}
