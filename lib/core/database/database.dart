import 'package:drift/drift.dart';
import 'connection/connection.dart' as db_connection;
import 'tables_v10.dart';
import 'migrations/migration_v9_to_v10.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Places,
  Labels,
  PlaceLabels,
  Photos,
  PlaceVisits,
  NewReferenceImages,
  Trips,
  TripDays,
  Stops,
  StopLabels,
  ScheduleItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(db_connection.openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_labels_kind_name
            ON labels(kind, name)
            WHERE kind IN ('tag', 'region');
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_labels_bangumi_id
            ON labels(bangumi_id)
            WHERE bangumi_id IS NOT NULL;
          ''');
        },
        onUpgrade: (m, from, to) async {
          if (from < 10) {
            await m.createTable(places);
            await m.createTable(labels);
            await m.createTable(placeLabels);
            await m.createTable(photos);
            await m.createTable(placeVisits);
            await m.createTable(newReferenceImages);
            await m.createTable(trips);
            await m.createTable(tripDays);
            await m.createTable(stops);
            await m.createTable(stopLabels);
            await m.createTable(scheduleItems);
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_labels_kind_name
              ON labels(kind, name)
              WHERE kind IN ('tag', 'region');
            ''');
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_labels_bangumi_id
              ON labels(bangumi_id)
              WHERE bangumi_id IS NOT NULL;
            ''');

            // Migrate legacy data to v10 tables (runs once for any upgrade from < 10).
            await MigrationV9ToV10(this).migrateData();
          }
          if (from < 11 && from >= 10) {
            await m.addColumn(stops, stops.area);
          }
          if (from < 12 && from >= 10) {
            await m.addColumn(stops, stops.note);
          }
          if (from < 13) {
            // Drop legacy tables. For from >= 10 (dev phones), do not re-run migrateData(),
            // preventing overwriting edited/merged places, photos, and deleted labels.
            await MigrationV9ToV10(this).dropLegacyTables();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
