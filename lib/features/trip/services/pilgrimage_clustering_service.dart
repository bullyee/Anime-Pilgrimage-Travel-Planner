import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/route_optimization_models.dart';
import 'geodesic_math.dart';

/// Service for grouping pilgrimage stops into walking-friendly geographic clusters
/// and auto-detecting pilgrimage areas (e.g. "Uji River Area", "Fushimi Inari Area").
class PilgrimageClusteringService {
  const PilgrimageClusteringService();

  /// Default walking cluster threshold (800 meters, ~10 min walk).
  static const double defaultClusterRadiusMeters = 800.0;

  /// Groups [stops] into geographic clusters based on walking proximity.
  ///
  /// Uses spatial connected-components clustering: stops within [maxDistanceMeters]
  /// of each other belong to the same cluster.
  List<StopCluster> clusterStops(
    List<Stop> stops, {
    double maxDistanceMeters = defaultClusterRadiusMeters,
  }) {
    if (stops.isEmpty) return const [];
    if (stops.length == 1) {
      final s = stops.first;
      return [
        StopCluster(
          clusterId: 'cluster_0',
          name: s.area?.isNotEmpty == true ? s.area! : '${s.name} 周邊',
          centerLat: s.lat,
          centerLng: s.lng,
          stops: [s],
          radiusMeters: 0.0,
        ),
      ];
    }

    final n = stops.length;
    final parent = List.generate(n, (i) => i);

    int find(int i) {
      if (parent[i] == i) return i;
      return parent[i] = find(parent[i]);
    }

    void union(int i, int j) {
      final rootI = find(i);
      final rootJ = find(j);
      if (rootI != rootJ) {
        parent[rootJ] = rootI;
      }
    }

    // Connect any stops within walking distance
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final dist = GeodesicMath.haversineDistance(
          stops[i].lat,
          stops[i].lng,
          stops[j].lat,
          stops[j].lng,
        );
        if (dist <= maxDistanceMeters) {
          union(i, j);
        }
      }
    }

    // Group stops by connected component root
    final componentMap = <int, List<Stop>>{};
    for (var i = 0; i < n; i++) {
      final root = find(i);
      componentMap.putIfAbsent(root, () => []).add(stops[i]);
    }

    final clusters = <StopCluster>[];
    var clusterIdx = 0;

    for (final memberStops in componentMap.values) {
      var sumLat = 0.0;
      var sumLng = 0.0;
      final areaVotes = <String, int>{};

      for (final s in memberStops) {
        sumLat += s.lat;
        sumLng += s.lng;
        if (s.area != null && s.area!.trim().isNotEmpty) {
          final trimmed = s.area!.trim();
          areaVotes[trimmed] = (areaVotes[trimmed] ?? 0) + 1;
        }
      }

      final cLat = sumLat / memberStops.length;
      final cLng = sumLng / memberStops.length;

      var maxRadius = 0.0;
      for (final s in memberStops) {
        final r = GeodesicMath.haversineDistance(cLat, cLng, s.lat, s.lng);
        if (r > maxRadius) maxRadius = r;
      }

      // Infer cluster name: most frequent explicit area, or top landmark name
      String clusterName;
      if (areaVotes.isNotEmpty) {
        final sortedAreas = areaVotes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        clusterName = sortedAreas.first.key;
      } else {
        clusterName = '${memberStops.first.name} 周邊';
      }

      clusters.add(StopCluster(
        clusterId: 'cluster_$clusterIdx',
        name: clusterName,
        centerLat: cLat,
        centerLng: cLng,
        stops: memberStops,
        radiusMeters: maxRadius,
      ));
      clusterIdx++;
    }

    // Sort clusters by number of stops descending
    clusters.sort((a, b) => b.stopCount.compareTo(a.stopCount));
    return clusters;
  }

  /// Automatically groups and populates `stops.area` for stops with missing area
  /// in [tripId] based on geographic clustering.
  ///
  /// Scoped by [tripId] and stop [id] to guarantee entity isolation (Rule 2).
  /// Sets `syncStatus = 1` and updates `updatedAt` for bidirectional sync.
  Future<int> autoAssignTripAreas({
    required AppDatabase db,
    required String tripId,
    double maxDistanceMeters = defaultClusterRadiusMeters,
  }) async {
    final query = db.select(db.stops)
      ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull());
    final stops = await query.get();
    if (stops.isEmpty) return 0;

    final clusters = clusterStops(stops, maxDistanceMeters: maxDistanceMeters);
    final now = DateTime.now();
    var updatedCount = 0;

    await db.transaction(() async {
      for (final cluster in clusters) {
        for (final stop in cluster.stops) {
          if (stop.area == null || stop.area!.trim().isEmpty) {
            final updateQuery = db.update(db.stops)
              ..where((tbl) =>
                  tbl.id.equals(stop.id) & tbl.tripId.equals(tripId));
            await updateQuery.write(StopsCompanion(
              area: Value(cluster.name),
              updatedAt: Value(now),
              syncStatus: const Value(1),
            ));
            updatedCount++;
          }
        }
      }
    });

    return updatedCount;
  }
}
