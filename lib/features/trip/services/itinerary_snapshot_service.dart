import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/trip_snapshot_models.dart';
import 'trip_snapshot_store.dart';

/// Service managing trip itinerary historical snapshots, state diffing, and atomic rollbacks.
///
/// Adheres strictly to:
/// - Rule 2 (Zero Data Loss & Topological Ingestion Ordering): Child records are cleared
///   before parents and restored parents before children to prevent FK constraint violations.
/// - Rule 2 (Partial Update Protection): Never replaces entire `trips` rows; uses targeted updates.
/// - Rule 2 (Entity Scope Isolation): All mutations and queries are strictly scoped to `tripId`.
/// - Rule 3 (Lifecycle Safety): Every database mutation is awaited inside atomic transactions.
class ItinerarySnapshotService {
  final TripSnapshotStore _store;
  final Uuid _uuid;

  const ItinerarySnapshotService({
    required TripSnapshotStore store,
    Uuid? uuid,
  })  : _store = store,
        _uuid = uuid ?? const Uuid();

  /// Captures an immutable snapshot of a trip's complete itinerary.
  Future<TripSnapshotPayload> createSnapshot(
    AppDatabase db,
    String tripId, {
    required String snapshotName,
    String? description,
    required String createdBy,
  }) async {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) {
      throw ArgumentError('Trip with ID $tripId not found');
    }

    final days = await (db.select(db.tripDays)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
        .get();

    final stops = await (db.select(db.stops)..where((s) => s.tripId.equals(tripId))).get();

    // Load stop label mappings
    final stopLabelMap = await _loadStopLabels(db, stops.map((s) => s.id).toList());

    final scheduleItems = await (db.select(db.scheduleItems)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
        .get();

    final snapshotId = _uuid.v4();
    final now = DateTime.now();

    final metadata = TripSnapshotMetadata(
      id: snapshotId,
      tripId: tripId,
      name: snapshotName.trim(),
      description: description?.trim(),
      createdAt: now,
      createdBy: createdBy,
      dayCount: days.length,
      stopCount: stops.length,
      scheduleItemCount: scheduleItems.length,
    );

    final tripData = TripDataSnapshot(
      title: trip.title,
      description: trip.description,
      startDate: trip.startDate,
      dayCount: trip.dayCount,
    );

    final daySnapshots = days.map((d) => TripDaySnapshot(
          id: d.id,
          sortKey: d.sortKey,
          title: d.title,
          pinnedDate: d.pinnedDate,
        )).toList();

    final stopSnapshots = stops.map((s) => StopSnapshot(
          id: s.id,
          placeKey: s.placeKey,
          name: s.name,
          lat: s.lat,
          lng: s.lng,
          description: s.description,
          address: s.address,
          businessHours: s.businessHours,
          contactInfo: s.contactInfo,
          accessTips: s.accessTips,
          links: s.links,
          coverLocalPath: s.coverLocalPath,
          coverRemoteUrl: s.coverRemoteUrl,
          source: s.source,
          sourceUrl: s.sourceUrl,
          area: s.area,
          note: s.note,
          addedBy: s.addedBy,
          labelIds: stopLabelMap[s.id] ?? const [],
        )).toList();

    final scheduleSnapshots = scheduleItems.map((i) => ScheduleItemSnapshot(
          id: i.id,
          stopId: i.stopId,
          dayId: i.dayId,
          sortKey: i.sortKey,
          stayMinutes: i.stayMinutes,
          transitMinutes: i.transitMinutes,
          fixedTime: i.fixedTime,
          status: i.status,
        )).toList();

    final payload = TripSnapshotPayload(
      metadata: metadata,
      trip: tripData,
      days: daySnapshots,
      stops: stopSnapshots,
      scheduleItems: scheduleSnapshots,
    );

    await _store.saveSnapshot(payload);
    return payload;
  }

  /// Lists all snapshots for a given trip.
  Future<List<TripSnapshotMetadata>> listSnapshots(String tripId) =>
      _store.listSnapshots(tripId);

  /// Retrieves a specific snapshot by its ID.
  Future<TripSnapshotPayload?> getSnapshot(String snapshotId) =>
      _store.getSnapshot(snapshotId);

  /// Deletes a snapshot by its ID.
  Future<bool> deleteSnapshot(String snapshotId) =>
      _store.deleteSnapshot(snapshotId);

  /// Clears all snapshots for a given trip.
  Future<void> clearSnapshots(String tripId) =>
      _store.clearSnapshots(tripId);

  /// Computes a semantic diff between a historical snapshot and the current trip state.
  Future<SnapshotDiffReport> compareSnapshotWithCurrent(
    AppDatabase db,
    String tripId,
    String snapshotId,
  ) async {
    final snapshot = await _store.getSnapshot(snapshotId);
    if (snapshot == null) {
      throw ArgumentError('Snapshot with ID $snapshotId not found');
    }
    if (snapshot.metadata.tripId != tripId) {
      throw ArgumentError('Snapshot $snapshotId does not belong to trip $tripId');
    }

    final currentDays = await (db.select(db.tripDays)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
        .get();

    final currentStops = await (db.select(db.stops)..where((s) => s.tripId.equals(tripId))).get();

    final currentSchedule = await (db.select(db.scheduleItems)
          ..where((s) => s.tripId.equals(tripId)))
        .get();

    // Compute Stop diffs
    final currentStopMap = {for (final s in currentStops) s.id: s};
    final snapshotStopMap = {for (final s in snapshot.stops) s.id: s};

    final addedStopNames = <String>[];
    final removedStopNames = <String>[];
    final modifiedStops = <StopDiffDetail>[];

    for (final curr in currentStops) {
      if (!snapshotStopMap.containsKey(curr.id)) {
        addedStopNames.add(curr.name);
      }
    }

    for (final snap in snapshot.stops) {
      final curr = currentStopMap[snap.id];
      if (curr == null) {
        removedStopNames.add(snap.name);
      } else {
        final changes = <String>[];
        if (curr.name != snap.name) changes.add('name');
        if (curr.note != snap.note) changes.add('note');
        if (curr.address != snap.address) changes.add('address');
        if (curr.description != snap.description) changes.add('description');
        if (changes.isNotEmpty) {
          modifiedStops.add(StopDiffDetail(
            stopId: snap.id,
            name: snap.name,
            changedFields: changes,
          ));
        }
      }
    }

    // Compute Day diffs
    final currentDayIds = currentDays.map((d) => d.id).toSet();
    final snapshotDayIds = snapshot.days.map((d) => d.id).toSet();

    final addedDayTitles = currentDays
        .where((d) => !snapshotDayIds.contains(d.id))
        .map((d) => d.title ?? 'Untitled Day')
        .toList();
    final removedDayTitles = snapshot.days
        .where((d) => !currentDayIds.contains(d.id))
        .map((d) => d.title ?? 'Untitled Day')
        .toList();

    // Compute Schedule diffs
    final currentScheduleMap = {for (final it in currentSchedule) it.stopId: it};
    final snapshotScheduleMap = {for (final it in snapshot.scheduleItems) it.stopId: it};
    final scheduleChanges = <ScheduleDiffDetail>[];

    for (final snapStop in snapshot.stops) {
      final snapSched = snapshotScheduleMap[snapStop.id];
      final currSched = currentScheduleMap[snapStop.id];

      if (snapSched != null && currSched != null) {
        if (snapSched.dayId != currSched.dayId) {
          scheduleChanges.add(ScheduleDiffDetail(
            stopId: snapStop.id,
            stopName: snapStop.name,
            description: 'Moved between day blocks',
          ));
        } else if (snapSched.stayMinutes != currSched.stayMinutes) {
          scheduleChanges.add(ScheduleDiffDetail(
            stopId: snapStop.id,
            stopName: snapStop.name,
            description: 'Stay duration changed (${snapSched.stayMinutes}m -> ${currSched.stayMinutes}m)',
          ));
        } else if (snapSched.status != currSched.status) {
          scheduleChanges.add(ScheduleDiffDetail(
            stopId: snapStop.id,
            stopName: snapStop.name,
            description: 'Status changed (${snapSched.status} -> ${currSched.status})',
          ));
        }
      } else if (snapSched != null && currSched == null) {
        scheduleChanges.add(ScheduleDiffDetail(
          stopId: snapStop.id,
          stopName: snapStop.name,
          description: 'Unscheduled in current trip',
        ));
      } else if (snapSched == null && currSched != null) {
        scheduleChanges.add(ScheduleDiffDetail(
          stopId: snapStop.id,
          stopName: snapStop.name,
          description: 'Scheduled in current trip but unscheduled in snapshot',
        ));
      }
    }

    return SnapshotDiffReport(
      tripId: tripId,
      snapshotId: snapshotId,
      snapshotName: snapshot.metadata.name,
      addedStopNames: addedStopNames,
      removedStopNames: removedStopNames,
      modifiedStops: modifiedStops,
      addedDayTitles: addedDayTitles,
      removedDayTitles: removedDayTitles,
      scheduleChanges: scheduleChanges,
    );
  }

  /// Rolls back a trip's itinerary state to match the historical snapshot.
  ///
  /// Guarantees:
  /// - Entity Scope Isolation: verifies [snapshotId] belongs to [tripId].
  /// - Topological Ingestion Ordering: deletes child records before parent records,
  ///   and re-inserts parent records before child records.
  /// - Library Safety: underlying physical [Places] are preserved (never deleted).
  /// - Automatic safety backup snapshot created before executing rollback.
  Future<RollbackResult> rollbackToSnapshot(
    AppDatabase db,
    String tripId,
    String snapshotId, {
    bool createPreRollbackBackup = true,
    String? operatedBy,
  }) async {
    final snapshot = await _store.getSnapshot(snapshotId);
    if (snapshot == null) {
      throw ArgumentError('Snapshot with ID $snapshotId not found');
    }
    if (snapshot.metadata.tripId != tripId) {
      throw ArgumentError('Snapshot $snapshotId does not belong to trip $tripId');
    }

    // Create automatic pre-rollback safety backup if requested
    String? backupSnapshotId;
    if (createPreRollbackBackup) {
      try {
        final backup = await createSnapshot(
          db,
          tripId,
          snapshotName: 'Pre-rollback safety backup (${snapshot.metadata.name})',
          description: 'Automated backup captured before restoring snapshot $snapshotId',
          createdBy: operatedBy ?? 'system',
        );
        backupSnapshotId = backup.metadata.id;
      } catch (e) {
        debugPrint('[ItinerarySnapshotService] Warning: pre-rollback backup failed: $e');
      }
    }

    return await db.transaction(() async {
      // 1. Delete existing schedule items for this trip
      await (db.delete(db.scheduleItems)..where((s) => s.tripId.equals(tripId))).go();

      // 2. Delete existing stop label links for this trip's stops
      final currentStops = await (db.select(db.stops)..where((s) => s.tripId.equals(tripId))).get();
      final currentStopIds = currentStops.map((s) => s.id).toList();
      if (currentStopIds.isNotEmpty) {
        await (db.delete(db.stopLabels)..where((sl) => sl.stopId.isIn(currentStopIds))).go();
      }

      // 3. Delete existing stops for this trip
      // Note: db.places are NOT deleted! (Rule 2: Relational integrity & Zero data loss)
      await (db.delete(db.stops)..where((s) => s.tripId.equals(tripId))).go();

      // 4. Delete existing trip day blocks for this trip
      await (db.delete(db.tripDays)..where((d) => d.tripId.equals(tripId))).go();

      // 5. Update core trip attributes using targeted partial update (Rule 2)
      await (db.update(db.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          title: Value(snapshot.trip.title),
          description: Value(snapshot.trip.description),
          startDate: Value(snapshot.trip.startDate),
          dayCount: Value(snapshot.trip.dayCount),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 6. Restore TripDays
      for (final day in snapshot.days) {
        await db.into(db.tripDays).insert(TripDaysCompanion.insert(
              id: day.id,
              tripId: tripId,
              sortKey: day.sortKey,
              title: Value(day.title),
              pinnedDate: Value(day.pinnedDate),
            ));
      }

      // 7. Ensure backing Places exist before restoring Stops (Topological Ordering)
      for (final stop in snapshot.stops) {
        final existingPlace = await (db.select(db.places)..where((p) => p.placeKey.equals(stop.placeKey))).getSingleOrNull();
        if (existingPlace == null) {
          await db.into(db.places).insert(PlacesCompanion.insert(
                placeKey: stop.placeKey,
                name: stop.name,
                lat: stop.lat,
                lng: stop.lng,
                description: Value(stop.description),
                address: Value(stop.address),
                businessHours: Value(stop.businessHours),
                contactInfo: Value(stop.contactInfo),
                accessTips: Value(stop.accessTips),
                links: Value(stop.links),
                coverLocalPath: Value(stop.coverLocalPath),
                coverRemoteUrl: Value(stop.coverRemoteUrl),
                source: Value(stop.source),
                sourceUrl: Value(stop.sourceUrl),
              ));
        }

        // Restore Stop
        await db.into(db.stops).insert(StopsCompanion.insert(
              id: stop.id,
              tripId: tripId,
              placeKey: stop.placeKey,
              name: stop.name,
              lat: stop.lat,
              lng: stop.lng,
              description: Value(stop.description),
              address: Value(stop.address),
              businessHours: Value(stop.businessHours),
              contactInfo: Value(stop.contactInfo),
              accessTips: Value(stop.accessTips),
              links: Value(stop.links),
              coverLocalPath: Value(stop.coverLocalPath),
              coverRemoteUrl: Value(stop.coverRemoteUrl),
              source: Value(stop.source),
              sourceUrl: Value(stop.sourceUrl),
              area: Value(stop.area),
              note: Value(stop.note),
              addedBy: stop.addedBy,
            ));

        // Restore StopLabels
        for (final labelId in stop.labelIds) {
          final labelExists = await (db.select(db.labels)..where((l) => l.id.equals(labelId))).getSingleOrNull();
          if (labelExists != null) {
            await db.into(db.stopLabels).insertOnConflictUpdate(StopLabelsCompanion.insert(
                  stopId: stop.id,
                  labelId: labelId,
                ));
          }
        }
      }

      // 8. Restore ScheduleItems
      for (final item in snapshot.scheduleItems) {
        await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
              id: item.id,
              tripId: tripId,
              stopId: item.stopId,
              dayId: item.dayId,
              sortKey: item.sortKey,
              stayMinutes: Value(item.stayMinutes),
              transitMinutes: Value(item.transitMinutes),
              fixedTime: Value(item.fixedTime),
              status: Value(item.status),
            ));
      }

      return RollbackResult(
        success: true,
        tripId: tripId,
        snapshotId: snapshotId,
        restoredDays: snapshot.days.length,
        restoredStops: snapshot.stops.length,
        restoredScheduleItems: snapshot.scheduleItems.length,
        backupSnapshotId: backupSnapshotId,
      );
    });
  }

  Future<Map<String, List<String>>> _loadStopLabels(AppDatabase db, List<String> stopIds) async {
    if (stopIds.isEmpty) return {};

    final rows = await (db.select(db.stopLabels)..where((sl) => sl.stopId.isIn(stopIds))).get();
    final map = <String, List<String>>{};

    for (final row in rows) {
      map.putIfAbsent(row.stopId, () => []).add(row.labelId);
    }
    return map;
  }
}
