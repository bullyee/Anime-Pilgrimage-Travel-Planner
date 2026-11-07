import '../../../core/database/database.dart';

/// A single travel leg between two consecutive stops on a pilgrimage itinerary.
class RouteLeg {
  final String fromStopId;
  final String fromStopName;
  final String toStopId;
  final String toStopName;
  final double distanceMeters;
  final int estimatedWalkingMinutes;
  final String bearingCompass;

  const RouteLeg({
    required this.fromStopId,
    required this.fromStopName,
    required this.toStopId,
    required this.toStopName,
    required this.distanceMeters,
    required this.estimatedWalkingMinutes,
    required this.bearingCompass,
  });

  @override
  String toString() =>
      'RouteLeg($fromStopName -> $toStopName: ${(distanceMeters).toStringAsFixed(1)}m, ~$estimatedWalkingMinutes min, $bearingCompass)';
}

/// The result of a Traveling Salesperson / 2-Opt route optimization.
class RouteOptimizationResult {
  final List<String> orderedStopIds;
  final List<Stop> orderedStops;
  final List<RouteLeg> legs;
  final double totalDistanceMeters;
  final int totalEstimatedWalkingMinutes;
  final double originalDistanceMeters;
  final double savedDistanceMeters;
  final double savedDistancePercentage;

  const RouteOptimizationResult({
    required this.orderedStopIds,
    required this.orderedStops,
    required this.legs,
    required this.totalDistanceMeters,
    required this.totalEstimatedWalkingMinutes,
    required this.originalDistanceMeters,
    required this.savedDistanceMeters,
    required this.savedDistancePercentage,
  });

  /// True if optimization found a shorter route than the original sequence.
  bool get hasImprovement => savedDistanceMeters > 5.0;

  @override
  String toString() =>
      'RouteOptimizationResult(total: ${(totalDistanceMeters / 1000).toStringAsFixed(2)}km, '
      'saved: ${(savedDistanceMeters / 1000).toStringAsFixed(2)}km (${savedDistancePercentage.toStringAsFixed(1)}%), '
      'walk: ~$totalEstimatedWalkingMinutes min)';
}

/// A geographic cluster of pilgrimage spots in walking proximity (e.g. Uji River Area).
class StopCluster {
  final String clusterId;
  final String name;
  final double centerLat;
  final double centerLng;
  final List<Stop> stops;
  final double radiusMeters;

  const StopCluster({
    required this.clusterId,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.stops,
    required this.radiusMeters,
  });

  int get stopCount => stops.length;

  @override
  String toString() =>
      'StopCluster($name, spots: ${stops.length}, center: ($centerLat, $centerLng), radius: ${radiusMeters.toStringAsFixed(0)}m)';
}
