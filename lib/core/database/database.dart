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
  TripActivities,
  TripViews,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(db_connection.openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 16;

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
          await _createActivityIndex();
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
          if (from < 11 && from >= 10 && !await _hasColumn('stops', 'area')) {
            await m.addColumn(stops, stops.area);
          }
          if (from < 12 && from >= 10 && !await _hasColumn('stops', 'note')) {
            await m.addColumn(stops, stops.note);
          }
          if (from < 13) {
            // Drop legacy tables. For from >= 10 (dev phones), do not re-run migrateData(),
            // preventing overwriting edited/merged places, photos, and deleted labels.
            await MigrationV9ToV10(this).dropLegacyTables();
          }
          if (from < 14) {
            if (!await _hasColumn('places', 'chinese_name')) {
              await m.addColumn(places, places.chineseName);
            }
            if (!await _hasColumn('photos', 'keep_as_is')) {
              await m.addColumn(photos, photos.keepAsIs);
              // Set existing historical photos to keep_as_is = 1 so the user's existing
              // library photos are not flooded into the "Photos to edit" inbox.
              await customStatement('UPDATE photos SET keep_as_is = 1 WHERE keep_as_is = 0');
            }
          }
          if (from < 15) {
            // The activity log (What changed) and the unread dot (v0.4.0).
            await m.createTable(tripActivities);
            await m.createTable(tripViews);
            await _createActivityIndex();
          }
          if (from < 16) {
            // Where each frame is shot from: a place is one stop now, and its
            // frames carry the spots inside it (the fine layer). A merged
            // stop remembers the stop it went into. A file without one of the
            // tables (only ever a hand-made test file) skips it.
            if (await _hasTable('v10_reference_images')) {
              for (final (name, column) in [
                ('lat', newReferenceImages.lat),
                ('lng', newReferenceImages.lng),
                ('note', newReferenceImages.note),
                ('heading', newReferenceImages.heading),
              ]) {
                if (!await _hasColumn('v10_reference_images', name)) await m.addColumn(newReferenceImages, column);
              }
            }
            if (await _hasTable('stops') && !await _hasColumn('stops', 'merged_into')) {
              await m.addColumn(stops, stops.mergedInto);
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createActivityIndex() => customStatement(
        'CREATE INDEX IF NOT EXISTS idx_trip_activities_trip_created ON trip_activities(trip_id, created_at)',
      );

  Future<bool> _hasTable(String table) async => (await customSelect('PRAGMA table_info($table)').get()).isNotEmpty;

  Future<bool> _hasColumn(String table, String column) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    return columns.any((c) => c.read<String>('name') == column);
  }
}
