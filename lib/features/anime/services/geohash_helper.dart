import 'dart:math' as math;

/// Fast spatial indexing utilities using standard Geohash and metric grid bucketing.
class GeohashHelper {
  const GeohashHelper._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static final Map<String, int> _base32Lookup = {
    for (var i = 0; i < _base32.length; i++) _base32[i]: i,
  };

  /// Encodes a WGS84 coordinate pair into a standard geohash of length [precision].
  ///
  /// Precision guidelines:
  /// - 6: ~1.2 km x 0.6 km (city neighborhood)
  /// - 7: ~153 m x 153 m (street block)
  /// - 8: ~38 m x 19 m (individual building / plaza)
  /// - 9: ~4.8 m x 4.8 m (sub-meter pinpoint)
  static String encode(double lat, double lng, {int precision = 8}) {
    final clampedLat = lat.clamp(-90.0, 90.0);
    final clampedLng = lng.clamp(-180.0, 180.0);

    var latMin = -90.0;
    var latMax = 90.0;
    var lngMin = -180.0;
    var lngMax = 180.0;

    final hash = StringBuffer();
    var isEven = true;
    var bit = 0;
    var ch = 0;

    while (hash.length < precision) {
      if (isEven) {
        final mid = (lngMin + lngMax) / 2.0;
        if (clampedLng >= mid) {
          ch |= 1 << (4 - bit);
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2.0;
        if (clampedLat >= mid) {
          ch |= 1 << (4 - bit);
          latMin = mid;
        } else {
          latMax = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        hash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return hash.toString();
  }

  /// Decodes a [geohash] into center coordinates and error margins.
  static ({double lat, double lng, double latError, double lngError}) decode(
    String geohash,
  ) {
    var latMin = -90.0;
    var latMax = 90.0;
    var lngMin = -180.0;
    var lngMax = 180.0;
    var isEven = true;

    for (var i = 0; i < geohash.length; i++) {
      final cd = _base32Lookup[geohash[i].toLowerCase()] ?? 0;
      for (var j = 4; j >= 0; j--) {
        final mask = 1 << j;
        if (isEven) {
          final mid = (lngMin + lngMax) / 2.0;
          if ((cd & mask) != 0) {
            lngMin = mid;
          } else {
            lngMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2.0;
          if ((cd & mask) != 0) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        isEven = !isEven;
      }
    }

    final lat = (latMin + latMax) / 2.0;
    final lng = (lngMin + lngMax) / 2.0;
    final latError = (latMax - latMin) / 2.0;
    final lngError = (lngMax - lngMin) / 2.0;

    return (lat: lat, lng: lng, latError: latError, lngError: lngError);
  }

  /// Calculates a spatial grid cell index `(row, col)` for metric bucketing.
  ///
  /// Converts lat/lng into meter displacements from origin (0, 0) divided by [cellSizeMeters].
  static ({int row, int col}) gridCell(
    double lat,
    double lng, {
    double cellSizeMeters = 35.0,
  }) {
    // 1 deg latitude ~ 111,320 meters
    const metersPerDegreeLat = 111320.0;
    final row = (lat * metersPerDegreeLat / cellSizeMeters).floor();

    // 1 deg longitude ~ 111,320 * cos(lat) meters
    final latRad = lat * math.pi / 180.0;
    final metersPerDegreeLng = metersPerDegreeLat * math.cos(latRad);
    final col = metersPerDegreeLng > 0
        ? (lng * metersPerDegreeLng / cellSizeMeters).floor()
        : 0;

    return (row: row, col: col);
  }

  /// Generates the keys for the target grid cell and all 8 immediately adjacent neighboring cells.
  static List<String> neighborGridKeys(
    double lat,
    double lng, {
    double cellSizeMeters = 35.0,
  }) {
    final cell = gridCell(lat, lng, cellSizeMeters: cellSizeMeters);
    final keys = <String>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        keys.add('${cell.row + dr}:${cell.col + dc}');
      }
    }
    return keys;
  }
}
