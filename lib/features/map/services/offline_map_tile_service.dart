import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database.dart';
import '../models/map_tile_models.dart';
import 'tile_math.dart';

/// Backend service for managing local OpenStreetMap raster tiles, prefetching
/// anime pilgrimage regions, and maintaining disk cache limits.
class OfflineMapTileService {
  static const String defaultOsmUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String userAgent = 'trip_planner/1.0 (Anime Pilgrimage Map Cache)';

  final Future<Directory> Function() _cacheDir;
  final String _urlTemplate;

  OfflineMapTileService({
    Future<Directory> Function()? cacheDir,
    String urlTemplate = defaultOsmUrlTemplate,
  })  : _cacheDir = cacheDir ?? _defaultCacheDir,
        _urlTemplate = urlTemplate;

  static Future<Directory> _defaultCacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'map_tiles'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Returns the local [File] reference for a [tile] in [baseDir].
  File getTileFile(Directory baseDir, TileCoordinate tile) {
    return File(p.join(baseDir.path, tile.z.toString(), tile.x.toString(), '${tile.y}.png'));
  }

  /// Checks if [tile] is already saved locally on disk.
  Future<File?> getCachedTile(TileCoordinate tile) async {
    final dir = await _cacheDir();
    final file = getTileFile(dir, tile);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Synchronous tile check when [baseDir] is already resolved.
  bool isTileCachedSync(Directory baseDir, TileCoordinate tile) {
    final file = getTileFile(baseDir, tile);
    return file.existsSync();
  }

  /// Downloads a single [tile] from the network and saves it to the local cache.
  Future<File?> downloadTile(
    TileCoordinate tile, {
    http.Client? client,
    String? urlTemplate,
  }) async {
    final dir = await _cacheDir();
    final targetFile = getTileFile(dir, tile);

    if (await targetFile.exists()) {
      return targetFile;
    }

    final template = urlTemplate ?? _urlTemplate;
    final url = template
        .replaceAll('{z}', tile.z.toString())
        .replaceAll('{x}', tile.x.toString())
        .replaceAll('{y}', tile.y.toString());

    final httpClient = client ?? http.Client();
    final ownsClient = client == null;

    try {
      final response = await httpClient.get(
        Uri.parse(url),
        headers: const {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(response.bodyBytes, flush: true);
      return targetFile;
    } catch (e) {
      debugPrint('[OfflineMapTileService] Failed to download tile $tile: $e');
      return null;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// Prefetches all tiles covering [bbox] across [zoomLevels] (e.g. 14, 15, 16).
  ///
  /// Enforces [maxTiles] limit to prevent accidental massive downloads.
  Future<PrefetchSummary> prefetchTilesForBoundingBox(
    BoundingBox bbox, {
    List<int> zoomLevels = const [14, 15, 16],
    void Function(PrefetchProgress)? onProgress,
    http.Client? client,
    int maxTiles = 500,
  }) async {
    final estimatedCount = TileMath.estimateTileCount(bbox, zoomLevels);
    if (estimatedCount > maxTiles) {
      throw ArgumentError(
        'Estimated tile count ($estimatedCount) exceeds maxTiles threshold ($maxTiles). '
        'Reduce zoom levels or zoom area.',
      );
    }

    final stopwatch = Stopwatch()..start();
    final allTiles = <TileCoordinate>[];
    for (final z in zoomLevels) {
      allTiles.addAll(TileMath.tilesForBoundingBox(bbox, z));
    }

    final total = allTiles.length;
    var downloaded = 0;
    var cached = 0;
    var failed = 0;
    var totalBytes = 0;

    final dir = await _cacheDir();
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;

    try {
      for (final tile in allTiles) {
        final targetFile = getTileFile(dir, tile);
        if (await targetFile.exists()) {
          cached++;
          totalBytes += await targetFile.length();
        } else {
          final savedFile = await downloadTile(
            tile,
            client: httpClient,
          );
          if (savedFile != null) {
            downloaded++;
            totalBytes += await savedFile.length();
          } else {
            failed++;
          }
          // Polite rate-limiting between successive tile downloads
          await Future.delayed(const Duration(milliseconds: 10));
        }

        onProgress?.call(PrefetchProgress(
          total: total,
          downloaded: downloaded,
          alreadyCached: cached,
          failed: failed,
          bytes: totalBytes,
        ));
      }
    } finally {
      if (ownsClient) httpClient.close();
      stopwatch.stop();
    }

    return PrefetchSummary(
      totalTiles: total,
      downloadedTiles: downloaded,
      alreadyCachedTiles: cached,
      failedTiles: failed,
      totalBytes: totalBytes,
      duration: stopwatch.elapsed,
    );
  }

  /// Computes the bounding box of [stops] and prefetches all tiles for offline travel.
  Future<PrefetchSummary> prefetchTilesForStops(
    List<Stop> stops, {
    List<int> zoomLevels = const [14, 15, 16],
    double bufferMeters = 500.0,
    void Function(PrefetchProgress)? onProgress,
    http.Client? client,
    int maxTiles = 500,
  }) async {
    if (stops.isEmpty) {
      return const PrefetchSummary(
        totalTiles: 0,
        downloadedTiles: 0,
        alreadyCachedTiles: 0,
        failedTiles: 0,
        totalBytes: 0,
        duration: Duration.zero,
      );
    }

    final bbox = BoundingBox.fromPoints(
      stops.map((s) => (lat: s.lat, lng: s.lng)),
      bufferMeters: bufferMeters,
    );

    return prefetchTilesForBoundingBox(
      bbox,
      zoomLevels: zoomLevels,
      onProgress: onProgress,
      client: client,
      maxTiles: maxTiles,
    );
  }

  /// Calculates total bytes consumed by all cached tiles on disk.
  Future<int> getCacheSizeBytes() async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return 0;

    var totalBytes = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.png')) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes;
  }

  /// Counts the total number of individual tiles cached on disk.
  Future<int> getCachedTileCount() async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return 0;

    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.png')) {
        count++;
      }
    }
    return count;
  }

  /// Clears all cached tiles from disk.
  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }

  /// Evicts oldest tiles according to LRU / modified time until total size <= [targetMaxBytes].
  ///
  /// Returns the count of deleted tiles.
  Future<int> evictOldestTiles({int targetMaxBytes = 100 * 1024 * 1024}) async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return 0;

    final tileFiles = <({File file, DateTime modified, int size})>[];
    var currentTotalSize = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.png')) {
        final stat = await entity.stat();
        final size = stat.size;
        currentTotalSize += size;
        tileFiles.add((file: entity, modified: stat.modified, size: size));
      }
    }

    if (currentTotalSize <= targetMaxBytes) {
      return 0;
    }

    // Sort ascending by modified time (oldest first)
    tileFiles.sort((a, b) => a.modified.compareTo(b.modified));

    var deletedCount = 0;
    for (final item in tileFiles) {
      if (currentTotalSize <= targetMaxBytes) break;
      try {
        await item.file.delete();
        currentTotalSize -= item.size;
        deletedCount++;
      } catch (_) {
        // Ignore deletion failures
      }
    }

    return deletedCount;
  }
}
