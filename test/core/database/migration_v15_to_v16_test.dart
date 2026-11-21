import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:trip_planner/core/database/database.dart';

/// Schema 16 gives every frame where it is shot from (`lat`, `lng`, `note`,
/// `heading`) and a merged stop the stop it went into (`stops.merged_into`);
/// a schema 15 database keeps its frames, with none of them set.
void main() {
  test('a fresh database is at schema 16 with the frame position columns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 16);
    final columns = {
      for (final r in await db.customSelect('PRAGMA table_info(v10_reference_images)').get()) r.read<String>('name'),
    };
    expect(columns, containsAll(['lat', 'lng', 'note', 'heading']));
    final stopColumns = {
      for (final r in await db.customSelect('PRAGMA table_info(stops)').get()) r.read<String>('name'),
    };
    expect(stopColumns, contains('merged_into'));
  });

  test('upgrading from 15 adds the columns and keeps the frames', () async {
    final dir = await Directory.systemTemp.createTemp('tp_migration_v16_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v15.sqlite');

    // A schema 16 file with a frame, then taken back to how 15 looked.
    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.into(first.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f1',
          stopId: const Value('s1'),
          localPath: const Value('frames/f1.png'),
        ));
    await first.close();
    final raw = sqlite.sqlite3.open(file.path);
    for (final column in ['lat', 'lng', 'note', 'heading']) {
      raw.execute('ALTER TABLE v10_reference_images DROP COLUMN $column');
    }
    raw.execute('ALTER TABLE stops DROP COLUMN merged_into');
    raw.execute('PRAGMA user_version = 15');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final before = await db.select(db.newReferenceImages).getSingle();
    expect(before.localPath, 'frames/f1.png');
    expect(before.lat, isNull);
    expect(before.note, isNull);

    await (db.update(db.newReferenceImages)..where((t) => t.id.equals('f1'))).write(const NewReferenceImagesCompanion(
      lat: Value(34.8921),
      lng: Value(135.8075),
      note: Value('三の間'),
      heading: Value(270),
    ));
    final after = await db.select(db.newReferenceImages).getSingle();
    expect(after.note, '三の間');
    expect(after.heading, 270);
    final stopColumns = {
      for (final r in await db.customSelect('PRAGMA table_info(stops)').get()) r.read<String>('name'),
    };
    expect(stopColumns, contains('merged_into'));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);
  });
}
