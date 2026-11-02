import 'dart:io';

import 'package:flutter/foundation.dart'; // ADDED: for debugPrint
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';
import '../../library/repositories/place_repository.dart';
import '../models/media_asset_model.dart';
import '../repositories/media_repository.dart';

/// Copies [source] into the app's permanent `camera_photos` directory
/// (filename derived from a unique UUID) and inserts a matching `MediaAsset`
/// row pointing at the new path.
///
/// [type] should be `user_photo` for fresh camera captures or
/// `uploaded_image` for gallery-picked photos — the POI detail list
/// chooses its icon from this column.
///
/// While the old POI screens and the new place pages both exist, the photo
/// joins both models: the POI's media when [poiId] is a POI, and the place's
/// photos (from [places]) when it is a place. Migrated places keep their POI
/// ids, so most photos land in both, under the same id, which keeps the
/// v9 → v10 migration from copying them twice when it re-runs at the cutover.
///
/// Returns `true` on success, `false` on any I/O or database failure
/// — callers decide whether to surface that via a SnackBar.
Future<bool> persistMediaAsset({
  required MediaRepository mediaRepo,
  required File source,
  required String poiId,
  required String type,
  required String authorId, // CRITICAL FIX: Mandate authorId from the caller
  String? referenceImageId,
  PlaceRepository? places,
}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'camera_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final assetId = const Uuid().v4();
    final extension =
        p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final savedPath = p.join(photosDir.path, 'photo_$assetId$extension');
    await source.copy(savedPath);

    final newAsset = MediaAssetModel(
      id: assetId,
      poiId: poiId,
      type: type,
      authorId: authorId, // CRITICAL FIX: Use the injected ID
      localPath: savedPath,
      referenceImageId: referenceImageId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    
    var saved = false;
    if (await mediaRepo.poiExists(poiId)) {
      await mediaRepo.addMediaAsset(newAsset);
      saved = true;
    }
    if (places != null && await places.getPlace(poiId) != null) {
      await places.upsertPhoto(PhotosCompanion.insert(
        id: assetId,
        placeKey: poiId,
        // The kinds the v9 → v10 migration gives these types.
        kind: Value(type == 'comparison_image' ? 'comparison' : 'original'),
        referenceImageId: Value(referenceImageId),
        localPath: savedPath,
        takenAt: Value(DateTime.now()),
      ));
      saved = true;
    }
    if (!saved) throw StateError('$poiId is neither a POI nor a place');
    return true;
  } catch (e, st) {
    // CRITICAL FIX: Stop silent failures. Log the exact I/O or DB error.
    debugPrint('[MediaAssetService] Failed to persist media asset: $e\n$st');
    return false;
  }
}

