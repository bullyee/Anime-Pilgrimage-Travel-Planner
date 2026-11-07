import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../services/offline_first_tile_provider.dart';
import '../services/offline_map_tile_service.dart';

/// Provider for the singleton/shared [OfflineMapTileService].
final offlineMapTileServiceProvider = Provider<OfflineMapTileService>((ref) {
  return OfflineMapTileService();
});

/// Reactive provider that prepares an [OfflineFirstTileProvider] with resolved disk cache directory.
final offlineFirstTileProvider =
    FutureProvider<OfflineFirstTileProvider>((ref) async {
  final service = ref.watch(offlineMapTileServiceProvider);
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'map_tiles'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return OfflineFirstTileProvider(
    service: service,
    cacheDir: dir,
  );
});

/// Returns total disk storage in bytes consumed by cached map tiles.
final mapTileCacheSizeBytesProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(offlineMapTileServiceProvider);
  return service.getCacheSizeBytes();
});

/// Returns the total number of cached map tiles on disk.
final mapTileCacheCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(offlineMapTileServiceProvider);
  return service.getCachedTileCount();
});
