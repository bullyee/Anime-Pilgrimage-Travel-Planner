import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';

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

  /// Attaches a label to a place.
  Future<void> attachLabelToPlace(String placeKey, String labelId);

  /// Detaches a label from a place.
  Future<void> removeLabelFromPlace(String placeKey, String labelId);

  /// Retrieves all labels attached to a place.
  Future<List<Label>> getLabelsForPlace(String placeKey);

  /// Watches all labels attached to a place.
  Stream<List<Label>> watchLabelsForPlace(String placeKey);

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
  Future<Place> createTripOnlyPlace({
    required String name,
    required double lat,
    required double lng,
    String? address,
    String? description,
    String? accessTips,
  }) async {
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
    final query = _db.select(_db.labels)..where((tbl) => tbl.kind.equals(kind));

    if (kind == 'anime' && bangumiId != null) {
      query.where((tbl) => tbl.bangumiId.equals(bangumiId));
    } else {
      query.where((tbl) => tbl.name.equals(name));
    }

    final existing = await query.getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    final newId = _uuid.v4();
    final companion = LabelsCompanion.insert(
      id: newId,
      kind: kind,
      name: name,
      bangumiId: Value(bangumiId),
    );

    await _db.into(_db.labels).insert(companion);
    return (await (_db.select(_db.labels)..where((tbl) => tbl.id.equals(newId))).getSingle());
  }
}

