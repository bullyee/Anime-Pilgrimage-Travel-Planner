import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../../../core/utils/schedule_logic.dart';

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
  Future<void> swapDayBlocks(String dayIdA, String dayIdB);
  Future<void> pinDayBlockDate(String dayId, String? pinnedDate);
  Future<void> reorderDayBlock(String dayId, String newSortKey);

  // Stops
  Future<List<Stop>> getStopsForTrip(String tripId);
  Stream<List<Stop>> watchStopsForTrip(String tripId);
  Future<Stop> addPlaceToTrip({
    required String tripId,
    required String placeKey,
    required String addedBy,
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
  });
  Future<void> deleteStop(String stopId);

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
  Future<void> reorderScheduleItem({
    required String itemId,
    required String newSortKey,
    String? targetDayId,
  });
  Future<void> updateScheduleItemStatus({
    required String itemId,
    required String status,
  });
  Future<void> deleteScheduleItem(String itemId);
}

/// Drift implementation of [TripRepository].
class DriftTripRepository implements TripRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  DriftTripRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  // ==========================================================================
  // Trips
  // ==========================================================================

  @override
  Future<Trip?> getTrip(String tripId) {
    return (_db.select(_db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
  }

  @override
  Stream<Trip?> watchTrip(String tripId) {
    return (_db.select(_db.trips)..where((tbl) => tbl.id.equals(tripId))).watchSingleOrNull();
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
    final tripId = _uuid.v4();
    final companion = TripsCompanion.insert(
      id: tripId,
      title: title,
      description: Value(description),
      ownerId: ownerId,
      startDate: Value(startDate),
      dayCount: Value(dayCount),
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
            ),
          );
    }

    return (await getTrip(tripId))!;
  }

  @override
  Future<void> updateTrip(TripsCompanion trip) {
    return (_db.update(_db.trips)..where((tbl) => tbl.id.equals(trip.id.value))).write(
      trip.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> deleteTrip(String tripId) {
    return (_db.update(_db.trips)..where((tbl) => tbl.id.equals(tripId))).write(
      TripsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================================================
  // Day Blocks
  // ==========================================================================

  @override
  Future<List<TripDay>> getDaysForTrip(String tripId) {
    return (_db.select(_db.tripDays)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortKey)]))
        .get();
  }

  @override
  Stream<List<TripDay>> watchDaysForTrip(String tripId) {
    return (_db.select(_db.tripDays)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortKey)]))
        .watch();
  }

  @override
  Future<TripDay> addDayBlock(String tripId, {String? title, String? pinnedDate}) async {
    final existingDays = await getDaysForTrip(tripId);
    final existingKeys = existingDays.map((d) => d.sortKey).toList();
    final newSortKey = FractionalIndexUtil.append(existingKeys);

    final dayId = _uuid.v4();
    final companion = TripDaysCompanion.insert(
      id: dayId,
      tripId: tripId,
      sortKey: newSortKey,
      title: Value(title),
      pinnedDate: Value(pinnedDate),
    );

    await _db.into(_db.tripDays).insert(companion);
    return (await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingle());
  }

  @override
  Future<void> swapDayBlocks(String dayIdA, String dayIdB) async {
    final dayA = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdA))).getSingle();
    final dayB = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdB))).getSingle();

    await _db.transaction(() async {
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdA))).write(
        TripDaysCompanion(sortKey: Value(dayB.sortKey), updatedAt: Value(DateTime.now())),
      );
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdB))).write(
        TripDaysCompanion(sortKey: Value(dayA.sortKey), updatedAt: Value(DateTime.now())),
      );
    });
  }

  @override
  Future<void> pinDayBlockDate(String dayId, String? pinnedDate) async {
    final targetDay = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingle();
    final allDays = await getDaysForTrip(targetDay.tripId);

    // Validate that pinned dates strictly increase along sort order
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

    ScheduleLogicEngine.validatePinnedDates(updatedBlocks);

    await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
      TripDaysCompanion(
        pinnedDate: Value(pinnedDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> reorderDayBlock(String dayId, String newSortKey) {
    return (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
      TripDaysCompanion(
        sortKey: Value(newSortKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================================================
  // Stops
  // ==========================================================================

  @override
  Future<List<Stop>> getStopsForTrip(String tripId) {
    return (_db.select(_db.stops)..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())).get();
  }

  @override
  Stream<List<Stop>> watchStopsForTrip(String tripId) {
    return (_db.select(_db.stops)..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())).watch();
  }

  @override
  Future<Stop> addPlaceToTrip({
    required String tripId,
    required String placeKey,
    required String addedBy,
  }) async {
    final place = await (_db.select(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey))).getSingle();
    final stopId = _uuid.v4();

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
      addedBy: addedBy,
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

    return (await (_db.select(_db.stops)..where((tbl) => tbl.id.equals(stopId))).getSingle());
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
  }) async {
    final placeKey = _uuid.v4();
    final placeCompanion = PlacesCompanion.insert(
      placeKey: placeKey,
      name: name,
      lat: lat,
      lng: lng,
      address: Value(address),
      description: Value(description),
      accessTips: Value(accessTips),
      visibility: const Value('trip_only'),
    );

    await _db.into(_db.places).insert(placeCompanion);

    return addPlaceToTrip(
      tripId: tripId,
      placeKey: placeKey,
      addedBy: addedBy,
    );
  }

  @override
  Future<void> deleteStop(String stopId) {
    return (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stopId))).write(
      StopsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================================================
  // Schedule Items
  // ==========================================================================

  @override
  Future<List<ScheduleItem>> getScheduleItemsForTrip(String tripId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortKey)]))
        .get();
  }

  @override
  Stream<List<ScheduleItem>> watchScheduleItemsForTrip(String tripId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.tripId.equals(tripId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortKey)]))
        .watch();
  }

  @override
  Future<List<ScheduleItem>> getScheduleItemsForDay(String dayId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.dayId.equals(dayId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortKey)]))
        .get();
  }

  @override
  Stream<List<ScheduleItem>> watchScheduleItemsForDay(String dayId) {
    return (_db.select(_db.scheduleItems)
          ..where((tbl) => tbl.dayId.equals(dayId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortKey)]))
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
    );

    await _db.into(_db.scheduleItems).insert(companion);
    return (await (_db.select(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).getSingle());
  }

  @override
  Future<void> reorderScheduleItem({
    required String itemId,
    required String newSortKey,
    String? targetDayId,
  }) {
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
      ScheduleItemsCompanion(
        sortKey: Value(newSortKey),
        dayId: targetDayId != null ? Value(targetDayId) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateScheduleItemStatus({
    required String itemId,
    required String status,
  }) {
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
      ScheduleItemsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteScheduleItem(String itemId) {
    return (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
      ScheduleItemsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
