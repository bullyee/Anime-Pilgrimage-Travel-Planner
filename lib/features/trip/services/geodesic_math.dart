import 'dart:math' as math;

/// Mathematical and geodesic calculation utilities for pilgrimage route planning.
class GeodesicMath {
  const GeodesicMath._();

  /// Earth's mean radius in meters (WGS84).
  static const double earthRadiusMeters = 6371000.0;

  /// Standard walking speed: 80 meters per minute (~4.8 km/h).
  /// Matches standard Japanese transit & walking guideline (1分 = 80m).
  static const double standardWalkingSpeedMpm = 80.0;

  /// Calculates geodesic distance between two coordinates in meters using the Haversine formula.
  static double haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    if (lat1 == lat2 && lng1 == lng2) return 0.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLng / 2) * math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates the forward azimuth / bearing from (lat1, lng1) to (lat2, lng2) in degrees [0, 360).
  static double bearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);
    final dLng = _toRadians(lng2 - lng1);

    final y = math.sin(dLng) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLng);

    final theta = math.atan2(y, x);
    final deg = (theta * 180.0 / math.pi + 360.0) % 360.0;
    return deg;
  }

  /// Converts a bearing in degrees to an 8-point compass abbreviation.
  static String bearingToCompass(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = (degrees % 360.0 + 360.0) % 360.0;
    final index = ((normalized + 22.5) / 45.0).floor() % 8;
    return directions[index];
  }

  /// Estimates walking time in minutes for [distanceMeters].
  static int estimateWalkingMinutes(
    double distanceMeters, {
    double speedMpm = standardWalkingSpeedMpm,
  }) {
    if (distanceMeters <= 5.0) return 0;
    final minutes = (distanceMeters / speedMpm).ceil();
    return math.max(1, minutes);
  }

  /// Computes a full symmetric distance matrix in meters for a list of coordinates.
  static List<List<double>> computeDistanceMatrix(
    List<({double lat, double lng})> points,
  ) {
    final n = points.length;
    final matrix = List.generate(n, (_) => List<double>.filled(n, 0.0));

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final dist = haversineDistance(
          points[i].lat,
          points[i].lng,
          points[j].lat,
          points[j].lng,
        );
        matrix[i][j] = dist;
        matrix[j][i] = dist;
      }
    }
    return matrix;
  }

  /// Computes the total sequential route distance for a list of points.
  static double totalRouteDistance(List<({double lat, double lng})> points) {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += haversineDistance(
        points[i].lat,
        points[i].lng,
        points[i + 1].lat,
        points[i + 1].lng,
      );
    }
    return total;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
