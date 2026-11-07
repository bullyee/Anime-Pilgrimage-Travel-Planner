import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../models/route_optimization_models.dart';
import 'geodesic_math.dart';

/// Service for optimizing pilgrimage visit sequences (Traveling Salesperson Problem / 2-Opt)
/// and computing walking legs and transit times.
class RouteOptimizationService {
  const RouteOptimizationService();

  /// Optimizes the visitation order of [stops] to minimize total travel distance.
  ///
  /// - If [startStopId] is provided, the route always begins at that stop.
  /// - If [endStopId] is provided, the route always concludes at that stop.
  /// - For small inputs (<= 8 stops), runs an exact branch-and-bound solver for the global optimum.
  /// - For larger inputs (> 8 stops), uses Nearest-Neighbor initialization followed by 2-Opt edge improvement.
  RouteOptimizationResult optimizeRoute(
    List<Stop> stops, {
    String? startStopId,
    String? endStopId,
  }) {
    if (stops.isEmpty) {
      return const RouteOptimizationResult(
        orderedStopIds: [],
        orderedStops: [],
        legs: [],
        totalDistanceMeters: 0.0,
        totalEstimatedWalkingMinutes: 0,
        originalDistanceMeters: 0.0,
        savedDistanceMeters: 0.0,
        savedDistancePercentage: 0.0,
      );
    }

    if (stops.length == 1) {
      final s = stops.first;
      return RouteOptimizationResult(
        orderedStopIds: [s.id],
        orderedStops: [s],
        legs: const [],
        totalDistanceMeters: 0.0,
        totalEstimatedWalkingMinutes: 0,
        originalDistanceMeters: 0.0,
        savedDistanceMeters: 0.0,
        savedDistancePercentage: 0.0,
      );
    }

    final n = stops.length;

    // Calculate baseline original distance
    final originalDistance = GeodesicMath.totalRouteDistance(
      stops.map((s) => (lat: s.lat, lng: s.lng)).toList(),
    );

    // Build distance matrix
    final matrix = GeodesicMath.computeDistanceMatrix(
      stops.map((s) => (lat: s.lat, lng: s.lng)).toList(),
    );

    // Identify start/end indices if constrained
    int? startIdx;
    int? endIdx;
    for (var i = 0; i < n; i++) {
      if (stops[i].id == startStopId) startIdx = i;
      if (stops[i].id == endStopId) endIdx = i;
    }

    List<int> bestTour;
    if (n <= 8) {
      bestTour = _solveTspExact(matrix, startIdx, endIdx);
    } else {
      bestTour = _solveTsp2Opt(matrix, startIdx, endIdx);
    }

    final orderedStops = bestTour.map((i) => stops[i]).toList();
    final orderedStopIds = orderedStops.map((s) => s.id).toList();

    // Compute legs
    final legs = <RouteLeg>[];
    var totalDistance = 0.0;
    var totalWalkingMinutes = 0;

    for (var i = 0; i < orderedStops.length - 1; i++) {
      final from = orderedStops[i];
      final to = orderedStops[i + 1];

      final dist = GeodesicMath.haversineDistance(from.lat, from.lng, to.lat, to.lng);
      final walkMin = GeodesicMath.estimateWalkingMinutes(dist);
      final bearing = GeodesicMath.bearingDegrees(from.lat, from.lng, to.lat, to.lng);
      final compass = GeodesicMath.bearingToCompass(bearing);

      totalDistance += dist;
      totalWalkingMinutes += walkMin;

      legs.add(RouteLeg(
        fromStopId: from.id,
        fromStopName: from.name,
        toStopId: to.id,
        toStopName: to.name,
        distanceMeters: dist,
        estimatedWalkingMinutes: walkMin,
        bearingCompass: compass,
      ));
    }

    final savedDistance = math.max(0.0, originalDistance - totalDistance);
    final savedPct = originalDistance > 0.0
        ? (savedDistance / originalDistance * 100.0)
        : 0.0;

    return RouteOptimizationResult(
      orderedStopIds: orderedStopIds,
      orderedStops: orderedStops,
      legs: legs,
      totalDistanceMeters: totalDistance,
      totalEstimatedWalkingMinutes: totalWalkingMinutes,
      originalDistanceMeters: originalDistance,
      savedDistanceMeters: savedDistance,
      savedDistancePercentage: savedPct,
    );
  }

  /// Applies the [orderedStopIds] to the schedule items of [dayId] in [tripId].
  ///
  /// Assigns freshly spaced fractional index keys and updates [transitMinutes]
  /// for each leg. Scoped by [tripId] to enforce entity isolation (Rule 2).
  Future<void> applyOptimizedOrderToDay({
    required AppDatabase db,
    required String tripId,
    required String dayId,
    required List<String> orderedStopIds,
  }) async {
    if (orderedStopIds.isEmpty) return;

    final scheduleQuery = db.select(db.scheduleItems)
      ..where((tbl) =>
          tbl.tripId.equals(tripId) &
          tbl.dayId.equals(dayId) &
          tbl.deletedAt.isNull());
    final items = await scheduleQuery.get();
    if (items.isEmpty) return;

    final itemByStopId = {for (final item in items) item.stopId: item};

    // Retrieve stops to recalculate leg transit times
    final stopQuery = db.select(db.stops)
      ..where((tbl) =>
          tbl.tripId.equals(tripId) &
          tbl.id.isIn(orderedStopIds) &
          tbl.deletedAt.isNull());
    final stops = await stopQuery.get();
    final stopMap = {for (final s in stops) s.id: s};

    // Generate new fractional index sort keys
    final keys = FractionalIndexUtil.generateNKeysBetween(
      null,
      null,
      orderedStopIds.length,
    );

    final now = DateTime.now();

    await db.transaction(() async {
      for (var i = 0; i < orderedStopIds.length; i++) {
        final stopId = orderedStopIds[i];
        final item = itemByStopId[stopId];
        if (item == null) continue;

        var transitMin = item.transitMinutes;
        if (i > 0) {
          final prevStop = stopMap[orderedStopIds[i - 1]];
          final currStop = stopMap[stopId];
          if (prevStop != null && currStop != null) {
            final dist = GeodesicMath.haversineDistance(
              prevStop.lat,
              prevStop.lng,
              currStop.lat,
              currStop.lng,
            );
            transitMin = GeodesicMath.estimateWalkingMinutes(dist);
          }
        }

        final updateQuery = db.update(db.scheduleItems)
          ..where((tbl) =>
              tbl.id.equals(item.id) & tbl.tripId.equals(tripId));
        await updateQuery.write(ScheduleItemsCompanion(
          sortKey: Value(keys[i]),
          transitMinutes: Value(transitMin),
          updatedAt: Value(now),
          syncStatus: const Value(1),
        ));
      }
    });
  }

  /// Exact Held-Karp / Branch-and-bound solver for N <= 8.
  List<int> _solveTspExact(
    List<List<double>> matrix,
    int? startIdx,
    int? endIdx,
  ) {
    final n = matrix.length;
    var bestDistance = double.infinity;
    List<int> bestTour = [];

    void permute(List<int> currentTour, double currentDistance) {
      if (currentTour.length == n) {
        if (endIdx != null && currentTour.last != endIdx) return;
        if (currentDistance < bestDistance) {
          bestDistance = currentDistance;
          bestTour = List.from(currentTour);
        }
        return;
      }

      if (currentDistance >= bestDistance) return;

      for (var i = 0; i < n; i++) {
        if (!currentTour.contains(i)) {
          // If endIdx is set, do not visit it until the last position
          if (endIdx != null && i == endIdx && currentTour.length < n - 1) {
            continue;
          }

          final last = currentTour.last;
          final leg = matrix[last][i];
          currentTour.add(i);
          permute(currentTour, currentDistance + leg);
          currentTour.removeLast();
        }
      }
    }

    final initialCandidates = startIdx != null
        ? [startIdx]
        : List.generate(n, (i) => i).where((i) => i != endIdx).toList();

    for (final start in initialCandidates) {
      permute([start], 0.0);
    }

    return bestTour.isNotEmpty ? bestTour : List.generate(n, (i) => i);
  }

  /// Heuristic Nearest-Neighbor + 2-Opt edge swapping for N > 8.
  List<int> _solveTsp2Opt(
    List<List<double>> matrix,
    int? startIdx,
    int? endIdx,
  ) {
    final n = matrix.length;

    // 1. Nearest Neighbor construction
    final visited = <int>{};
    final tour = <int>[];

    var current = startIdx ?? 0;
    tour.add(current);
    visited.add(current);
    if (endIdx != null) visited.add(endIdx);

    while (tour.length < (endIdx != null ? n - 1 : n)) {
      var nearest = -1;
      var nearestDist = double.infinity;

      for (var i = 0; i < n; i++) {
        if (!visited.contains(i)) {
          final dist = matrix[current][i];
          if (dist < nearestDist) {
            nearestDist = dist;
            nearest = i;
          }
        }
      }

      if (nearest != -1) {
        tour.add(nearest);
        visited.add(nearest);
        current = nearest;
      } else {
        break;
      }
    }

    if (endIdx != null) {
      tour.add(endIdx);
    }

    // 2. 2-Opt iterative improvement
    var improved = true;
    var iterations = 0;
    const maxIterations = 200;

    final minI = startIdx != null ? 1 : 0;
    final maxJ = endIdx != null ? n - 2 : n - 1;

    while (improved && iterations < maxIterations) {
      improved = false;
      iterations++;

      for (var i = minI; i < maxJ; i++) {
        for (var j = i + 1; j <= maxJ; j++) {
          final prevI = i > 0 ? tour[i - 1] : null;
          final currI = tour[i];
          final currJ = tour[j];
          final nextJ = j + 1 < n ? tour[j + 1] : null;

          final dCurrent = (prevI != null ? matrix[prevI][currI] : 0.0) +
              (nextJ != null ? matrix[currJ][nextJ] : 0.0);

          final dNew = (prevI != null ? matrix[prevI][currJ] : 0.0) +
              (nextJ != null ? matrix[currI][nextJ] : 0.0);

          if (dCurrent - dNew > 0.01) {
            // Reverse sub-tour from i to j
            _reverseSubTour(tour, i, j);
            improved = true;
            break;
          }
        }
        if (improved) break;
      }
    }

    return tour;
  }

  void _reverseSubTour(List<int> tour, int start, int end) {
    var l = start;
    var r = end;
    while (l < r) {
      final tmp = tour[l];
      tour[l] = tour[r];
      tour[r] = tmp;
      l++;
      r--;
    }
  }
}
