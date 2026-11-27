import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:trip_planner/core/database/database.dart';

/// Schema 15 adds the activity log (`trip_activities`) and the unread dot's
/// `trip_views`; a schema 14 database keeps its trips and gains both.
void main() {
  test('a fresh database is at schema 15 with both tables and the index', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, greaterThanOrEqualTo(15));
    final tables = {
      for (final r in await db.customSelect("SELECT name FROM sqlite_master WHERE type IN ('table','index')").get())
        r.read<String>('name'),
    };
    expect(tables, containsAll(['trip_activities', 'trip_views', 'idx_trip_activities_trip_created']));
  });

  test('upgrading from 14 adds the tables and keeps the trips', () async {
    final dir = await Directory.systemTemp.createTemp('tp_migration_v15_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v14.sqlite');

    // A schema 15 file with a trip, then taken back to how 14 looked.
    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.into(first.trips).insert(TripsCompanion.insert(id: 't1', title: 'Uji', ownerId: 'u', sharing: const Value('group')));
    await first.close();
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('DROP INDEX IF EXISTS idx_trip_activities_trip_created');
    raw.execute('DROP TABLE trip_activities');
    raw.execute('DROP TABLE trip_views');
    raw.execute('PRAGMA user_version = 14');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final trips = await db.select(db.trips).get();
    expect(trips.single.title, 'Uji');

    await db.into(db.tripActivities).insert(TripActivitiesCompanion.insert(
          id: 'a1',
          tripId: 't1',
          actorId: 'u',
          action: 'add_stop',
          entityType: 'stop',
          entityId: 's1',
          summary: 'added Uji Bridge',
          createdAt: DateTime(2026, 11, 16),
        ));
    await db.into(db.tripViews).insert(TripViewsCompanion.insert(tripId: 't1', userId: 'u', viewedAt: DateTime(2026, 11, 16)));
    expect(await db.select(db.tripActivities).get(), hasLength(1));
    expect(await db.select(db.tripViews).get(), hasLength(1));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), greaterThanOrEqualTo(15));
  });
}
