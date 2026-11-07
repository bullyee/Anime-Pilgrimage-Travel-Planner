import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../models/route_optimization_models.dart';
import '../services/pilgrimage_clustering_service.dart';
import '../services/route_optimization_service.dart';

/// Provider for [RouteOptimizationService].
final routeOptimizationServiceProvider =
    Provider<RouteOptimizationService>((ref) {
  return const RouteOptimizationService();
});

/// Provider for [PilgrimageClusteringService].
final pilgrimageClusteringServiceProvider =
    Provider<PilgrimageClusteringService>((ref) {
  return const PilgrimageClusteringService();
});

/// Computes walking clusters for all active stops in [tripId].
final tripClustersProvider =
    FutureProvider.autoDispose.family<List<StopCluster>, String>(
        (ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.stops)
    ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull());
  final stops = await query.get();

  final service = ref.watch(pilgrimageClusteringServiceProvider);
  return service.clusterStops(stops);
});

/// Computes an optimal visit order and route metrics for scheduled stops on [dayId] in [tripId].
final dayOptimizedRouteProvider = FutureProvider.autoDispose.family<
    RouteOptimizationResult?, ({String tripId, String dayId})>(
        (ref, params) async {
  final db = ref.watch(databaseProvider);

  // 1. Fetch scheduled items for the day in current sort order
  final itemsQuery = db.select(db.scheduleItems)
    ..where((tbl) =>
        tbl.tripId.equals(params.tripId) &
        tbl.dayId.equals(params.dayId) &
        tbl.deletedAt.isNull())
    ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortKey)]);
  final items = await itemsQuery.get();
  if (items.isEmpty) return null;

  // 2. Fetch corresponding stops
  final stopIds = items.map((i) => i.stopId).toList();
  final stopsQuery = db.select(db.stops)
    ..where((tbl) =>
        tbl.tripId.equals(params.tripId) &
        tbl.id.isIn(stopIds) &
        tbl.deletedAt.isNull());
  final stops = await stopsQuery.get();
  final stopMap = {for (final s in stops) s.id: s};

  // Reconstruct in schedule order
  final scheduledStops = <Stop>[];
  for (final id in stopIds) {
    final s = stopMap[id];
    if (s != null) scheduledStops.add(s);
  }

  if (scheduledStops.isEmpty) return null;

  final optimizer = ref.watch(routeOptimizationServiceProvider);
  return optimizer.optimizeRoute(scheduledStops);
});
