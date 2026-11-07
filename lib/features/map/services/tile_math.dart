import 'dart:math' as math;

import '../models/map_tile_models.dart';

/// Slippy Map (Web Mercator EPSG:3857) tile coordinate mathematical utilities.
class TileMath {
  const TileMath._();

  /// Converts a WGS84 ([lat], [lng]) pair into a [TileCoordinate] at [zoom].
  static TileCoordinate latLngToTile(double lat, double lng, int zoom) {
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final clampedLng = lng.clamp(-180.0, 180.0);

    final n = 1 << zoom;
    final x = ((clampedLng + 180.0) / 360.0 * n).floor().clamp(0, n - 1);

    final latRad = clampedLat * math.pi / 180.0;
    final y = ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            n)
        .floor()
        .clamp(0, n - 1);

    return TileCoordinate(z: zoom, x: x, y: y);
  }

  /// Converts a [TileCoordinate] back into the NW corner ([lat], [lng]) coordinates.
  static ({double lat, double lng}) tileToNorthWestLatLng(
    int x,
    int y,
    int zoom,
  ) {
    final n = 1 << zoom;
    final lng = x / n * 360.0 - 180.0;
    final latRad = math.atan(_sinh(math.pi * (1.0 - 2.0 * y / n)));
    final lat = latRad * 180.0 / math.pi;
    return (lat: lat, lng: lng);
  }

  /// Calculates all tile coordinates spanning [bbox] at the specified [zoom].
  static List<TileCoordinate> tilesForBoundingBox(BoundingBox bbox, int zoom) {
    final topLeft = latLngToTile(bbox.maxLat, bbox.minLng, zoom);
    final bottomRight = latLngToTile(bbox.minLat, bbox.maxLng, zoom);

    final minX = math.min(topLeft.x, bottomRight.x);
    final maxX = math.max(topLeft.x, bottomRight.x);
    final minY = math.min(topLeft.y, bottomRight.y);
    final maxY = math.max(topLeft.y, bottomRight.y);

    final tiles = <TileCoordinate>[];
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        tiles.add(TileCoordinate(z: zoom, x: x, y: y));
      }
    }
    return tiles;
  }

  /// Estimates the total number of tiles needed to cover [bbox] across [zoomLevels].
  static int estimateTileCount(BoundingBox bbox, List<int> zoomLevels) {
    var count = 0;
    for (final z in zoomLevels) {
      final topLeft = latLngToTile(bbox.maxLat, bbox.minLng, z);
      final bottomRight = latLngToTile(bbox.minLat, bbox.maxLng, z);

      final minX = math.min(topLeft.x, bottomRight.x);
      final maxX = math.max(topLeft.x, bottomRight.x);
      final minY = math.min(topLeft.y, bottomRight.y);
      final maxY = math.max(topLeft.y, bottomRight.y);

      count += (maxX - minX + 1) * (maxY - minY + 1);
    }
    return count;
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;
}
