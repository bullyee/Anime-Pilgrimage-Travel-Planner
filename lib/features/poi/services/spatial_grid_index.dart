import 'dart:math' as math;

/// Fast, battery-friendly 2D spatial grid index for proximity detection.
///
/// Buckets geographic coordinates into grid cells so that user location queries
/// check only the immediate surrounding cells in O(1) time rather than scanning
/// all N spots with costly trigonometric Haversine computations.
class SpatialGridIndex<T> {
  /// Grid cell size in degrees (~0.005 deg ≈ 550 meters at mid-latitudes).
  final double cellSize;

  final Map<int, List<({double lat, double lng, T item})>> _grid = {};

  SpatialGridIndex({this.cellSize = 0.005}) : assert(cellSize > 0);

  /// Clears the index.
  void clear() {
    _grid.clear();
  }

  /// Inserts an [item] at coordinates ([lat], [lng]).
  void insert(double lat, double lng, T item) {
    final key = _hashCell(lat, lng);
    _grid.putIfAbsent(key, () => []).add((lat: lat, lng: lng, item: item));
  }

  /// Batch inserts multiple items into the spatial grid.
  void insertAll(Iterable<({double lat, double lng, T item})> items) {
    for (final it in items) {
      insert(it.lat, it.lng, it.item);
    }
  }

  /// Queries all candidate items within the surrounding 9 grid cells of ([lat], [lng]).
  List<({double lat, double lng, T item})> queryCandidates(
    double lat,
    double lng, {
    double radiusMeters = 100.0,
  }) {
    // Determine how many cell rings to search based on radius
    // ~111,000 meters per degree of latitude
    final searchSpanDeg = radiusMeters / 111000.0;
    final ringRadius = math.max(1, (searchSpanDeg / cellSize).ceil());

    final cellX = (lat / cellSize).floor();
    final cellY = (lng / cellSize).floor();

    final candidates = <({double lat, double lng, T item})>[];

    for (var dx = -ringRadius; dx <= ringRadius; dx++) {
      for (var dy = -ringRadius; dy <= ringRadius; dy++) {
        final key = _keyForCell(cellX + dx, cellY + dy);
        final cellItems = _grid[key];
        if (cellItems != null) {
          candidates.addAll(cellItems);
        }
      }
    }

    return candidates;
  }

  int _hashCell(double lat, double lng) {
    final x = (lat / cellSize).floor();
    final y = (lng / cellSize).floor();
    return _keyForCell(x, y);
  }

  int _keyForCell(int x, int y) {
    // 32-bit Cantor pairing hash
    return (x * 73856093) ^ (y * 19349663);
  }
}
