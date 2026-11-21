import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../library/repositories/place_repository.dart';
import '../models/stop_group.dart';
import '../services/trip_activity_log.dart';

/// The trip note of stops merged into one: [kept]'s, then each other one
/// that isn't already there, a blank line apart. Null when none has a note.
String? mergedStopNote(String? kept, Iterable<String?> others) {
  final notes = <String>[];
  for (final note in [kept, ...others]) {
    final trimmed = note?.trim();
    if (trimmed != null && trimmed.isNotEmpty && !notes.contains(trimmed)) notes.add(trimmed);
  }
  return notes.isEmpty ? null : notes.join('\n\n');
}

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

  /// Merges [otherIds] into [keepId], stops of one trip for the same spot.
  /// The kept stop keeps its name and facts, and takes on the others' notes,
  /// labels, frames, group and days; the others are then removed. The
  /// others' frames become spots of the kept stop: each takes the position
  /// and short name of the stop it came from, unless it has its own.
  Future<void> mergeStops({required String keepId, required List<String> otherIds});

  /// Turns a group of stops into one place named [name]: [keepId] stays,
  /// renamed to [name] and in no group, and takes on [otherIds]' labels,
  /// frames and days as [mergeStops] does, but not their trip notes (a
  /// member's note names its spot, so it goes onto its frames instead).
  /// Every member's frames, the kept stop's too, take the position and
  /// short name ([spotLabel]) of the stop they came from unless they have
  /// their own, and the library's frames of the members are copied onto the
  /// kept stop with theirs, since the library places stop showing in the
  /// trip with their stops gone.
  Future<void> foldStopsIntoPlace({required String keepId, required List<String> otherIds, required String name});

  /// Sets where the frames [frameIds] are shot from, a spot of a place:
  /// their position ([lat] with [lng]) and/or their [note], each left alone
  /// when absent. Only frames of the trip's live stops change; the
  /// library's stay the library's. Their stops are marked for sync, so the
  /// `frameShots` map goes up with them, and the change is logged.
  Future<void> setFrameShots({
    required List<String> frameIds,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<String?> note = const Value.absent(),
  });

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

  // Restoration (Undo & Safety Net)
  Future<void> restoreStop(String stopId, {Duration window = const Duration(days: 30)});
  Future<void> restoreDayBlock(String dayId, {Duration window = const Duration(days: 30)});
  Future<void> restoreTrip(String tripId, {Duration window = const Duration(days: 30)});
}

/// Drift implementation of [TripRepository].
class DriftTripRepository implements TripRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  final String _currentUserId;
  final PlaceRepository _placeRepository;
  int _lastTimestampMs = 0;
  late final TripActivityLog _activity = TripActivityLog(_db, _uuid);

  /// Adds an entry to the trip's activity log (shared trips only), inside the
  /// caller's transaction so the entry and the change go up together.
  Future<void> _log(String tripId, TripActivityAction action, String entityType, String entityId, String summary) =>
      _activity.record(
        tripId: tripId,
        actorId: _currentUserId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        summary: summary,
      );

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
    return _db.transaction(() async {
      final before = await (_db.select(_db.trips)..where((tbl) => tbl.id.equals(trip.id.value))).getSingleOrNull();
      await (_db.update(_db.trips)..where((tbl) => tbl.id.equals(trip.id.value))).write(
        trip.copyWith(
          updatedAt: Value(now),
          updatedBy: trip.updatedBy.present ? trip.updatedBy : Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      if (before == null) return;
      // The edit sheet sends every field, so log only what actually changed.
      final String summary;
      if (trip.title.present && trip.title.value != before.title) {
        summary = 'renamed the trip to "${trip.title.value}"';
      } else if ((trip.startDate.present && trip.startDate.value != before.startDate) ||
          (trip.dayCount.present && trip.dayCount.value != before.dayCount)) {
        summary = "changed the trip's dates";
      } else if (trip.description.present && (trip.description.value ?? '') != (before.description ?? '')) {
        summary = "edited the trip's description";
      } else {
        return;
      }
      await _log(trip.id.value, TripActivityAction.updateTrip, 'trip', trip.id.value, summary);
    });
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
      await _log(tripId, TripActivityAction.deleteTrip, 'trip', tripId, 'deleted the trip');
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
      await _log(tripId, TripActivityAction.addDay, 'day', dayId, 'added ${await _activity.dayLabel(tripId, dayId)}');
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
      if (day.title.present) {
        final label = await _activity.dayLabel(current.tripId, dayId);
        final title = day.title.value?.trim();
        await _log(current.tripId, TripActivityAction.updateDay, 'day', dayId,
            title == null || title.isEmpty ? 'cleared the name of $label' : 'named $label');
      }
    });
  }

  @override
  Future<void> deleteDayBlock(String dayId) async {
    final now = _now();
    await _db.transaction(() async {
      final day = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingleOrNull();
      final label = day == null ? null : await _activity.dayLabel(day.tripId, dayId);
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
      if (day != null && day.deletedAt == null) {
        await _log(day.tripId, TripActivityAction.removeDay, 'day', dayId, 'deleted $label');
      }
    });
  }

  @override
  Future<void> swapDayBlocks(String dayIdA, String dayIdB) async {
    await _db.transaction(() async {
      final dayA = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdA))).getSingle();
      final dayB = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayIdB))).getSingle();
      final labelA = await _activity.dayLabel(dayA.tripId, dayIdA);
      final labelB = await _activity.dayLabel(dayB.tripId, dayIdB);

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
      await _log(dayA.tripId, TripActivityAction.moveDay, 'day', dayIdA, 'swapped $labelA and $labelB');
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
      final label = await _activity.dayLabel(targetDay.tripId, dayId);
      await _log(targetDay.tripId, TripActivityAction.updateDay, 'day', dayId,
          pinnedDate == null ? 'unpinned $label from its date' : 'pinned $label to $pinnedDate');
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

      final before = await _activity.dayLabel(targetDay.tripId, dayId, days: allDays);
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).write(
        TripDaysCompanion(
          sortKey: Value(newSortKey),
          updatedAt: Value(_now()),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      final after = await _activity.dayLabel(targetDay.tripId, dayId);
      if (after != before) {
        await _log(targetDay.tripId, TripActivityAction.moveDay, 'day', dayId, 'moved $before to ${after.split(' (').first}');
      }
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
                lat: Value(img.lat),
                lng: Value(img.lng),
                note: Value(img.note),
                heading: Value(img.heading),
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

      await _log(tripId, TripActivityAction.addStop, 'stop', stopId, 'added ${place.name}');
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
    return _db.transaction(() async {
      final before = await getStop(stop.id.value);
      await (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stop.id.value))).write(
        stop.copyWith(
          updatedAt: Value(now),
          updatedBy: stop.updatedBy.present ? stop.updatedBy : Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      if (before == null) return;
      final String summary;
      if (stop.name.present && stop.name.value != before.name) {
        summary = 'renamed ${before.name} to ${stop.name.value}';
      } else if (stop.note.present) {
        summary = 'edited the note on ${before.name}';
      } else if (stop.lat.present || stop.lng.present) {
        summary = 'moved the pin of ${before.name}';
      } else {
        summary = 'edited ${before.name}';
      }
      await _log(before.tripId, TripActivityAction.updateStop, 'stop', before.id, summary);
    });
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
      final stops = await (_db.select(_db.stops)..where((tbl) => tbl.id.isIn(stopIds) & tbl.deletedAt.isNull())).get();
      if (stops.isEmpty) return;
      final names = stopNames([for (final s in stops) s.name]);
      await _log(stops.first.tripId, TripActivityAction.groupStops, 'stop', stops.first.id,
          normalizedArea == null ? 'ungrouped $names' : 'grouped $names as "$normalizedArea"');
    });
  }

  @override
  Future<void> deleteStop(String stopId) => _deleteStop(stopId);

  /// Deletes [stopId] and its days; [mergedInto] names the stop a merge
  /// moved it into, which the other members' phones follow.
  Future<void> _deleteStop(String stopId, {bool log = true, String? mergedInto}) async {
    final now = _now();
    await _db.transaction(() async {
      final stop = await getStop(stopId);
      await (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stopId))).write(
        StopsCompanion(
          deletedAt: Value(now),
          mergedInto: Value(mergedInto),
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
      if (log && stop != null && stop.deletedAt == null) {
        await _log(stop.tripId, TripActivityAction.removeStop, 'stop', stopId, 'removed ${stop.name}');
      }
    });
  }

  @override
  Future<void> mergeStops({required String keepId, required List<String> otherIds}) =>
      _merge(keepId: keepId, otherIds: otherIds);

  @override
  Future<void> foldStopsIntoPlace({required String keepId, required List<String> otherIds, required String name}) =>
      _merge(keepId: keepId, otherIds: otherIds, place: name.trim());

  @override
  Future<void> setFrameShots({
    required List<String> frameIds,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) async {
    if (frameIds.isEmpty || (!lat.present && !lng.present && !note.present)) return;
    final now = _now();
    await _db.transaction(() async {
      final frames = await (_db.select(_db.newReferenceImages)..where((f) => f.id.isIn(frameIds) & f.stopId.isNotNull())).get();
      final stopIds = {for (final f in frames) f.stopId!};
      final stops = await (_db.select(_db.stops)..where((s) => s.id.isIn(stopIds) & s.deletedAt.isNull())).get();
      if (stops.isEmpty) return;
      final live = {for (final s in stops) s.id};
      final ids = [for (final f in frames) if (live.contains(f.stopId)) f.id];
      await (_db.update(_db.newReferenceImages)..where((f) => f.id.isIn(ids))).write(
        NewReferenceImagesCompanion(lat: lat, lng: lng, note: note),
      );
      for (final stop in stops) {
        await (_db.update(_db.stops)..where((s) => s.id.equals(stop.id))).write(
          StopsCompanion(updatedAt: Value(now), updatedBy: Value(_currentUserId), syncStatus: const Value(1)),
        );
        final what = lat.present || lng.present ? 'moved a spot of ${stop.name}' : 'renamed a spot of ${stop.name}';
        await _log(stop.tripId, TripActivityAction.updateStop, 'stop', stop.id, what);
      }
    });
  }

  /// [mergeStops], or with a [place] name [foldStopsIntoPlace].
  Future<void> _merge({required String keepId, required List<String> otherIds, String? place}) async {
    await _db.transaction(() async {
      final kept = await getStop(keepId);
      if (kept == null || kept.deletedAt != null) throw StateError('The stop to keep is gone.');
      final others = <Stop>[
        for (final id in otherIds.toSet())
          if (id != keepId)
            if (await getStop(id) case final s? when s.deletedAt == null && s.tripId == kept.tripId) s,
      ];
      final folding = place != null && place.isNotEmpty;
      if (others.isEmpty && !folding) return;

      String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
      var area = clean(kept.area);
      for (final other in others) {
        area ??= clean(other.area);
      }
      // The name a member's spots are told apart from: the group's.
      final group = folding ? place : area;

      // Labels.
      final otherIdList = [for (final o in others) o.id];
      final labelRows = await (_db.select(_db.stopLabels)..where((t) => t.stopId.isIn(otherIdList))).get();
      for (final row in labelRows) {
        await _db.into(_db.stopLabels).insertOnConflictUpdate(StopLabelsCompanion.insert(stopId: keepId, labelId: row.labelId));
      }

      // Frames: one that shows a file the kept stop already has goes, and
      // the user's photos of it count for the one that stays. The rest move
      // to the kept stop as its spots.
      final keptFrames = await getReferenceImagesForStop(keepId);
      final byFile = <String, String>{
        for (final f in keptFrames)
          if (f.localPath ?? f.remoteUrl case final file?) file: f.id,
      };
      if (folding) {
        for (final frame in keptFrames) {
          await (_db.update(_db.newReferenceImages)..where((t) => t.id.equals(frame.id))).write(frameAsSpotOf(frame, kept, group));
        }
      }
      for (final other in others) {
        for (final frame in await getReferenceImagesForStop(other.id)) {
          final file = frame.localPath ?? frame.remoteUrl;
          final same = file == null ? null : byFile[file];
          if (same != null) {
            await (_db.update(_db.photos)..where((t) => t.referenceImageId.equals(frame.id)))
                .write(PhotosCompanion(referenceImageId: Value(same)));
            await (_db.delete(_db.newReferenceImages)..where((t) => t.id.equals(frame.id))).go();
          } else {
            if (file != null) byFile[file] = frame.id;
            await (_db.update(_db.newReferenceImages)..where((t) => t.id.equals(frame.id)))
                .write(frameAsSpotOf(frame, other, group).copyWith(stopId: Value(keepId)));
          }
        }
      }
      // The library's frames of a stop show in the trip only through it, so
      // those of a stop that goes (and, folding, the kept stop's too, to say
      // where they're shot from) are copied onto the kept stop.
      for (final member in [if (folding) kept, ...others]) {
        if (member.placeKey.isEmpty) continue;
        final library = await (_db.select(_db.newReferenceImages)
              ..where((t) => t.placeKey.equals(member.placeKey) & t.stopId.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt), (t) => OrderingTerm(expression: t.id)]))
            .get();
        for (final frame in library) {
          final file = frame.localPath ?? frame.remoteUrl;
          if (file == null || byFile.containsKey(file)) continue;
          final id = _uuid.v4();
          byFile[file] = id;
          await _db.into(_db.newReferenceImages).insert(frame.toCompanion(true).copyWith(
                id: Value(id),
                placeKey: const Value(null),
                stopId: Value(keepId),
                lat: Value(frame.lat ?? member.lat),
                lng: Value(frame.lng ?? member.lng),
                note: Value(clean(frame.note) ?? spotLabel(member, group)),
                createdAt: Value(DateTime.now()),
              ));
        }
      }

      // Days: the others' items move to the kept stop, except on a day it is
      // already on, where a visit still counts.
      final now = _now();
      Future<List<ScheduleItem>> liveItems(String stopId) =>
          (_db.select(_db.scheduleItems)..where((t) => t.stopId.equals(stopId) & t.deletedAt.isNull())).get();
      final onDay = {for (final it in await liveItems(keepId)) it.dayId: it};
      for (final other in others) {
        for (final it in await liveItems(other.id)) {
          final mine = onDay[it.dayId];
          if (mine == null) {
            await (_db.update(_db.scheduleItems)..where((t) => t.id.equals(it.id))).write(ScheduleItemsCompanion(
              stopId: Value(keepId),
              updatedAt: Value(now),
              updatedBy: Value(_currentUserId),
              syncStatus: const Value(1),
            ));
            onDay[it.dayId] = it.copyWith(stopId: keepId);
          } else if (it.status == 'done' && mine.status != 'done') {
            await (_db.update(_db.scheduleItems)..where((t) => t.id.equals(mine.id))).write(ScheduleItemsCompanion(
              status: const Value('done'),
              updatedAt: Value(now),
              updatedBy: Value(_currentUserId),
              syncStatus: const Value(1),
            ));
            onDay[it.dayId] = mine.copyWith(status: 'done');
          }
        }
      }

      // The kept stop is edited, so it syncs again with what it took on.
      await (_db.update(_db.stops)..where((t) => t.id.equals(keepId))).write(StopsCompanion(
        name: folding ? Value(place) : const Value.absent(),
        note: folding ? const Value.absent() : Value(mergedStopNote(kept.note, [for (final o in others) o.note])),
        area: Value(folding ? null : area),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ));
      for (final other in others) {
        await _deleteStop(other.id, log: false, mergedInto: keepId);
      }
      final summary = !folding
          ? 'merged ${stopNames([for (final o in others) o.name])} into ${kept.name}'
          : others.isEmpty
              ? 'made "$place" one place'
              : 'made "$place" one place from ${stopNames([kept.name, for (final o in others) o.name])}';
      await _log(kept.tripId, TripActivityAction.mergeStops, 'stop', keepId, summary);
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
      await _log(tripId, TripActivityAction.scheduleStop, 'stop', stopId,
          'planned ${await _activity.stopName(stopId)} on ${await _activity.dayLabel(tripId, dayId)}');
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

      final names = [for (final id in stopIds) await _activity.stopName(id)];
      await _log(tripId, TripActivityAction.scheduleStop, 'stop', stopIds.first,
          'planned ${stopNames(names)} on ${await _activity.dayLabel(tripId, dayId)}');
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
    return _db.transaction(() async {
      final before = await (_db.select(_db.scheduleItems)..where((tbl) => tbl.id.equals(item.id.value))).getSingleOrNull();
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(item.id.value))).write(
        item.copyWith(
          updatedAt: Value(now),
          updatedBy: item.updatedBy.present ? item.updatedBy : Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      if (before == null) return;
      final name = await _activity.stopName(before.stopId);
      final day = await _activity.dayLabel(before.tripId, before.dayId);
      if (item.deletedAt.present && item.deletedAt.value == null && before.deletedAt != null) {
        await _log(before.tripId, TripActivityAction.scheduleStop, 'stop', before.stopId, 'put $name back on $day');
      } else if (item.fixedTime.present || item.stayMinutes.present || item.transitMinutes.present) {
        await _log(before.tripId, TripActivityAction.changeTime, 'stop', before.stopId, "changed $name's times on $day");
      }
    });
  }

  @override
  Future<void> reorderScheduleItem({
    required String itemId,
    required String newSortKey,
    String? targetDayId,
  }) {
    final now = _now();
    return _db.transaction(() async {
      final before = await (_db.select(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).getSingleOrNull();
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
        ScheduleItemsCompanion(
          sortKey: Value(newSortKey),
          dayId: targetDayId != null ? Value(targetDayId) : const Value.absent(),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      if (before != null) await _logMoves(before.tripId, [before], targetDayId);
    });
  }

  /// "moved Uji Bridge to Day 3" when items changed day; "reordered Day 2"
  /// when they only changed places within it.
  Future<void> _logMoves(String tripId, List<ScheduleItem> before, String? targetDayId) async {
    if (before.isEmpty) return;
    final movedDays = targetDayId != null && before.any((i) => i.dayId != targetDayId);
    if (movedDays) {
      final names = [for (final i in before) await _activity.stopName(i.stopId)];
      await _log(tripId, TripActivityAction.moveStop, 'stop', before.first.stopId,
          'moved ${stopNames(names)} to ${await _activity.dayLabel(tripId, targetDayId)}');
    } else {
      final dayId = before.first.dayId;
      await _log(tripId, TripActivityAction.moveDay, 'day', dayId, 'reordered ${await _activity.dayLabel(tripId, dayId)}');
    }
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
      final before = await (_db.select(_db.scheduleItems)..where((tbl) => tbl.id.isIn(itemIds))).get();
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
      if (before.isNotEmpty) await _logMoves(before.first.tripId, before, resolvedDayId);
    });
  }

  @override
  Future<void> updateScheduleItemStatus({
    required String itemId,
    required String status,
  }) {
    final now = _now();
    return _db.transaction(() async {
      final before = await (_db.select(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).getSingleOrNull();
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.equals(itemId))).write(
        ScheduleItemsCompanion(
          status: Value(status),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      if (before == null || before.status == status) return;
      final name = await _activity.stopName(before.stopId);
      final summary = switch (status) {
        'done' => 'marked $name done',
        'skipped' => 'skipped $name',
        _ => 'marked $name not done',
      };
      await _log(before.tripId, TripActivityAction.setVisited, 'stop', before.stopId, summary);
    });
  }

  @override
  Future<void> deleteScheduleItem(String itemId) => deleteScheduleItems([itemId]);

  @override
  Future<void> deleteScheduleItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    await _db.transaction(() async {
      final before = await (_db.select(_db.scheduleItems)
            ..where((tbl) => tbl.id.isIn(itemIds) & tbl.deletedAt.isNull()))
          .get();
      final now = _now();
      await (_db.update(_db.scheduleItems)..where((tbl) => tbl.id.isIn(itemIds))).write(
        ScheduleItemsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
      if (before.isEmpty) return;
      final names = [for (final i in before) await _activity.stopName(i.stopId)];
      final days = {for (final i in before) i.dayId};
      final from = days.length == 1 ? await _activity.dayLabel(before.first.tripId, days.first) : 'their days';
      await _log(before.first.tripId, TripActivityAction.unscheduleStop, 'stop', before.first.stopId,
          'took ${stopNames(names)} off $from');
    });
  }

  // ==========================================================================
  // Restoration (Undo & Safety Net)
  // ==========================================================================

  @override
  Future<void> restoreStop(String stopId, {Duration window = const Duration(days: 30)}) async {
    final now = _now();
    final cutoff = DateTime.now().subtract(window);
    await _db.transaction(() async {
      final stop = await (_db.select(_db.stops)..where((tbl) => tbl.id.equals(stopId))).getSingleOrNull();
      if (stop == null || stop.deletedAt == null) return;
      final deletedAt = stop.deletedAt!;
      if (deletedAt.isBefore(cutoff)) return;

      // Revive the stop
      await (_db.update(_db.stops)..where((tbl) => tbl.id.equals(stopId) & tbl.tripId.equals(stop.tripId))).write(
        StopsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );

      await _log(stop.tripId, TripActivityAction.restoreStop, 'stop', stopId, 'restored ${stop.name}');

      // Revive schedule items that were deleted at the same time as this stop,
      // on days that are still there (a day deleted since stays in the trash).
      final liveDays = await (_db.select(_db.tripDays)
            ..where((tbl) => tbl.tripId.equals(stop.tripId) & tbl.deletedAt.isNull()))
          .get();
      if (liveDays.isEmpty) return;
      await (_db.update(_db.scheduleItems)
            ..where((tbl) =>
                tbl.stopId.equals(stopId) &
                tbl.tripId.equals(stop.tripId) &
                tbl.deletedAt.equals(deletedAt.millisecondsSinceEpoch) &
                tbl.dayId.isIn(liveDays.map((d) => d.id))))
          .write(
        ScheduleItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );
    });
  }

  @override
  Future<void> restoreDayBlock(String dayId, {Duration window = const Duration(days: 30)}) async {
    final now = _now();
    final cutoff = DateTime.now().subtract(window);
    await _db.transaction(() async {
      final day = await (_db.select(_db.tripDays)..where((tbl) => tbl.id.equals(dayId))).getSingleOrNull();
      if (day == null || day.deletedAt == null) return;
      final deletedAt = day.deletedAt!;
      if (deletedAt.isBefore(cutoff)) return;

      // Revive the day block
      await (_db.update(_db.tripDays)..where((tbl) => tbl.id.equals(dayId) & tbl.tripId.equals(day.tripId))).write(
        TripDaysCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );

      await _log(day.tripId, TripActivityAction.restoreDay, 'day', dayId, 'restored ${await _activity.dayLabel(day.tripId, dayId)}');

      // Revive schedule items deleted with this day whose stops are still active
      final liveStops = await (_db.select(_db.stops)
            ..where((tbl) => tbl.tripId.equals(day.tripId) & tbl.deletedAt.isNull()))
          .get();
      final liveStopIds = liveStops.map((s) => s.id).toSet();

      if (liveStopIds.isNotEmpty) {
        await (_db.update(_db.scheduleItems)
              ..where((tbl) =>
                  tbl.dayId.equals(dayId) &
                  tbl.tripId.equals(day.tripId) &
                  tbl.deletedAt.equals(deletedAt.millisecondsSinceEpoch) &
                  tbl.stopId.isIn(liveStopIds)))
            .write(
          ScheduleItemsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(now),
            updatedBy: Value(_currentUserId),
            syncStatus: const Value(1),
          ),
        );
      }
    });
  }

  @override
  Future<void> restoreTrip(String tripId, {Duration window = const Duration(days: 30)}) async {
    final now = _now();
    final cutoff = DateTime.now().subtract(window);
    await _db.transaction(() async {
      final trip = await (_db.select(_db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
      if (trip == null || trip.deletedAt == null) return;
      final deletedAt = trip.deletedAt!;
      if (deletedAt.isBefore(cutoff)) return;

      await (_db.update(_db.trips)..where((tbl) => tbl.id.equals(tripId))).write(
        TripsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
          updatedBy: Value(_currentUserId),
          syncStatus: const Value(1),
        ),
      );

      // What went with the trip comes back, and what this device still has
      // live goes up again too: if the trip was deleted on another device,
      // this one may never have pulled its tombstones, and they would hide
      // everything again once the trip's watchers restart.
      await (_db.update(_db.tripDays)
            ..where((tbl) =>
                tbl.tripId.equals(tripId) &
                (tbl.deletedAt.equals(deletedAt.millisecondsSinceEpoch) | tbl.deletedAt.isNull())))
          .write(TripDaysCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ));

      await (_db.update(_db.stops)
            ..where((tbl) =>
                tbl.tripId.equals(tripId) &
                (tbl.deletedAt.equals(deletedAt.millisecondsSinceEpoch) | tbl.deletedAt.isNull())))
          .write(StopsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ));

      await (_db.update(_db.scheduleItems)
            ..where((tbl) =>
                tbl.tripId.equals(tripId) &
                (tbl.deletedAt.equals(deletedAt.millisecondsSinceEpoch) | tbl.deletedAt.isNull())))
          .write(ScheduleItemsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
        updatedBy: Value(_currentUserId),
        syncStatus: const Value(1),
      ));
      await _log(tripId, TripActivityAction.restoreTrip, 'trip', tripId, 'restored the trip');
    });
  }
}

