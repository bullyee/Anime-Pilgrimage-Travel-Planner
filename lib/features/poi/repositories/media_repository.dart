import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:drift/drift.dart';
import '../models/media_asset_model.dart';
import '../models/reference_image_model.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_repository.g.dart';

abstract class MediaRepository {
  /// Whether [poiId] is a POI of the old model. Media can only join one that
  /// is; places made in the new library have no POI.
  Future<bool> poiExists(String poiId);

  // Media Assets
  Future<void> addMediaAsset(MediaAssetModel asset);
  Future<void> deleteMediaAsset(String id);
  
  // Reference Images
  Future<void> addReferenceImage(ReferenceImageModel image);
  Future<void> deleteReferenceImage(String id);
  
  // Renamed to reflect localPath and allow nullable values
  Future<void> updateMediaAssetLocalPath(String id, String? newPath);
  Future<void> updateReferenceImageLocalPath(String id, String? newPath);
  
  Stream<List<MediaAssetModel>> watchMediaAssetsByPoi(String poiId);
  Stream<List<ReferenceImageModel>> watchReferenceImagesByPoi(String poiId);
  Stream<List<MediaAssetModel>> watchMediaAssetsByType(String type);
}

class LocalMediaRepository implements MediaRepository {
  final AppDatabase localDb;
  LocalMediaRepository(this.localDb);

  MediaAssetModel _mapMediaAsset(MediaAsset asset) {
    return MediaAssetModel(
      id: asset.id,
      poiId: asset.poiId,
      authorId: asset.authorId,
      localPath: asset.localPath,
      type: asset.type,
      remoteUrl: asset.remoteUrl,
      metadata: asset.metadata,
      referenceImageId: asset.referenceImageId,
      createdAt: asset.createdAt,
      isShared: false,
    );
  }

  ReferenceImageModel _mapReferenceImage(ReferenceImage img) {
    return ReferenceImageModel(
      id: img.id,
      poiId: img.poiId,
      authorId: img.authorId,
      localPath: img.localPath,
      remoteUrl: img.remoteUrl,
      metadata: img.metadata,
      createdAt: img.createdAt,
      isShared: false,
    );
  }

  @override
  Future<bool> poiExists(String poiId) async =>
      await (localDb.select(localDb.pois)..where((p) => p.id.equals(poiId))).getSingleOrNull() != null;

  @override
  Future<void> addMediaAsset(MediaAssetModel asset) async {
    await localDb.insertMediaAsset(
      MediaAssetsCompanion.insert(
        id: asset.id,
        poiId: asset.poiId,
        authorId: asset.authorId,
        localPath: Value(asset.localPath),
        type: asset.type ?? 'unknown', 
        remoteUrl: Value(asset.remoteUrl), 
        metadata: Value(asset.metadata),   
        referenceImageId: Value(asset.referenceImageId),
        createdAt: Value(asset.createdAt),
      )
    );
  }

  @override
  Future<void> deleteMediaAsset(String id) async {
    String? pathToDelete;
    try {
      final asset = await (localDb.select(localDb.mediaAssets)..where((m) => m.id.equals(id))).getSingleOrNull();
      if (asset?.localPath != null && asset!.localPath!.isNotEmpty) {
        pathToDelete = asset.localPath;
      }
    } catch (e) {
      debugPrint('[MediaRepository] Failed to inspect file path for MediaAsset $id: $e');
    }

    await localDb.deleteMediaAsset(id);

    if (pathToDelete != null) {
      try {
        final file = File(pathToDelete);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[MediaRepository] Failed to delete physical file $pathToDelete: $e');
      }
    }
  }

  @override
  Future<void> addReferenceImage(ReferenceImageModel image) async {
    await localDb.insertReferenceImage(
      ReferenceImagesCompanion.insert(
        id: image.id,
        poiId: image.poiId,
        authorId: image.authorId,
        localPath: Value(image.localPath),
        remoteUrl: Value(image.remoteUrl), 
        metadata: Value(image.metadata),   
        createdAt: Value(image.createdAt),
      )
    );
  }

  @override
  Future<void> deleteReferenceImage(String id) async {
    String? pathToDelete;
    try {
      final img = await (localDb.select(localDb.referenceImages)..where((r) => r.id.equals(id))).getSingleOrNull();
      if (img?.localPath != null && img!.localPath!.isNotEmpty) {
        pathToDelete = img.localPath;
      }
    } catch (e) {
      debugPrint('[MediaRepository] Failed to inspect file path for ReferenceImage $id: $e');
    }

    await localDb.deleteReferenceImage(id);

    if (pathToDelete != null) {
      try {
        final file = File(pathToDelete);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[MediaRepository] Failed to delete physical file $pathToDelete: $e');
      }
    }
  }

  @override
  Stream<List<MediaAssetModel>> watchMediaAssetsByPoi(String poiId) {
    return localDb.watchMediaAssetsByPoi(poiId).map((list) {
      return list.map(_mapMediaAsset).toList();
    });
  }

  @override
  Stream<List<ReferenceImageModel>> watchReferenceImagesByPoi(String poiId) {
    return localDb.watchReferenceImagesByPoi(poiId).map((list) {
      return list.map(_mapReferenceImage).toList();
    });
  }

  @override
  Future<void> updateMediaAssetLocalPath(String id, String? newPath) async {
    await localDb.updateMediaAssetLocalPath(id, newPath);
  }

  @override
  Future<void> updateReferenceImageLocalPath(String id, String? newPath) async {
    await localDb.updateReferenceImageLocalPath(id, newPath);
  }

  @override
  Stream<List<MediaAssetModel>> watchMediaAssetsByType(String type) {
    return (localDb.select(localDb.mediaAssets)
          ..where((tbl) => tbl.type.equals(type))
          ..orderBy([(m) => OrderingTerm.desc(m.id)]))
        .watch()
        .map((rows) {
          return rows.map(_mapMediaAsset).toList();
        });
  }
}

@riverpod
MediaRepository mediaRepository(MediaRepositoryRef ref) {
  return LocalMediaRepository(ref.watch(databaseProvider));
}
