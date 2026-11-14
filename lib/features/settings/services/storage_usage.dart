import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/map/app_map.dart';

/// How much space the app takes on the phone, for Settings → Your data.
class StorageUsage {
  /// Everything the app keeps: the database, photos, frames, covers, caches.
  final int total;

  /// The map tiles kept for 14 days ([setUpMapTileCache]).
  final int mapTiles;

  /// The anime cutout's model, downloaded the first time it's used.
  final int cutoutModel;

  const StorageUsage({required this.total, required this.mapTiles, required this.cutoutModel});

  /// The database, photos, frames and the rest: what the user's own data takes.
  int get yourData => total - mapTiles - cutoutModel;
}

/// The folders to measure, so tests can point them elsewhere.
class StorageFolders {
  final List<String> roots;
  final String? mapTiles;
  final String cutoutModel;

  const StorageFolders({required this.roots, required this.mapTiles, required this.cutoutModel});
}

final storageFoldersProvider = Provider<Future<StorageFolders> Function()>((ref) => () async {
      final support = (await getApplicationSupportDirectory()).path;
      final docs = (await getApplicationDocumentsDirectory()).path;
      return StorageFolders(
        // On Android and iOS these two are apart; elsewhere one may hold the other.
        roots: {support, docs}.toList(),
        mapTiles: await mapTileCacheDirectory(),
        cutoutModel: p.join(support, 'models'),
      );
    });

/// Measured off the main thread; refresh it after clearing something.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((ref) async {
  final folders = await ref.watch(storageFoldersProvider)();
  return compute(measureStorage, folders);
});

/// Adds up the sizes of the files under [StorageFolders]. A folder inside
/// another root is counted once.
StorageUsage measureStorage(StorageFolders f) {
  final roots = [...f.roots]..sort((a, b) => a.length.compareTo(b.length));
  final counted = <String>[];
  var total = 0;
  for (final root in roots) {
    if (counted.any((c) => p.isWithin(c, root))) continue;
    counted.add(root);
    total += _sizeOf(root);
  }
  return StorageUsage(
    total: total,
    mapTiles: f.mapTiles == null ? 0 : _sizeOf(f.mapTiles!),
    cutoutModel: _sizeOf(f.cutoutModel),
  );
}

int _sizeOf(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;
  var bytes = 0;
  try {
    for (final e in dir.listSync(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          bytes += e.lengthSync();
        } catch (_) {
          // Gone while counting.
        }
      }
    }
  } catch (_) {
    // A folder we can't read: count what we have.
  }
  return bytes;
}
