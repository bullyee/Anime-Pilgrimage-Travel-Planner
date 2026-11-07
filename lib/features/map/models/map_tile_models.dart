import 'dart:math' as math;

/// Represents an individual Slippy Map tile coordinate (z/x/y).
class TileCoordinate {
  final int z;
  final int x;
  final int y;

  const TileCoordinate({
    required this.z,
    required this.x,
    required this.y,
  });

  String get path => '$z/$x/$y.png';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          z == other.z &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'Tile($z/$x/$y)';
}

/// Bounding box representation for geographic regions.
class BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  }) : assert(minLat <= maxLat, 'minLat must be <= maxLat'),
       assert(minLng <= maxLng, 'minLng must be <= maxLng');

  /// Creates a bounding box enclosing [points] with an optional safety margin.
  factory BoundingBox.fromPoints(
    Iterable<({double lat, double lng})> points, {
    double bufferMeters = 500.0,
  }) {
    if (points.isEmpty) {
      return const BoundingBox(minLat: 0, maxLat: 0, minLng: 0, maxLng: 0);
    }

    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;

    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    // ~111,000 meters per degree of latitude
    final latBufferDeg = bufferMeters / 111000.0;
    // Account for longitudinal compression at mean latitude
    final meanLatRad = ((minLat + maxLat) / 2.0) * math.pi / 180.0;
    final lngBufferDeg = bufferMeters / (111000.0 * math.cos(meanLatRad).abs().clamp(0.1, 1.0));

    return BoundingBox(
      minLat: (minLat - latBufferDeg).clamp(-85.0511, 85.0511),
      maxLat: (maxLat + latBufferDeg).clamp(-85.0511, 85.0511),
      minLng: (minLng - lngBufferDeg).clamp(-180.0, 180.0),
      maxLng: (maxLng + lngBufferDeg).clamp(-180.0, 180.0),
    );
  }

  @override
  String toString() =>
      'BoundingBox(lat: ${minLat.toStringAsFixed(4)}..${maxLat.toStringAsFixed(4)}, '
      'lng: ${minLng.toStringAsFixed(4)}..${maxLng.toStringAsFixed(4)})';
}

/// Real-time progress update for an ongoing tile prefetch job.
class PrefetchProgress {
  final int total;
  final int downloaded;
  final int alreadyCached;
  final int failed;
  final int bytes;

  const PrefetchProgress({
    required this.total,
    required this.downloaded,
    required this.alreadyCached,
    required this.failed,
    required this.bytes,
  });

  double get percentage =>
      total > 0 ? ((downloaded + alreadyCached + failed) / total * 100.0) : 0.0;

  bool get isDone => (downloaded + alreadyCached + failed) >= total;

  @override
  String toString() =>
      'PrefetchProgress(${percentage.toStringAsFixed(1)}%: $downloaded dl, $alreadyCached cached, $failed fail of $total)';
}

/// Final summary result after completing a tile prefetch operation.
class PrefetchSummary {
  final int totalTiles;
  final int downloadedTiles;
  final int alreadyCachedTiles;
  final int failedTiles;
  final int totalBytes;
  final Duration duration;

  const PrefetchSummary({
    required this.totalTiles,
    required this.downloadedTiles,
    required this.alreadyCachedTiles,
    required this.failedTiles,
    required this.totalBytes,
    required this.duration,
  });

  bool get isSuccess => failedTiles == 0;

  @override
  String toString() =>
      'PrefetchSummary(total: $totalTiles, downloaded: $downloadedTiles, cached: $alreadyCachedTiles, '
      'failed: $failedTiles, size: ${(totalBytes / 1024).toStringAsFixed(1)}KB, '
      'time: ${duration.inMilliseconds}ms)';
}
