// Review repros for PR #81.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/database/migrations/migration_v9_to_v10.dart';
import 'package:trip_planner/core/utils/schedule_logic.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

const v10Tables = [
  'stop_labels', 'schedule_items', 'stops', 'trip_days', 'trips',
  'place_labels', 'photos', 'place_visits', 'v10_reference_images',
  'labels', 'places',
];

/// Builds a real v9 database file: today's schema minus the v10 tables,
/// with user_version 9, seeded by [seed]. Reopening it runs onUpgrade(9 → 10)
/// exactly like an installed v0.1.3 app updating.
Future<File> v9File(Future<void> Function(AppDatabase db) seed) async {
  final dir = await Directory.systemTemp.createTemp('pr81_');
  final file = File('${dir.path}/app.sqlite');
  final db = AppDatabase.forTesting(NativeDatabase(file));
  await seed(db);
  await db.customStatement('PRAGMA foreign_keys = OFF');
  for (final t in v10Tables) {
    await db.customStatement('DROP TABLE $t');
  }
  await db.customStatement('PRAGMA user_version = 9');
  await db.close();
  return file;
}

void main() {
  group('migration (real upgrade from a v9 file)', () {
    test('every photo a v0.1.3 user saved survives the upgrade', () async {
      final file = await v9File((db) async {
        await db.into(db.pois).insert(PoisCompanion.insert(
            id: 'p', name: 'Uji bridge', lat: 34.9, lng: 135.8, authorId: 'u'));
        for (final (id, type) in [
          ('shot', 'user_photo'),
          ('compare', 'comparison_image'), // Compose → comparison
          ('upload', 'uploaded_image'), // Edit Photo on a gallery image
        ]) {
          await db.into(db.mediaAssets).insert(MediaAssetsCompanion.insert(
              id: id, poiId: 'p', authorId: 'u', type: type, localPath: Value('/x/$id.jpg')));
        }
      });

      final db = AppDatabase.forTesting(NativeDatabase(file));
      final photos = await db.select(db.photos).get();
      await db.close();

      expect(photos.map((p) => p.id).toSet(), {'shot', 'compare', 'upload'},
          reason: 'only these made it into photos: ${photos.map((p) => p.id).toList()}');
    });

    test('a spot deleted but not yet pushed stays deleted', () async {
      final file = await v9File((db) async {
        await db.into(db.pois).insert(PoisCompanion.insert(
            id: 'gone', name: 'Deleted spot', lat: 0, lng: 0, authorId: 'u',
            isDeleted: const Value(true), hasEverSynced: const Value(true)));
      });

      final db = AppDatabase.forTesting(NativeDatabase(file));
      final places = await db.select(db.places).get();
      await db.close();

      expect(places, isEmpty,
          reason: 'the v9 tombstone came back as a saved place: ${places.map((p) => p.name).toList()}');
    });
  });

  group('repositories', () {
    late AppDatabase db;
    late DriftTripRepository trips;
    late DriftPlaceRepository places;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      trips = DriftTripRepository(db);
      places = DriftPlaceRepository(db);
    });
    tearDown(() => db.close());

    test('two v9 regions with the same name do not break label lookup', () async {
      // ROIs were used as trips, so two named "Kyoto" is ordinary.
      for (final id in ['kyoto-2025', 'kyoto-2026']) {
        await db.into(db.rois).insert(RoisCompanion.insert(id: id, name: 'Kyoto', authorId: 'u'));
      }
      await MigrationV9ToV10(db).migrateData();

      await expectLater(places.getOrCreateLabel(kind: 'region', name: 'Kyoto'), completes);
    });

    test('swapping two pinned blocks leaves a trip the planner can still date', () async {
      final trip = await trips.createTrip(title: 't', ownerId: 'u', startDate: '2027-04-01', dayCount: 2);
      final days = await trips.getDaysForTrip(trip.id);
      await trips.pinDayBlockDate(days[0].id, '2027-04-01');
      await trips.pinDayBlockDate(days[1].id, '2027-04-05');

      await trips.swapDayBlocks(days[0].id, days[1].id); // "drag a block onto another"

      final after = await trips.getDaysForTrip(trip.id);
      expect(
        () => ScheduleLogicEngine.computeBlockDates(
          blocks: [
            for (final d in after)
              DayBlockInfo(id: d.id, sortKey: d.sortKey,
                  pinnedDate: d.pinnedDate == null ? null : DateTime.parse(d.pinnedDate!)),
          ],
          startDate: DateTime(2027, 4, 1),
          dayCount: 2,
        ),
        returnsNormally,
        reason: 'computeBlockDates throws on the pins swapDayBlocks just wrote',
      );
    });

    test('a pin can not give two blocks the same date', () {
      final dates = ScheduleLogicEngine.computeBlockDates(
        blocks: [
          const DayBlockInfo(id: 'a', sortKey: 'a0'), // dated by position: Apr 1
          DayBlockInfo(id: 'b', sortKey: 'a1', pinnedDate: DateTime(2027, 4, 1)),
        ],
        startDate: DateTime(2027, 4, 1),
        dayCount: 2,
      );
      expect(dates[0].date, isNot(dates[1].date),
          reason: 'both blocks are dated ${dates[0].date}; the doc says this pin is rejected');
    });

    test('deleting a stop also removes it from the day plan', () async {
      final trip = await trips.createTrip(title: 't', ownerId: 'u', dayCount: 1);
      final day = (await trips.getDaysForTrip(trip.id)).single;
      final stop = await trips.createTripOnlySpot(
          tripId: trip.id, name: 'spot', lat: 0, lng: 0, addedBy: 'u');
      await trips.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: day.id);

      await trips.deleteStop(stop.id);

      final items = await trips.getScheduleItemsForDay(day.id);
      expect(items, isEmpty, reason: 'the deleted stop is still scheduled on the day');
    });

    test('edits mark shared rows dirty so sync can find them', () async {
      final trip = await trips.createTrip(title: 't', ownerId: 'u', dayCount: 1);
      final day = (await trips.getDaysForTrip(trip.id)).single;
      final stop = await trips.createTripOnlySpot(
          tripId: trip.id, name: 'spot', lat: 0, lng: 0, addedBy: 'u');
      final item = await trips.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: day.id);
      await trips.updateScheduleItemStatus(itemId: item.id, status: 'done');

      final row = await (db.select(db.scheduleItems)..where((t) => t.id.equals(item.id))).getSingle();
      expect(row.syncStatus, 1, reason: 'syncStatus ${row.syncStatus}, updatedBy ${row.updatedBy}');
    });

    test('updated_at keeps sub-second precision for last-write-wins', () async {
      final trip = await trips.createTrip(title: 't', ownerId: 'u');
      final written = DateTime(2027, 4, 1, 9, 0, 0, 750);
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(TripsCompanion(updatedAt: Value(written)));

      final read = (await trips.getTrip(trip.id))!.updatedAt;
      expect(read, written, reason: 'wrote $written, read back $read');
    });
  });
}

