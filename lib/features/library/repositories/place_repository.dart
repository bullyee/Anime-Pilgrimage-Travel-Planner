import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/platform_media.dart';

/// Repository interface for managing the personal places library, labels, and photos.
abstract class PlaceRepository {
  /// Retrieves places, optionally filtered by visibility ('saved' | 'trip_only').
  Future<List<Place>> getPlaces({String? visibility});

  /// Watches places, optionally filtered by visibility.
  Stream<List<Place>> watchPlaces({String? visibility});

  /// Retrieves places linked to a specific label.
  Future<List<Place>> getPlacesByLabel(String labelId, {String? visibility});

  /// Watches places linked to a specific label.
  Stream<List<Place>> watchPlacesByLabel(String labelId, {String? visibility});

  /// Retrieves a place by its unique [placeKey].
  Future<Place?> getPlace(String placeKey);

  /// Watches a place by its unique [placeKey].
  Stream<Place?> watchPlace(String placeKey);

  /// Inserts or updates a place.
  Future<void> upsertPlace(PlacesCompanion place);

  /// Updates fields on an existing place and bumps `updatedAt`.
  Future<void> updatePlace(PlacesCompanion place);

  /// Deletes a place from the personal library.
  Future<void> deletePlace(String placeKey);

  /// Creates a hidden `trip_only` place to back a newly created stop in a trip.
  Future<Place> createTripOnlyPlace({
    required String name,
    required double lat,
    required double lng,
    String? address,
    String? description,
    String? accessTips,
  });

  /// Changes the visibility of a place (e.g. promoting `trip_only` to `saved`).
  Future<void> setPlaceVisibility(String placeKey, String visibility);

  // ==========================================================================
  // Labels
  // ==========================================================================

  /// Attaches a label to a place.
  Future<void> attachLabelToPlace(String placeKey, String labelId);

  /// Detaches a label from a place.
  Future<void> removeLabelFromPlace(String placeKey, String labelId);

  /// Retrieves all labels attached to a place.
  Future<List<Label>> getLabelsForPlace(String placeKey);

  /// Watches all labels attached to a place.
  Stream<List<Label>> watchLabelsForPlace(String placeKey);

  /// Retrieves a single label by ID.
  Future<Label?> getLabel(String labelId);

  /// Retrieves all labels, optionally filtered by kind ('anime' | 'tag' | 'region').
  Future<List<Label>> getLabels({String? kind});

  /// Watches all labels, optionally filtered by kind.
  Stream<List<Label>> watchLabels({String? kind});

  /// Gets an existing label matching the natural key, or creates a new one.
  ///
  /// Natural key matching per `docs/data-model.md`:
  /// - `anime`: matched by [bangumiId] if provided, else by [name].
  /// - `tag` and `region`: matched by [kind] + [name].
  Future<Label> getOrCreateLabel({
    required String kind,
    required String name,
    String? bangumiId,
  });

  /// Renames a label (or updates its [bangumiId]). If another label of the same
  /// kind already matches the target natural key, merges [labelId] into it and
  /// returns the surviving [Label].
  Future<Label> renameLabel(
    String labelId,
    String newName, {
    String? bangumiId,
  });

  /// Merges [sourceLabelId] into [targetLabelId], re-pointing all place/stop
  /// associations and reference image `animeLabelId` references, then deletes
  /// [sourceLabelId].
  Future<void> mergeLabels({
    required String sourceLabelId,
    required String targetLabelId,
  });

  /// Deletes a label by [labelId].
  Future<void> deleteLabel(String labelId);

  // ==========================================================================
  // Photos
  // ==========================================================================

  Future<Photo?> getPhoto(String id);
  Future<List<Photo>> getPhotosForPlace(String placeKey);
  Stream<List<Photo>> watchPhotosForPlace(String placeKey);
  Future<List<Photo>> getPhotosForTrip(String tripId);
  Stream<List<Photo>> watchPhotosForTrip(String tripId);
  Future<Photo> addPhoto({
    required String placeKey,
    required String localPath,
    String? tripId,
    String kind = 'original',
    String? derivedFromId,
    String? referenceImageId,
    String? remoteUrl,
    bool isShared = false,
    DateTime? takenAt,
  });
  Future<void> upsertPhoto(PhotosCompanion photo);
  Future<void> updatePhoto(PhotosCompanion photo);
  Future<void> deletePhoto(String id);

  // ==========================================================================
  // Reference Images (v10_reference_images)
  // ==========================================================================

  Future<NewReferenceImage?> getReferenceImage(String id);
  Future<List<NewReferenceImage>> getReferenceImagesForPlace(String placeKey);
  Stream<List<NewReferenceImage>> watchReferenceImagesForPlace(String placeKey);
  Future<NewReferenceImage> addReferenceImage({
    String? placeKey,
    String? stopId,
    String? localPath,
    String? remoteUrl,
    String? animeLabelId,
    String? episode,
    int? timestampS,
    String? source,
    String? sourceUrl,
  });
  Future<void> upsertReferenceImage(NewReferenceImagesCompanion image);
  Future<void> deleteReferenceImage(String id);

  // ==========================================================================
  // Place Visits (place_visits)
  // ==========================================================================

  Future<List<PlaceVisit>> getVisitsForPlace(String placeKey);
  Stream<List<PlaceVisit>> watchVisitsForPlace(String placeKey);
  Future<PlaceVisit> addVisit({
    required String placeKey,
    required String date,
    String? tripId,
  });
  Future<void> deleteVisit(String visitId);
}

/// Drift implementation of [PlaceRepository].
class DriftPlaceRepository implements PlaceRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  DriftPlaceRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<Place>> getPlaces({String? visibility}) {
    final query = _db.select(_db.places);
    if (visibility != null) {
      query.where((tbl) => tbl.visibility.equals(visibility));
    }
    return query.get();
  }

  @override
  Stream<List<Place>> watchPlaces({String? visibility}) {
    final query = _db.select(_db.places);
    if (visibility != null) {
      query.where((tbl) => tbl.visibility.equals(visibility));
    }
    return query.watch();
  }

  @override
  Future<List<Place>> getPlacesByLabel(String labelId, {String? visibility}) {
    final query = _db.select(_db.places).join([
      innerJoin(
        _db.placeLabels,
        _db.placeLabels.placeKey.equalsExp(_db.places.placeKey),
      ),
    ])..where(_db.placeLabels.labelId.equals(labelId));

    if (visibility != null) {
      query.where(_db.places.visibility.equals(visibility));
    }

    return query.map((row) => row.readTable(_db.places)).get();
  }

  @override
  Stream<List<Place>> watchPlacesByLabel(String labelId, {String? visibility}) {
    final query = _db.select(_db.places).join([
      innerJoin(
        _db.placeLabels,
        _db.placeLabels.placeKey.equalsExp(_db.places.placeKey),
      ),
    ])..where(_db.placeLabels.labelId.equals(labelId));

    if (visibility != null) {
      query.where(_db.places.visibility.equals(visibility));
    }

    return query.map((row) => row.readTable(_db.places)).watch();
  }

  @override
  Future<Place?> getPlace(String placeKey) {
    return (_db.select(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey))).getSingleOrNull();
  }

  @override
  Stream<Place?> watchPlace(String placeKey) {
    return (_db.select(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey))).watchSingleOrNull();
  }

  @override
  Future<void> upsertPlace(PlacesCompanion place) {
    return _db.into(_db.places).insertOnConflictUpdate(place);
  }

  @override
  Future<void> updatePlace(PlacesCompanion place) {
    return (_db.update(_db.places)
          ..where((tbl) => tbl.placeKey.equals(place.placeKey.value)))
        .write(place.copyWith(updatedAt: Value(DateTime.now())));
  }

  @override
  Future<void> deletePlace(String placeKey) async {
    final place = await getPlace(placeKey);
    final photos = await getPhotosForPlace(placeKey);
    final refImages = await getReferenceImagesForPlace(placeKey);

    final candidatePaths = <String>{
      if (place?.coverLocalPath != null && place!.coverLocalPath!.isNotEmpty)
        place.coverLocalPath!,
      for (final p in photos)
        if (p.localPath.isNotEmpty) p.localPath,
      for (final r in refImages)
        if (r.localPath != null && r.localPath!.isNotEmpty) r.localPath!,
    };

    await (_db.delete(_db.places)
          ..where((tbl) => tbl.placeKey.equals(placeKey)))
        .go();

    for (final path in candidatePaths) {
      await _deleteFileIfUnreferenced(path);
    }
  }

  @override
  Future<Place> createTripOnlyPlace({
    required String name,
    required double lat,
    required double lng,
    String? address,
    String? description,
    String? accessTips,
  }) async {
    return _db.transaction(() async {
      final key = _uuid.v4();
      final companion = PlacesCompanion.insert(
        placeKey: key,
        name: name,
        lat: lat,
        lng: lng,
        address: Value(address),
        description: Value(description),
        accessTips: Value(accessTips),
        visibility: const Value('trip_only'),
      );

      await _db.into(_db.places).insert(companion);
      return (await getPlace(key))!;
    });
  }

  @override
  Future<void> setPlaceVisibility(String placeKey, String visibility) {
    return (_db.update(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey))).write(
      PlacesCompanion(
        visibility: Value(visibility),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================================================
  // Labels
  // ==========================================================================

  @override
  Future<void> attachLabelToPlace(String placeKey, String labelId) {
    return _db.into(_db.placeLabels).insertOnConflictUpdate(
          PlaceLabelsCompanion.insert(
            placeKey: placeKey,
            labelId: labelId,
          ),
        );
  }

  @override
  Future<void> removeLabelFromPlace(String placeKey, String labelId) {
    return (_db.delete(_db.placeLabels)
          ..where((tbl) => tbl.placeKey.equals(placeKey) & tbl.labelId.equals(labelId)))
        .go();
  }

  @override
  Future<List<Label>> getLabelsForPlace(String placeKey) {
    final query = _db.select(_db.labels).join([
      innerJoin(
        _db.placeLabels,
        _db.placeLabels.labelId.equalsExp(_db.labels.id),
      ),
    ])..where(_db.placeLabels.placeKey.equals(placeKey));

    return query.map((row) => row.readTable(_db.labels)).get();
  }

  @override
  Stream<List<Label>> watchLabelsForPlace(String placeKey) {
    final query = _db.select(_db.labels).join([
      innerJoin(
        _db.placeLabels,
        _db.placeLabels.labelId.equalsExp(_db.labels.id),
      ),
    ])..where(_db.placeLabels.placeKey.equals(placeKey));

    return query.map((row) => row.readTable(_db.labels)).watch();
  }

  @override
  Future<Label?> getLabel(String labelId) {
    return (_db.select(_db.labels)..where((tbl) => tbl.id.equals(labelId)))
        .getSingleOrNull();
  }

  @override
  Future<List<Label>> getLabels({String? kind}) {
    final query = _db.select(_db.labels);
    if (kind != null) {
      query.where((tbl) => tbl.kind.equals(kind));
    }
    return query.get();
  }

  @override
  Stream<List<Label>> watchLabels({String? kind}) {
    final query = _db.select(_db.labels);
    if (kind != null) {
      query.where((tbl) => tbl.kind.equals(kind));
    }
    return query.watch();
  }

  @override
  Future<Label> getOrCreateLabel({
    required String kind,
    required String name,
    String? bangumiId,
  }) async {
    return _db.transaction(() async {
      if (kind == 'anime' && bangumiId != null) {
        final byBangumi = await (_db.select(_db.labels)
              ..where((tbl) =>
                  tbl.kind.equals('anime') & tbl.bangumiId.equals(bangumiId))
              ..limit(1))
            .getSingleOrNull();
        if (byBangumi != null) {
          return byBangumi;
        }
        // Check if an anime label with the same name and null bangumiId exists;
        // if so, upgrade it in place rather than creating a duplicate.
        final byNameNoBangumi = await (_db.select(_db.labels)
              ..where((tbl) =>
                  tbl.kind.equals('anime') &
                  tbl.name.equals(name) &
                  tbl.bangumiId.isNull())
              ..limit(1))
            .getSingleOrNull();
        if (byNameNoBangumi != null) {
          await (_db.update(_db.labels)
                ..where((tbl) => tbl.id.equals(byNameNoBangumi.id)))
              .write(LabelsCompanion(bangumiId: Value(bangumiId)));
          return (await getLabel(byNameNoBangumi.id))!;
        }
      } else {
        final existing = await (_db.select(_db.labels)
              ..where((tbl) => tbl.kind.equals(kind) & tbl.name.equals(name))
              ..limit(1))
            .getSingleOrNull();
        if (existing != null) {
          return existing;
        }
      }

      final newId = _uuid.v4();
      final companion = LabelsCompanion.insert(
        id: newId,
        kind: kind,
        name: name,
        bangumiId: Value(bangumiId),
      );

      await _db.into(_db.labels).insert(companion);
      return (await getLabel(newId))!;
    });
  }

  @override
  Future<Label> renameLabel(
    String labelId,
    String newName, {
    String? bangumiId,
  }) async {
    return _db.transaction(() async {
      final current = await getLabel(labelId);
      if (current == null) {
        throw StateError('Label not found: $labelId');
      }

      final effectiveBangumiId = bangumiId ?? current.bangumiId;
      Label? collision;
      if (current.kind == 'anime' && effectiveBangumiId != null) {
        collision = await (_db.select(_db.labels)
              ..where((tbl) =>
                  tbl.kind.equals('anime') &
                  tbl.bangumiId.equals(effectiveBangumiId) &
                  tbl.id.isNotValue(labelId))
              ..limit(1))
            .getSingleOrNull();
      }
      collision ??= await (_db.select(_db.labels)
            ..where((tbl) =>
                tbl.kind.equals(current.kind) &
                tbl.name.equals(newName) &
                tbl.id.isNotValue(labelId))
            ..limit(1))
          .getSingleOrNull();

      if (collision != null) {
        await mergeLabels(sourceLabelId: labelId, targetLabelId: collision.id);
        return (await getLabel(collision.id))!;
      }

      final affectedStopLinks = await (_db.select(_db.stopLabels)
            ..where((tbl) => tbl.labelId.equals(labelId)))
          .get();

      await (_db.update(_db.labels)..where((tbl) => tbl.id.equals(labelId)))
          .write(
        LabelsCompanion(
          name: Value(newName),
          bangumiId: Value(effectiveBangumiId),
        ),
      );
      await _markStopsDirty(affectedStopLinks.map((sl) => sl.stopId));
      return (await getLabel(labelId))!;
    });
  }

  @override
  Future<void> mergeLabels({
    required String sourceLabelId,
    required String targetLabelId,
  }) async {
    if (sourceLabelId == targetLabelId) return;
    await _db.transaction(() async {
      // Re-point place_labels
      final sourcePlaces = await (_db.select(_db.placeLabels)
            ..where((tbl) => tbl.labelId.equals(sourceLabelId)))
          .get();
      for (final pl in sourcePlaces) {
        await _db.into(_db.placeLabels).insertOnConflictUpdate(
              PlaceLabelsCompanion.insert(
                placeKey: pl.placeKey,
                labelId: targetLabelId,
              ),
            );
      }

      // Re-point stop_labels
      final sourceStops = await (_db.select(_db.stopLabels)
            ..where((tbl) => tbl.labelId.equals(sourceLabelId)))
          .get();
      for (final sl in sourceStops) {
        await _db.into(_db.stopLabels).insertOnConflictUpdate(
              StopLabelsCompanion.insert(
                stopId: sl.stopId,
                labelId: targetLabelId,
              ),
            );
      }

      // Re-point reference images animeLabelId
      await (_db.update(_db.newReferenceImages)
            ..where((tbl) => tbl.animeLabelId.equals(sourceLabelId)))
          .write(NewReferenceImagesCompanion(animeLabelId: Value(targetLabelId)));

      // Delete source label (cascades any remaining place_labels / stop_labels)
      await (_db.delete(_db.labels)
            ..where((tbl) => tbl.id.equals(sourceLabelId)))
          .go();

      await _markStopsDirty(sourceStops.map((sl) => sl.stopId));
    });
  }

  @override
  Future<void> deleteLabel(String labelId) async {
    await _db.transaction(() async {
      final affectedStopLinks = await (_db.select(_db.stopLabels)
            ..where((tbl) => tbl.labelId.equals(labelId)))
          .get();
      await (_db.update(_db.newReferenceImages)
            ..where((tbl) => tbl.animeLabelId.equals(labelId)))
          .write(const NewReferenceImagesCompanion(animeLabelId: Value(null)));
      await (_db.delete(_db.labels)..where((tbl) => tbl.id.equals(labelId)))
          .go();
      await _markStopsDirty(affectedStopLinks.map((sl) => sl.stopId));
    });
  }

  Future<void> _markStopsDirty(Iterable<String> stopIds) async {
    final ids = stopIds.toSet().toList();
    if (ids.isEmpty) return;
    await (_db.update(_db.stops)..where((s) => s.id.isIn(ids))).write(
      StopsCompanion(
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value(1),
      ),
    );
  }

  // ==========================================================================
  // Photos
  // ==========================================================================

  @override
  Future<Photo?> getPhoto(String id) {
    return (_db.select(_db.photos)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<Photo>> getPhotosForPlace(String placeKey) {
    return (_db.select(_db.photos)
          ..where((tbl) => tbl.placeKey.equals(placeKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  @override
  Stream<List<Photo>> watchPhotosForPlace(String placeKey) {
    return (_db.select(_db.photos)
          ..where((tbl) => tbl.placeKey.equals(placeKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  @override
  Future<List<Photo>> getPhotosForTrip(String tripId) {
    return (_db.select(_db.photos)
          ..where((tbl) => tbl.tripId.equals(tripId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  @override
  Stream<List<Photo>> watchPhotosForTrip(String tripId) {
    return (_db.select(_db.photos)
          ..where((tbl) => tbl.tripId.equals(tripId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  @override
  Future<Photo> addPhoto({
    required String placeKey,
    required String localPath,
    String? tripId,
    String kind = 'original',
    String? derivedFromId,
    String? referenceImageId,
    String? remoteUrl,
    bool isShared = false,
    DateTime? takenAt,
  }) async {
    return _db.transaction(() async {
      final id = _uuid.v4();
      await _db.into(_db.photos).insert(
            PhotosCompanion.insert(
              id: id,
              placeKey: placeKey,
              tripId: Value(tripId),
              kind: Value(kind),
              derivedFromId: Value(derivedFromId),
              referenceImageId: Value(referenceImageId),
              localPath: localPath,
              remoteUrl: Value(remoteUrl),
              isShared: Value(isShared),
              takenAt: Value(takenAt),
            ),
          );
      return (await getPhoto(id))!;
    });
  }

  @override
  Future<void> upsertPhoto(PhotosCompanion photo) {
    return _db.into(_db.photos).insertOnConflictUpdate(photo);
  }

  @override
  Future<void> updatePhoto(PhotosCompanion photo) {
    return (_db.update(_db.photos)
          ..where((tbl) => tbl.id.equals(photo.id.value)))
        .write(photo);
  }

  @override
  Future<void> deletePhoto(String id) async {
    final photo = await getPhoto(id);
    await _db.transaction(() async {
      await (_db.update(_db.photos)
            ..where((tbl) => tbl.derivedFromId.equals(id)))
          .write(const PhotosCompanion(derivedFromId: Value(null)));
      await (_db.delete(_db.photos)..where((tbl) => tbl.id.equals(id))).go();
    });
    if (photo != null && photo.localPath.isNotEmpty) {
      await _deleteFileIfUnreferenced(photo.localPath);
    }
  }

  // ==========================================================================
  // Reference Images (v10_reference_images)
  // ==========================================================================

  @override
  Future<NewReferenceImage?> getReferenceImage(String id) {
    return (_db.select(_db.newReferenceImages)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<NewReferenceImage>> getReferenceImagesForPlace(String placeKey) {
    return (_db.select(_db.newReferenceImages)
          ..where((tbl) => tbl.placeKey.equals(placeKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  @override
  Stream<List<NewReferenceImage>> watchReferenceImagesForPlace(String placeKey) {
    return (_db.select(_db.newReferenceImages)
          ..where((tbl) => tbl.placeKey.equals(placeKey))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  @override
  Future<NewReferenceImage> addReferenceImage({
    String? placeKey,
    String? stopId,
    String? localPath,
    String? remoteUrl,
    String? animeLabelId,
    String? episode,
    int? timestampS,
    String? source,
    String? sourceUrl,
  }) async {
    return _db.transaction(() async {
      final id = _uuid.v4();
      await _db.into(_db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: id,
              placeKey: Value(placeKey),
              stopId: Value(stopId),
              localPath: Value(localPath),
              remoteUrl: Value(remoteUrl),
              animeLabelId: Value(animeLabelId),
              episode: Value(episode),
              timestampS: Value(timestampS),
              source: Value(source),
              sourceUrl: Value(sourceUrl),
            ),
          );
      return (await getReferenceImage(id))!;
    });
  }

  @override
  Future<void> upsertReferenceImage(NewReferenceImagesCompanion image) {
    return _db.into(_db.newReferenceImages).insertOnConflictUpdate(image);
  }

  @override
  Future<void> deleteReferenceImage(String id) async {
    final img = await getReferenceImage(id);
    await _db.transaction(() async {
      await (_db.update(_db.photos)
            ..where((tbl) => tbl.referenceImageId.equals(id)))
          .write(const PhotosCompanion(referenceImageId: Value(null)));
      if (img?.stopId != null) {
        await _markStopsDirty([img!.stopId!]);
      }
      await (_db.delete(_db.newReferenceImages)
            ..where((tbl) => tbl.id.equals(id)))
          .go();
    });
    if (img?.localPath != null && img!.localPath!.isNotEmpty) {
      await _deleteFileIfUnreferenced(img.localPath!);
    }
  }

  Future<void> _deleteFileIfUnreferenced(String path) async {
    if (path.isEmpty) return;
    final placeRef = await (_db.select(_db.places)
          ..where((p) => p.coverLocalPath.equals(path))
          ..limit(1))
        .getSingleOrNull();
    if (placeRef != null) return;

    final photoRef = await (_db.select(_db.photos)
          ..where((p) => p.localPath.equals(path))
          ..limit(1))
        .getSingleOrNull();
    if (photoRef != null) return;

    final refImgRef = await (_db.select(_db.newReferenceImages)
          ..where((r) => r.localPath.equals(path))
          ..limit(1))
        .getSingleOrNull();
    if (refImgRef != null) return;

    if (kIsWeb || isRemoteOrMemoryUri(path)) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // ==========================================================================
  // Place Visits (place_visits)
  // ==========================================================================

  @override
  Future<List<PlaceVisit>> getVisitsForPlace(String placeKey) {
    return (_db.select(_db.placeVisits)
          ..where((tbl) => tbl.placeKey.equals(placeKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .get();
  }

  @override
  Stream<List<PlaceVisit>> watchVisitsForPlace(String placeKey) {
    return (_db.select(_db.placeVisits)
          ..where((tbl) => tbl.placeKey.equals(placeKey))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .watch();
  }

  @override
  Future<PlaceVisit> addVisit({
    required String placeKey,
    required String date,
    String? tripId,
  }) async {
    return _db.transaction(() async {
      final id = _uuid.v4();
      await _db.into(_db.placeVisits).insert(
            PlaceVisitsCompanion.insert(
              id: id,
              placeKey: placeKey,
              date: date,
              tripId: Value(tripId),
            ),
          );
      return await (_db.select(_db.placeVisits)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingle();
    });
  }

  @override
  Future<void> deleteVisit(String visitId) {
    return (_db.delete(_db.placeVisits)
          ..where((tbl) => tbl.id.equals(visitId)))
        .go();
  }
}
