import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../library/repositories/place_repository.dart';

/// Repository interface for managing shared trips, day blocks, stops, and schedule items.
abstract class TripRepository {
  // Trips
  Future<Trip?> getTrip(String tripId);
  Stream<Trip?> watchTrip(String tripId);
  Future<List<Trip>> getTrips();
  Stream<List<Trip>> watchTrips();
  Future<Trip> createTrip({
    required String title,
    String? description,
    required String ownerId,
    String? startDate,
    int dayCount = 1,
  });
  Future<void> updateTrip(TripsCompanion trip);
  Future<void> deleteTrip(String tripId);

  // Day Blocks
  Future<List<TripDay>> getDaysForTrip(String tripId);
  Stream<List<TripDay>> watchDaysForTrip(String tripId);
  Future<TripDay> addDayBlock(String tripId, {String? title, String? pinnedDate});
  Future<void> updateDayBlock(TripDaysCompanion day);
  Future<void> deleteDayBlock(String dayId);
  Future<void> swapDayBlocks(String dayIdA, String dayIdB);
  Future<void> pinDayBlockDate(String dayId, String? pinnedDate);
  Future<void> reorderDayBlock(String dayId, String newSortKey);

  // Stops
  Future<Stop?> getStop(String stopId);
  Stream<Stop?> watchStop(String stopId);
  Future<List<Stop>> getStopsForTrip(String tripId);
  Stream<List<Stop>> watchStopsForTrip(String tripId);
  Future<Stop> addPlaceToTrip({
    required String tripId,
    required String placeKey,
    required String addedBy,
    String? area,
  });
  Future<Stop> createTripOnlySpot({
    required String tripId,
    required String name,
    required double lat,
    required double lng,
    required String addedBy,
    String? address,
    String? description,
    String? accessTips,
    String? area,
  });
  Future<void> updateStop(StopsCompanion stop);
  Future<void> setStopsArea(List<String> stopIds, String? area);
  Future<void> deleteStop(String stopId);

  // Stop Labels & Reference Images
  Future<List<Label>> getLabelsForStop(String stopId);
  Stream<List<Label>> watchLabelsForStop(String stopId);
  Future<void> attachLabelToStop(String stopId, String labelId);
  Future<void> removeLabelFromStop(String stopId, String labelId);
  Future<List<NewReferenceImage>> getReferenceImagesForStop(String stopId);
  Stream<List<NewReferenceImage>> watchReferenceImagesForStop(String stopId);

  // Schedule Items
  Future<List<ScheduleItem>> getScheduleItemsForTrip(String tripId);
  Stream<List<ScheduleItem>> watchScheduleItemsForTrip(String tripId);
  Future<List<ScheduleItem>> getScheduleItemsForDay(String dayId);
  Stream<List<ScheduleItem>> watchScheduleItemsForDay(String dayId);
  Future<ScheduleItem> scheduleStop({
    required String tripId,
    required String stopId,
    required String dayId,
    String? sortKey,
    int stayMinutes = 60,
    int transitMinutes = 0,
    int? fixedTime,
  });
  Future<List<ScheduleItem>> scheduleStops({
    required String tripId,
    required String dayId,
    required List<String> stopIds,
    List<String>? sortKeys,
    int stayMinutes = 60,
    int transitMinutes = 0,
  });
  Future<void> updateScheduleItem(ScheduleItemsCompanion item);
  Future<void> reorderScheduleItem({
    required String itemId,
    required String newSortKey,
    String? targetDayId,
  });
  Future<void> moveScheduleItems({
    required List<String> itemIds,
    required List<String> newSortKeys,
    String? dayId,
    String? targetDayId,
  });
  Future<void> updateScheduleItemStatus({
    required String itemId,
    required String status,
  });
  Future<void> deleteScheduleItem(String itemId);
  Future<void> deleteScheduleItems(List<String> itemIds);

  // Collaborator Update Tracking (Phase 2)
  Future<DateTime?> getLatestCollaboratorUpdate(String tripId, String currentUserId);
  Stream<DateTime?> watchLatestCollaboratorUpdate(String tripId, String currentUserId);
}

/// Drift implementation of [TripRepository].
class DriftTripRepository implements TripRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  final String _currentUserId;
  final PlaceRepository _placeRepository;
  int _lastTimestampMs = 0;

  DriftTripRepository(
    this._db, [
    Uuid? uuid,
    String currentUserId = 'u',
    PlaceRepository? placeRepository,
  ])  : _uuid = uuid ?? const Uuid(),
        _currentUserId = currentUserId,
        _placeRepository = placeRepository ?? DriftPlaceRepository(_db, uuid);

  /// Returns a monotonically increasing millisecond-precision timestamp so rapid
  /// sequential edits within the same wall-clock millisecond maintain strict LWW order.
  DateTime _now() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextMs = nowMs > _lastTimestampMs ? nowMs : _lastTimestampMs + 1;
    _lastTimestampMs = nextMs;
    return DateTime.fromMillisecondsSinceEpoch(nextMs);
  }

  // ==========================================================================
  // Trips
  // ==========================================================================

  @override
  Future<Trip?> getTrip(String tripId) async {
    final trip = await (_db.select(_db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
    if (trip == null || trip.deletedAt != null) return null;
    return trip;
  }

  @override
  Stream<Trip?> watchTrip(String tripId) {
    return (_db.select(_db.trips)..where((tbl) => tbl.id.equals(tripId))).watchSingleOrNull().map((trip) {
      if (trip == null || trip.deletedAt != null) return null;
      return trip;
    });
  }

  @override
  Future<List<Trip>> getTrips() {
    return (_db.select(_db.trips)..where((tbl) => tbl.deletedAt.isNull())).get();
  }

  @override
  Stream<List<Trip>> watchTrips() {
    return (_db.select(_db.trips)..where((tbl) => tbl.deletedAt.isNull())).watch();
  }

  @override
  Future<Trip> createTrip({
    required String title,
    String? description,
    required String ownerId,
    String? startDate,
    int dayCount = 1,
  }) async {
    return _db.transaction(() async {
      final now = _now();
      final tripId = _uuid.v4();
      final companion = TripsCompanion.insert(
        id: tripId,
        title: title,
        description: Value(description),
        ownerId: ownerId,
        startDate: Value(startDate),
        dayCount: Value(dayCount),
        updatedAt: Value(now),
        updatedBy: Value(ownerId),
        syncStatus: const Value(1),
      );

      await _db.into(_db.trips).insert(companion);

      // Create initial day blocks
      final sortKeys = FractionalIndexUtil.generateNKeysBetween(null, null, dayCount);
      for (int i = 0; i < dayCount; i++) {
        await _db.into(_db.tripDays).insert(
              TripDaysCompanion.insert(
                id: _uuid.v4(),
                tripId: tripId,
                sortKey: sortKeys[i],
                updatedAt: Value(now),
                updatedBy: Value(ownerId),
                syncStatus: const Value(1),
              ),
            );
      }

      return (await getTrip(tripId))!;
    });
  }

  @override
  Future<void> updateTrip(TripsCompanion trip) {
    final now = _now();
    return (_db.update(_db.trips)..where((tbl) => tbl.id.equals(trip.id.value))).write(
      trip.copyWith(
        updatedAt: Value(now),
        updatedBy: trip.updatedBy.present ? trip.updatedBy : Value(_currentUserId),
        syncStatus: const Value(1),
      ),
    );
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    final now = _now();
    await _db.transaction(() async {
      await (_db.update(_db.trips)..where((tbl) => tbl.id.equals(tripId))).write(
        TripsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      await (_db.update(_db.tripDays)..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())).write(
        TripDaysCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      await (_db.update(_db.stops)..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())).write(
        StopsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())).write(
        ScheduleItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  // ==========================================================================
  // Day Blocks
  // ==========================================================================

  @override
  Future<List<TripDay>> getDaysForTrip(String tripId) {
    return (_db.select(_db.tripDays)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortKey),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .get();
  }

  @override
  Stream<List<TripDay>> watchDaysForTrip(String tripId) {
    return (_db.select(_db.tripDays)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortKey),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .watch();
  }

  @override
  Future<TripDay> addDayBlock(String tripId, {String? title, String? pinnedDate}) async {
    return _db.transaction(() async {
      final existingDays = await getDaysForTrip(tripId);
      final existingKeys = existingDays.map((d) => d.sortKey).toList();
      final newSortKey = FractionalIndexUtil.append(existingKeys);

      final dayId = _uuid.v4();
      if (pinnedDate != null) {
        final trip = await getTrip(tripId);
        final startDate = trip?.startDate != null ? DateTime.tryParse(trip!.startDate!) : null;
        final updatedBlocks = [
          for (final d in existingDays)
            DayBlockInfo(
              id: d.id,
              sortKey: d.sortKey,
              pinnedDate: d.pinnedDate != null ? DateTime.parse(d.pinnedDate!) : null,
            ),
          DayBlockInfo(
            id: dayId,
            sortKey: newSortKey,
            pinnedDate: DateTime.parse(pinnedDate),
          ),
        ];
        ScheduleLogicEngine.validatePinnedDates(
          updatedBlocks,
          startDate: startDate,
          dayCount: trip?.dayCount,
        );
      }

      final companion = TripDaysCompanion.insert(
        id: dayId,
        tripId: tripId,
        sortKey: newSortKey,
        title: Value(title),
        pinnedDate: Value(pinnedDate),
        updatedAt: Value(_now()),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      );

      await _db.into(_db.tripDays).insert(companion);
      return await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingle();
    });
  }

  @override
  Future<void> updateDayBlock(TripDaysCompanion day) async {
    await _db.transaction(() async {
      final dayId = day.id.value;
      final current = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingle();
      if (day.pinnedDate.present || day.sortKey.present) {
        final trip = await getTrip(current.tripId);
        final startDate = trip?.startDate != null ? DateTime.tryParse(trip!.startDate!) : null;
        final allDays = await getDaysForTrip(current.tripId);
        final newPinnedStr = day.pinnedDate.present ? day.pinnedDate.value : current.pinnedDate;
        final newSortKey = day.sortKey.present ? day.sortKey.value : current.sortKey;
        final updatedBlocks = allDays.map((d) {
          if (d.id == dayId) {
            return DayBlockInfo(
              id: d.id,
              sortKey: newSortKey,
              pinnedDate: newPinnedStr != null ? DateTime.parse(newPinnedStr) : null,
            );
          }
          return DayBlockInfo(
            id: d.id,
            sortKey: d.sortKey,
            pinnedDate: d.pinnedDate != null ? DateTime.parse(d.pinnedDate!) : null,
          );
        }).toList();
        ScheduleLogicEngine.validatePinnedDates(
          updatedBlocks,
          startDate: startDate,
          dayCount: trip?.dayCount,
        );
      }

      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
        day.copyWith(
          updatedAt: Value(_now()),
          updatedBy: day.updatedBy.present ? day.updatedBy : Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> deleteDayBlock(String dayId) async {
    final now = _now();
    await _db.transaction(() async {
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
        TripDaysCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.dayId.equals(dayId) & tbl.deletedAt.isNull())).write(
        ScheduleItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> swapDayBlocks(String dayIdA, String dayIdB) async {
    await _db.transaction(() async {
      final dayA = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdA))).getSingle();
      final dayB = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdB))).getSingle();

      final now = _now();
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdA))).write(
        TripDaysCompanion(
          sortKey: Value(dayB.sortKey),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdB))).write(
        TripDaysCompanion(
          sortKey: Value(dayA.sortKey),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> pinDayBlockDate(String dayId, String? pinnedDate) async {
    await _db.transaction(() async {
      final targetDay = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingle();
      final trip = await getTrip(targetDay.tripId);
      final startDate = trip?.startDate != null ? DateTime.tryParse(trip!.startDate!) : null;
      final allDays = await getDaysForTrip(targetDay.tripId);

      // Validate that pinned dates strictly increase along sort order and against computed dates
      final updatedBlocks = allDays.map((d) {
        if (d.id == dayId) {
          return DayBlockInfo(
            id: d.id,
            sortKey: d.sortKey,
            pinnedDate: pinnedDate != null ? DateTime.parse(pinnedDate) : null,
          );
        }
        return DayBlockInfo(
          id: d.id,
          sortKey: d.sortKey,
          pinnedDate: d.pinnedDate != null ? DateTime.parse(d.pinnedDate!) : null,
        );
      }).toList();

      ScheduleLogicEngine.validatePinnedDates(
        updatedBlocks,
        startDate: startDate,
        dayCount: trip?.dayCount,
      );

      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
        TripDaysCompanion(
          pinnedDate: Value(pinnedDate),
          updatedAt: Value(_now()),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> reorderDayBlock(String dayId, String newSortKey) async {
    await _db.transaction(() async {
      final targetDay = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingle();
      final trip = await getTrip(targetDay.tripId);
      final startDate = trip?.startDate != null ? DateTime.tryParse(trip!.startDate!) : null;
      final allDays = await getDaysForTrip(targetDay.tripId);

      final hasAnyPin = allDays.any((d) => d.pinnedDate != null);
      if (hasAnyPin) {
        final updatedBlocks = allDays.map((d) {
          return DayBlockInfo(
            id: d.id,
            sortKey: d.id == dayId ? newSortKey : d.sortKey,
            pinnedDate: d.pinnedDate != null ? DateTime.parse(d.pinnedDate!) : null,
          );
        }).toList();
        ScheduleLogicEngine.validatePinnedDates(
          updatedBlocks,
          startDate: startDate,
          dayCount: trip?.dayCount,
        );
      }

      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
        TripDaysCompanion(
          sortKey: Value(newSortKey),
          updatedAt: Value(_now()),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  // ==========================================================================
  // Stops
  // ==========================================================================

  @override
  Future<Stop?> getStop(String stopId) {
    return (_db.select(_db.stops)..where((tbl) => tbl.id.equals(stopId))).getSingleOrNull();
  }

  @override
  Stream<Stop?> watchStop(String stopId) {
    return (_db.select(_db.stops)..where((tbl) => tbl.id.equals(stopId))).watchSingleOrNull();
  }

  @override
  Future<List<Stop>> getStopsForTrip(String tripId) {
    return (_db.select(_db.stops)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.createdAt),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .get();
  }

  @override
  Stream<List<Stop>> watchStopsForTrip(String tripId) {
    return (_db.select(_db.stops)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.createdAt),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .watch();
  }

  @override
  Future<Stop> addPlaceToTrip({
    required String tripId,
    required String placeKey,
    required String addedBy,
    String? area,
  }) async {
    return _db.transaction(() async {
      final place = await (_db.select(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey))).getSingle();
      final stopId = _uuid.v4();
      final now = _now();

      // 1. Copy place facts into Stop
      final stopCompanion = StopsCompanion.insert(
        id: stopId,
        tripId: tripId,
        placeKey: placeKey,
        name: place.name,
        lat: place.lat,
        lng: place.lng,
        description: Value(place.description),
        address: Value(place.address),
        businessHours: Value(place.businessHours),
        contactInfo: Value(place.contactInfo),
        accessTips: Value(place.accessTips),
        links: Value(place.links),
        coverLocalPath: Value(place.coverLocalPath),
        coverRemoteUrl: Value(place.coverRemoteUrl),
        source: Value(place.source),
        sourceUrl: Value(place.sourceUrl),
        area: Value(area),
        addedBy: addedBy,
        updatedAt: Value(now),
        updatedBy: Value(addedBy),
        syncStatus: const Value(1),
      );

      await _db.into(_db.stops).insert(stopCompanion);

      // 2. Copy place reference images to the stop
      final refImages = await (_db.select(_db.newReferenceImages)..where((tbl) => tbl.placeKey.equals(placeKey))).get();
      for (final img in refImages) {
        await _db.into(_db.newReferenceImages).insert(
              NewReferenceImagesCompanion.insert(
                id: _uuid.v4(),
                placeKey: const Value(null),
                stopId: Value(stopId),
                localPath: Value(img.localPath),
                remoteUrl: Value(img.remoteUrl),
                animeLabelId: Value(img.animeLabelId),
                episode: Value(img.episode),
                timestampS: Value(img.timestampS),
                source: Value(img.source),
                sourceUrl: Value(img.sourceUrl),
              ),
            );
      }

      // 3. Copy place labels to stop_labels
      final placeLabels = await (_db.select(_db.placeLabels)..where((tbl) => tbl.placeKey.equals(placeKey))).get();
      for (final pl in placeLabels) {
        await _db.into(_db.stopLabels).insertOnConflictUpdate(
              StopLabelsCompanion.insert(
                stopId: stopId,
                labelId: pl.labelId,
              ),
            );
      }

      return await (_db.select(_db.stops)..where((tbl) => tbl.id.equals(stopId))).getSingle();
    });
  }

  @override
  Future<Stop> createTripOnlySpot({
    required String tripId,
    required String name,
    required double lat,
    required double lng,
    required String addedBy,
    String? address,
    String? description,
    String? accessTips,
    String? area,
  }) async {
    return _db.transaction(() async {
      final place = await _placeRepository.createTripOnlyPlace(
        name: name,
        lat: lat,
        lng: lng,
        address: address,
        description: description,
        accessTips: accessTips,
      );

      return addPlaceToTrip(
        tripId: tripId,
        placeKey: place.placeKey,
        addedBy: addedBy,
        area: area,
      );
    });
  }

  @override
  Future<void> updateStop(StopsCompanion stop) {
    final now = _now();
    return (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stop.id.value))).write(
      stop.copyWith(
        updatedAt: Value(now),
        updatedBy: stop.updatedBy.present ? stop.updatedBy : Value(_currentUserId),
        syncStatus: const Value(1),
      ),
    );
  }

  @override
  Future<void> setStopsArea(List<String> stopIds, String? area) async {
    if (stopIds.isEmpty) return;
    final normalizedArea = (area != null && area.trim().isNotEmpty) ? area.trim() : null;
    await _db.transaction(() async {
      final now = _now();
      await (_db.update(_db.stops)
            ..where((tbl) => tbl.id.isIn(stopIds) & tbl.deletedAt.isNull()))
          .write(
        StopsCompanion(
          area: Value(normalizedArea),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> deleteStop(String stopId) async {
    final now = _now();
    await _db.transaction(() async {
      await (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stopId))).write(
        StopsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.stopId.equals(stopId) & tbl.deletedAt.isNull())).write(
        ScheduleItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  // ==========================================================================
  // Stop Labels & Reference Images
  // ==========================================================================

  @override
  Future<List<Label>> getLabelsForStop(String stopId) {
    final query = _db.select(_db.labels).join([
      innerJoin(
        _db.stopLabels,
        _db.stopLabels.labelId.equalsExp(_db.labels.id),
      ),
    ])..where(_db.stopLabels.stopId.equals(stopId));

    return query.map((row) => row.readTable(_db.labels)).get();
  }

  @override
  Stream<List<Label>> watchLabelsForStop(String stopId) {
    final query = _db.select(_db.labels).join([
      innerJoin(
        _db.stopLabels,
        _db.stopLabels.labelId.equalsExp(_db.labels.id),
      ),
    ])..where(_db.stopLabels.stopId.equals(stopId));

    return query.map((row) => row.readTable(_db.labels)).watch();
  }

  @override
  Future<void> attachLabelToStop(String stopId, String labelId) async {
    final now = _now();
    await _db.transaction(() async {
      await _db.into(_db.stopLabels).insertOnConflictUpdate(
            StopLabelsCompanion.insert(
              stopId: stopId,
              labelId: labelId,
            ),
          );
      await (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stopId))).write(
        StopsCompanion(
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> removeLabelFromStop(String stopId, String labelId) async {
    final now = _now();
    await _db.transaction(() async {
      await (_db.delete(_db.stopLabels)
            ..where((tbl) => tbl.stopId.equals(stopId) & tbl.labelId.equals(labelId)))
          .go();
      await (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stopId))).write(
        StopsCompanion(
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<List<NewReferenceImage>> getReferenceImagesForStop(String stopId) {
    return (_db.select(_db.newReferenceImages)
          ..where((tbl) => tbl.stopId.equals(stopId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  @override
  Stream<List<NewReferenceImage>> watchReferenceImagesForStop(String stopId) {
    return (_db.select(_db.newReferenceImages)
          ..where((tbl) => tbl.stopId.equals(stopId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  // ==========================================================================
  // Schedule Items
  // ==========================================================================

  @override
  Future<List<ScheduleItem>> getScheduleItemsForTrip(String tripId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortKey),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .get();
  }

  @override
  Stream<List<ScheduleItem>> watchScheduleItemsForTrip(String tripId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortKey),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .watch();
  }

  @override
  Future<List<ScheduleItem>> getScheduleItemsForDay(String dayId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.dayId.equals(dayId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortKey),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .get();
  }

  @override
  Stream<List<ScheduleItem>> watchScheduleItemsForDay(String dayId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.dayId.equals(dayId) & tbl.deletedAt.isNull())
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.sortKey),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .watch();
  }

  @override
  Future<ScheduleItem> scheduleStop({
    required String tripId,
    required String stopId,
    required String dayId,
    String? sortKey,
    int stayMinutes = 60,
    int transitMinutes = 0,
    int? fixedTime,
  }) async {
    return _db.transaction(() async {
      String computedSortKey = sortKey ?? '';
      if (computedSortKey.isEmpty) {
        final existingItems = await getScheduleItemsForDay(dayId);
        final existingKeys = existingItems.map((i) => i.sortKey).toList();
        computedSortKey = FractionalIndexUtil.append(existingKeys);
      }

      final itemId = _uuid.v4();
      final companion = ScheduleItemsCompanion.insert(
        id: itemId,
        tripId: tripId,
        stopId: stopId,
        dayId: dayId,
        sortKey: computedSortKey,
        stayMinutes: Value(stayMinutes),
        transitMinutes: Value(transitMinutes),
        fixedTime: Value(fixedTime),
        status: const Value('planned'),
        updatedAt: Value(_now()),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      );

      await _db.into(_db.scheduleItems).insert(companion);
      return await (_db.select(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).getSingle();
    });
  }

  @override
  Future<List<ScheduleItem>> scheduleStops({
    required String tripId,
    required String dayId,
    required List<String> stopIds,
    List<String>? sortKeys,
    int stayMinutes = 60,
    int transitMinutes = 0,
  }) async {
    if (stopIds.isEmpty) return const [];
    if (sortKeys != null && sortKeys.length != stopIds.length) {
      throw ArgumentError.value(
        sortKeys.length,
        'sortKeys',
        'Must match stopIds.length (${stopIds.length})',
      );
    }

    return _db.transaction(() async {
      final List<String> resolvedSortKeys;
      if (sortKeys != null) {
        resolvedSortKeys = sortKeys;
      } else {
        final existingItems = await getScheduleItemsForDay(dayId);
        final lastSortKey = existingItems.isEmpty ? null : existingItems.last.sortKey;
        resolvedSortKeys = FractionalIndexUtil.generateNKeysBetween(
          lastSortKey,
          null,
          stopIds.length,
        );
      }

      final now = _now();
      final createdIds = <String>[];
      for (int i = 0; i < stopIds.length; i++) {
        final itemId = _uuid.v4();
        createdIds.add(itemId);
        await _db.into(_db.scheduleItems).insert(
              ScheduleItemsCompanion.insert(
                id: itemId,
                tripId: tripId,
                stopId: stopIds[i],
                dayId: dayId,
                sortKey: resolvedSortKeys[i],
                stayMinutes: Value(stayMinutes),
                transitMinutes: Value(transitMinutes),
                status: const Value('planned'),
                updatedAt: Value(now),
                updatedBy: Value(_currentUserId),
                syncStatus: const Value(1),
              ),
            );
      }

      final inserted = await (_db.select(_db.scheduleItems)
            ..where((tbl) => tbl.id.isIn(createdIds)))
          .get();
      final byId = {for (final item in inserted) item.id: item};
      return [for (final id in createdIds) byId[id]!];
    });
  }

  @override
  Future<void> updateScheduleItem(ScheduleItemsCompanion item) {
    final now = _now();
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(item.id.value))).write(
      item.copyWith(
        updatedAt: Value(now),
        updatedBy: item.updatedBy.present ? item.updatedBy : Value(_currentUserId),
        syncStatus: const Value(1),
      ),
    );
  }

  @override
  Future<void> reorderScheduleItem({
    required String itemId,
    required String newSortKey,
    String? targetDayId,
  }) {
    final now = _now();
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
      ScheduleItemsCompanion(
        sortKey: Value(newSortKey),
        dayId: targetDayId != null ? Value(targetDayId) : const Value.absent(),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ),
    );
  }

  @override
  Future<void> moveScheduleItems({
    required List<String> itemIds,
    required List<String> newSortKeys,
    String? dayId,
    String? targetDayId,
  }) async {
    if (itemIds.length != newSortKeys.length) {
      throw ArgumentError.value(
        newSortKeys.length,
        'newSortKeys',
        'Must match itemIds.length (${itemIds.length})',
      );
    }
    if (itemIds.isEmpty) return;

    final resolvedDayId = dayId ?? targetDayId;
    await _db.transaction(() async {
      final now = _now();
      for (int i = 0; i < itemIds.length; i++) {
        await (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemIds[i]))).write(
          ScheduleItemsCompanion(
            sortKey: Value(newSortKeys[i]),
            dayId: resolvedDayId != null ? Value(resolvedDayId) : const Value.absent(),
            updatedAt: Value(now),
            updatedBy: Value(_currentUserId),
            syncStatus: const Value(1),
          ),
        );
      }
    });
  }

  @override
  Future<void> updateScheduleItemStatus({
    required String itemId,
    required String status,
  }) {
    final now = _now();
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
      ScheduleItemsCompanion(
        status: Value(status),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ),
    );
  }

  @override
  Future<void> deleteScheduleItem(String itemId) {
    final now = _now();
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
      ScheduleItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ),
    );
  }

  @override
  Future<void> deleteScheduleItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    await _db.transaction(() async {
      final now = _now();
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.isIn(itemIds))).write(
        ScheduleItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<DateTime?> getLatestCollaboratorUpdate(String tripId, String currentUserId) async {
    final effectiveUser = currentUserId.trim();
    final row = await _db.customSelect(
      '''
      SELECT MAX(latest) as max_updated_at FROM (
        SELECT MAX(updated_at) as latest FROM trips WHERE id = ? AND updated_by IS NOT NULL AND updated_by != ?
        UNION ALL
        SELECT MAX(updated_at) as latest FROM trip_days WHERE trip_id = ? AND updated_by IS NOT NULL AND updated_by != ?
        UNION ALL
        SELECT MAX(updated_at) as latest FROM stops WHERE trip_id = ? AND updated_by IS NOT NULL AND updated_by != ?
        UNION ALL
        SELECT MAX(updated_at) as latest FROM schedule_items WHERE trip_id = ? AND updated_by IS NOT NULL AND updated_by != ?
      )
      ''',
      variables: [
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
      ],
      readsFrom: {_db.trips, _db.tripDays, _db.stops, _db.scheduleItems},
    ).getSingleOrNull();

    final ms = row?.readNullable<int>('max_updated_at');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Stream<DateTime?> watchLatestCollaboratorUpdate(String tripId, String currentUserId) {
    final effectiveUser = currentUserId.trim();
    return _db.customSelect(
      '''
      SELECT MAX(latest) as max_updated_at FROM (
        SELECT MAX(updated_at) as latest FROM trips WHERE id = ? AND updated_by IS NOT NULL AND updated_by != ?
        UNION ALL
        SELECT MAX(updated_at) as latest FROM trip_days WHERE trip_id = ? AND updated_by IS NOT NULL AND updated_by != ?
        UNION ALL
        SELECT MAX(updated_at) as latest FROM stops WHERE trip_id = ? AND updated_by IS NOT NULL AND updated_by != ?
        UNION ALL
        SELECT MAX(updated_at) as latest FROM schedule_items WHERE trip_id = ? AND updated_by IS NOT NULL AND updated_by != ?
      )
      ''',
      variables: [
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
        Variable<String>(tripId),
        Variable<String>(effectiveUser),
      ],
      readsFrom: {_db.trips, _db.tripDays, _db.stops, _db.scheduleItems},
    ).watchSingleOrNull().map((row) {
      final ms = row?.readNullable<int>('max_updated_at');
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    });
  }
}

