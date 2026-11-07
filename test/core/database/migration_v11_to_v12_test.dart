import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:trip_planner/core/database/database.dart';

void main() {
  group('Schema v11 to v12 migration tests', () {
    test('fresh database starts at latest schema version with note column in stops', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, equals(14));

      final now = DateTime.now();
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_1',
              title: 'Test Trip',
              ownerId: 'user_1',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_1',
              tripId: 'trip_1',
              placeKey: 'anitabi:123',
              name: 'Kyoto Tower',
              lat: 34.987,
              lng: 135.759,
              area: const Value('Shimogyo'),
              note: const Value('Meet at the observation deck entrance'),
              addedBy: 'user_1',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final stop = await (db.select(db.stops)..where((s) => s.id.equals('stop_1'))).getSingle();
      expect(stop.area, equals('Shimogyo'));
      expect(stop.note, equals('Meet at the observation deck entrance'));
    });

    test('real onUpgrade from v11 database file adds note column and preserves existing rows', () async {
      final tempDir = await Directory.systemTemp.createTemp('db_v11_test_');
      final dbFile = File('${tempDir.path}/test_v11.db');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      // 1. Create and seed initial data
      final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final now = DateTime.now();
      await db1.into(db1.trips).insert(
            TripsCompanion.insert(
              id: 'trip_1',
              title: 'V11 Trip',
              ownerId: 'user_1',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db1.into(db1.stops).insert(
            StopsCompanion.insert(
              id: 'stop_1',
              tripId: 'trip_1',
              placeKey: 'anitabi:123',
              name: 'Kyoto Tower',
              lat: 34.987,
              lng: 135.759,
              area: const Value('Shimogyo'),
              note: const Value('Temporary Note'),
              addedBy: 'user_1',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db1.close();

      // 2. Drop the column and set schema version to 11 via raw sqlite3
      final raw = sqlite.sqlite3.open(dbFile.path);
      raw.execute('ALTER TABLE stops DROP COLUMN note;');
      raw.execute('PRAGMA user_version = 11;');
      raw.dispose();

      // 3. Re-open with AppDatabase to trigger real onUpgrade from 11 -> 13
      final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db2.close);

      expect(db2.schemaVersion, equals(14));

      final stop = await (db2.select(db2.stops)..where((s) => s.id.equals('stop_1'))).getSingle();
      expect(stop.name, equals('Kyoto Tower'));
      expect(stop.area, equals('Shimogyo'));
      expect(stop.note, isNull);

      // Verify that the new note column accepts updates
      await (db2.update(db2.stops)..where((s) => s.id.equals('stop_1'))).write(
        const StopsCompanion(note: Value('Upgraded v12 note')),
      );
      final updated = await (db2.select(db2.stops)..where((s) => s.id.equals('stop_1'))).getSingle();
      expect(updated.note, equals('Upgraded v12 note'));
    });
  });
}

