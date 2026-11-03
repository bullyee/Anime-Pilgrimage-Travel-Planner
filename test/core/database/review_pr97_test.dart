// Review repros for #97. Each test states what should happen, so it fails on
// 41ca90e and passes once the upgrade is fixed.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:trip_planner/core/database/database.dart';

/// The legacy tables as v0.1.3 (schema 9) left them. [v8] leaves out the
/// four sync columns schema 9 added to `pois`, as v0.1.1 and v0.1.2 have it.
void _createLegacyTables(sqlite.Database raw, {bool v8 = false}) {
  final poiSync = v8
      ? ''
      : '''
      sync_status INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      has_ever_synced INTEGER DEFAULT 0,
      last_modified_at INTEGER,''';
  raw.execute('''
    CREATE TABLE rois (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0, is_offline_cached INTEGER DEFAULT 0, created_at INTEGER DEFAULT 0,
      cloud_version INTEGER DEFAULT 0, sync_lock_expires_at INTEGER);
    CREATE TABLE animes (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, bangumi_id TEXT,
      author_id TEXT NOT NULL, is_shared INTEGER DEFAULT 0, created_at INTEGER DEFAULT 0);
    CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0, created_at INTEGER DEFAULT 0);
    CREATE TABLE pois (
      id TEXT PRIMARY KEY, roi_id TEXT, name TEXT NOT NULL, description TEXT, address TEXT,
      lat REAL NOT NULL, lng REAL NOT NULL, business_hours TEXT, contact_info TEXT,
      local_cover_image_path TEXT, remote_cover_image_url TEXT, sort_order INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0,$poiSync
      author_id TEXT NOT NULL, is_shared INTEGER DEFAULT 0);
    CREATE TABLE poi_animes (poi_id TEXT, anime_id TEXT, PRIMARY KEY (poi_id, anime_id));
    CREATE TABLE poi_tags (poi_id TEXT, tag_id TEXT, PRIMARY KEY (poi_id, tag_id));
    CREATE TABLE reference_images (id TEXT PRIMARY KEY, poi_id TEXT, author_id TEXT NOT NULL, local_path TEXT,
      remote_url TEXT, metadata TEXT, created_at INTEGER DEFAULT 0);
    CREATE TABLE media_assets (id TEXT PRIMARY KEY, poi_id TEXT NOT NULL, author_id TEXT NOT NULL, type TEXT NOT NULL,
      local_path TEXT, remote_url TEXT, metadata TEXT, reference_image_id TEXT, created_at INTEGER DEFAULT 0);
    CREATE TABLE time_chunks (id TEXT PRIMARY KEY, poi_id TEXT, date TEXT, start_time TEXT, end_time TEXT,
      status TEXT, sort_order INTEGER, duration INTEGER, transit_duration INTEGER, is_fixed_time INTEGER,
      author_id TEXT NOT NULL, is_shared INTEGER DEFAULT 0, created_at INTEGER DEFAULT 0);
  ''');
}

/// The legacy tables as v0.1.0 (schema 5) had them before dual-track sync.
void _createSchema5Tables(sqlite.Database raw) {
  raw.execute('''
    CREATE TABLE rois (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE animes (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, bangumi_id TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE pois (
      id TEXT PRIMARY KEY, roi_id TEXT, name TEXT NOT NULL, description TEXT, address TEXT,
      lat REAL NOT NULL, lng REAL NOT NULL, business_hours TEXT, contact_info TEXT,
      cover_image_uri TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE poi_animes (poi_id TEXT, anime_id TEXT, PRIMARY KEY (poi_id, anime_id));
    CREATE TABLE poi_tags (poi_id TEXT, tag_id TEXT, PRIMARY KEY (poi_id, tag_id));
    CREATE TABLE reference_images (id TEXT PRIMARY KEY, poi_id TEXT, local_uri TEXT, remote_url TEXT, metadata TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE media_assets (id TEXT PRIMARY KEY, poi_id TEXT NOT NULL, type TEXT NOT NULL, local_uri TEXT, remote_url TEXT, metadata TEXT, reference_image_id TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE time_chunks (id TEXT PRIMARY KEY, poi_id TEXT, date TEXT, start_time TEXT, end_time TEXT, status TEXT);
  ''');
}

/// The library tables a v12 database has (the trip tables don't matter here).
void _createLibraryTables(sqlite.Database raw) {
  raw.execute('''
    CREATE TABLE places (place_key TEXT PRIMARY KEY, name TEXT NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
      description TEXT, address TEXT, business_hours TEXT, contact_info TEXT, access_tips TEXT, links TEXT,
      cover_local_path TEXT, cover_remote_url TEXT, source TEXT, source_url TEXT, private_note TEXT,
      visibility TEXT NOT NULL DEFAULT 'saved', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
    CREATE TABLE labels (id TEXT PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL, bangumi_id TEXT,
      created_at INTEGER NOT NULL);
    CREATE TABLE place_labels (place_key TEXT NOT NULL, label_id TEXT NOT NULL, PRIMARY KEY (place_key, label_id));
    CREATE TABLE photos (id TEXT PRIMARY KEY, place_key TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'original',
      reference_image_id TEXT, derived_from_id TEXT, trip_id TEXT, local_path TEXT NOT NULL, remote_url TEXT,
      is_shared INTEGER NOT NULL DEFAULT 0, taken_at INTEGER NOT NULL, created_at INTEGER NOT NULL);
    CREATE TABLE place_visits (id TEXT PRIMARY KEY, place_key TEXT NOT NULL, visited_at INTEGER NOT NULL,
      trip_id TEXT, stop_id TEXT, created_at INTEGER NOT NULL);
    CREATE TABLE v10_reference_images (id TEXT PRIMARY KEY, place_key TEXT, local_path TEXT, remote_url TEXT,
      episode TEXT, timestamp_s INTEGER, source TEXT, created_at INTEGER NOT NULL);
  ''');
}

Future<AppDatabase> _open(File file) async {
  final db = AppDatabase.forTesting(NativeDatabase(file));
  addTearDown(db.close);
  return db;
}

void main() {
  late Directory dir;
  late File file;
  final ms = DateTime.utc(2026, 10, 20).millisecondsSinceEpoch;
  final s = ms ~/ 1000;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('review_pr97_');
    file = File('${dir.path}/app.db');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('an install still on v0.1.1 or v0.1.2 (schema 8) upgrades and keeps its spots', () async {
    final raw = sqlite.sqlite3.open(file.path);
    _createLegacyTables(raw, v8: true);
    raw.execute('''
      INSERT INTO pois (id, name, lat, lng, author_id, created_at) VALUES ('uji', 'Uji Bridge', 34.89, 135.80, 'u1', $ms);
      PRAGMA user_version = 8;
    ''');
    raw.dispose();

    final db = await _open(file);
    final places = await db.select(db.places).get();
    expect(places.map((p) => p.name), ['Uji Bridge']);
  });

  test('an install still on v0.1.0 (schema 5) upgrades and preserves places, cover_local_path, and photos', () async {
    final raw = sqlite.sqlite3.open(file.path);
    _createSchema5Tables(raw);
    raw.execute('''
      INSERT INTO rois (id, name, created_at) VALUES ('r1', 'Kyoto', $ms);
      INSERT INTO animes (id, name, bangumi_id, created_at) VALUES ('a1', 'Hibike! Euphonium', '115908', $ms);
      INSERT INTO pois (id, roi_id, name, lat, lng, cover_image_uri, created_at)
        VALUES ('spot1', 'r1', 'Mount Daikichi', 34.89, 135.81, '/covers/daikichi.jpg', $ms);
      INSERT INTO poi_animes (poi_id, anime_id) VALUES ('spot1', 'a1');
      INSERT INTO reference_images (id, poi_id, local_uri, metadata, created_at)
        VALUES ('ref1', 'spot1', '/refs/frame1.jpg', '{"ep":1,"s":120}', $ms);
      INSERT INTO media_assets (id, poi_id, type, local_uri, reference_image_id, created_at)
        VALUES ('photo1', 'spot1', 'user_photo', '/photos/my_daikichi.jpg', 'ref1', $ms);
      PRAGMA user_version = 5;
    ''');
    raw.dispose();

    final db = await _open(file);
    final place = await (db.select(db.places)..where((p) => p.placeKey.equals('spot1'))).getSingle();
    expect(place.name, 'Mount Daikichi');
    expect(place.coverLocalPath, '/covers/daikichi.jpg');

    final labels = await db.select(db.labels).get();
    expect(labels.map((l) => l.name).toSet(), containsAll(['Kyoto', 'Hibike! Euphonium']));

    final links = await db.select(db.placeLabels).get();
    expect(links.length, 2);

    final photo = await (db.select(db.photos)..where((p) => p.id.equals('photo1'))).getSingle();
    expect(photo.localPath, '/photos/my_daikichi.jpg');
    expect(photo.referenceImageId, 'ref1');

    final ref = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('ref1'))).getSingle();
    expect(ref.localPath, '/refs/frame1.jpg');
    expect(ref.episode, '1');
    expect(ref.timestampS, 120);
  });

  group('upgrading a v12 database (the dev phones) keeps the library as it was left', () {
    // Spots A and B came over to `places` at v10 and still sit in `pois`.
    // In the library, B was then merged into A (its photo and frame moved to
    // A, B deleted), C was removed, and the K-On! label was taken off A and
    // deleted as unused. A's own photo was saved by the camera as an edit,
    // which wrote it to both tables with the same id.
    setUp(() {
      final raw = sqlite.sqlite3.open(file.path);
      _createLibraryTables(raw);
      _createLegacyTables(raw);
      raw.execute('''
        INSERT INTO pois (id, name, lat, lng, author_id, created_at) VALUES
          ('a', 'Uji Bridge', 34.89, 135.80, 'u1', $ms),
          ('b', 'Uji Bridge (copy)', 34.89, 135.80, 'u1', $ms),
          ('c', 'Byodoin', 34.88, 135.80, 'u1', $ms);
        INSERT INTO animes (id, name, bangumi_id, author_id, created_at) VALUES ('kon', 'K-On!', '1424', 'u1', $ms);
        INSERT INTO poi_animes (poi_id, anime_id) VALUES ('a', 'kon');
        INSERT INTO media_assets (id, poi_id, author_id, type, local_path, created_at) VALUES
          ('photo-a', 'a', 'u1', 'user_photo', '/photos/a.jpg', $ms),
          ('photo-b', 'b', 'u1', 'user_photo', '/photos/b.jpg', $ms);
        INSERT INTO reference_images (id, poi_id, author_id, local_path, created_at) VALUES
          ('frame-b', 'b', 'u1', '/frames/b.jpg', $ms);

        INSERT INTO places (place_key, name, lat, lng, created_at, updated_at) VALUES
          ('a', 'Uji Bridge', 34.89, 135.80, $s, $s);
        INSERT INTO photos (id, place_key, kind, derived_from_id, local_path, taken_at, created_at) VALUES
          ('photo-a', 'a', 'edited', 'photo-0', '/photos/a.jpg', $s, $s),
          ('photo-b', 'a', 'original', NULL, '/photos/b.jpg', $s, $s);
        INSERT INTO v10_reference_images (id, place_key, local_path, created_at) VALUES
          ('frame-b', 'a', '/frames/b.jpg', $s);
        PRAGMA user_version = 12;
      ''');
      raw.dispose();
    });

    test('merged and removed places stay gone', () async {
      final db = await _open(file);
      final places = await db.select(db.places).get();
      expect(places.map((p) => p.placeKey), ['a']);
    });

    test('photos and frames keep their place and kind', () async {
      final db = await _open(file);
      final photos = {for (final p in await db.select(db.photos).get()) p.id: p};
      final frame = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('frame-b'))).getSingle();
      expect({
        'photo-a kind': photos['photo-a']!.kind,
        'photo-b place': photos['photo-b']!.placeKey,
        'frame-b place': frame.placeKey,
      }, {
        'photo-a kind': 'edited',
        'photo-b place': 'a',
        'frame-b place': 'a',
      });
    });

    test('a label taken off a place and deleted stays deleted', () async {
      final db = await _open(file);
      final labels = await db.select(db.labels).get();
      final links = await db.select(db.placeLabels).get();
      expect([...labels.map((l) => l.name), ...links.map((l) => '${l.placeKey} -> ${l.labelId}')], isEmpty);
    });
  });

  test('reopening a database stamped back to schema 10 does not fail on duplicate column name', () async {
    // 1. Create a database with the current schema (v13)
    var db = await _open(file);
    await db.into(db.trips).insert(
      TripsCompanion.insert(
        id: 't1',
        title: 'Kyoto Trip',
        ownerId: 'u1',
      ),
    );
    await db.into(db.stops).insert(
      StopsCompanion.insert(
        id: 's1',
        tripId: 't1',
        placeKey: 'p1',
        name: 'Uji Bridge',
        lat: 34.89,
        lng: 135.80,
        area: const Value('Uji'),
        note: const Value('Watch sunset'),
        addedBy: 'u1',
      ),
    );
    await db.close();

    // 2. Simulate dev phone where version was stamped back to 10
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 10;');
    raw.dispose();

    // 3. Reopening must succeed without throwing "duplicate column name: area"
    db = await _open(file);
    final stop = await (db.select(db.stops)..where((s) => s.id.equals('s1'))).getSingle();
    expect(stop.area, 'Uji');
    expect(stop.note, 'Watch sunset');
    expect(db.schemaVersion, 13);
  });
}
