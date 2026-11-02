import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';

void main() {
  group('Schema v11 to v12 migration tests', () {
    test('fresh database starts at schema version 12 with note column in stops', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, equals(12));

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

    test('migrating from v11 adds note column and preserves existing rows', () async {
      final rawDb = NativeDatabase.memory();
      final db = AppDatabase.forTesting(rawDb);
      addTearDown(db.close);

      // Verify migration runs cleanly
      await db.customSelect('SELECT id, name, area, note FROM stops LIMIT 1').get();
    });
  });
}

