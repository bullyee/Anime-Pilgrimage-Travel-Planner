import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/services/library_backup_service.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  const svc = LibraryBackupService();
  late Directory tmp;
  late AppDatabase db;
  late DriftTripRepository trips;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trips = DriftTripRepository(db, null, 'me', DriftPlaceRepository(db));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<String> file(String name, [List<int> bytes = const [1, 2, 3]]) async {
    final f = File(p.join(tmp.path, 'src', name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<void> place(String key, {String visibility = 'saved', String? cover, String name = 'Place'}) =>
      db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: key,
            name: name,
            lat: 1,
            lng: 2,
            visibility: Value(visibility),
            coverLocalPath: Value(cover),
          ));

  Future<File> export([AppDatabase? from]) =>
      svc.exportLibraryArchive(from ?? db, targetPath: p.join(tmp.path, 'out', 'b.${LibraryBackupService.fileExtension}'));

  Future<AppDatabase> freshDb() async {
    final d = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(d.close);
    return d;
  }

  Directory restoreDir() => Directory(p.join(tmp.path, 'phone2'));

  Map<String, dynamic> payloadOf(File zip) {
    final arc = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    return jsonDecode(utf8.decode(arc.findFile('library.json')!.content)) as Map<String, dynamic>;
  }

  test('round trip: library and a private trip arrive whole, with their files', () async {
    final cover = await file('cover.jpg', [9, 9]);
    await place('p1', cover: cover, name: 'Uji Bridge');
    await db.into(db.labels).insert(LabelsCompanion.insert(id: 'l1', kind: 'anime', name: 'Eupho', bangumiId: const Value('115908')));
    await db.into(db.placeLabels).insert(PlaceLabelsCompanion.insert(placeKey: 'p1', labelId: 'l1'));
    await db.into(db.placeVisits).insert(PlaceVisitsCompanion.insert(id: 'v1', placeKey: 'p1', date: '2026-06-18'));
    final photo = await file('shot.jpg', [4, 5, 6]);
    await db.into(db.photos).insert(PhotosCompanion.insert(id: 'ph1', placeKey: 'p1', localPath: photo));
    // The cover is also the place's frame: one file in the zip.
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'f1', placeKey: const Value('p1'), localPath: Value(cover), animeLabelId: const Value('l1')));

    final trip = await trips.createTrip(title: 'Kansai', ownerId: 'me', dayCount: 2);
    final days = await (db.select(db.tripDays)..where((d) => d.tripId.equals(trip.id))).get();
    final stop = await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'me', area: 'Uji');
    await trips.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id);
    await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(stopId: stop.id, labelId: 'l1'), mode: InsertMode.insertOrIgnore);
    final stopFrame = await file('mine.jpg', [7]);
    await db.into(db.newReferenceImages).insert(
        NewReferenceImagesCompanion.insert(id: 'sf1', stopId: Value(stop.id), localPath: Value(stopFrame)));

    final contents = await svc.describeExport(db);
    expect(contents.places, 1);
    expect(contents.privateTrips, 1);
    expect(contents.photos, 1);
    expect(contents.bytes, 2 + 3 + 1);

    final progress = <int>[];
    final zip = await svc.exportLibraryArchive(db,
        targetPath: p.join(tmp.path, 'b.pilgrimage'), onProgress: (n, total) => progress.add(n));
    expect(progress.last, 3, reason: 'cover/frame, photo, stop frame: three files');
    expect((await svc.readContents(zip)).privateTrips, 1);

    final db2 = await freshDb();
    final summary = await svc.importLibraryArchive(db2, zip, baseStorageDir: restoreDir());
    expect(summary.places, 1);
    expect(summary.privateTrips, 1);
    expect(summary.photos, 1);
    expect(summary.alreadyHere, 0);

    final p1 = await (db2.select(db2.places)..where((x) => x.placeKey.equals('p1'))).getSingle();
    expect(p1.name, 'Uji Bridge');
    expect(p.isWithin(restoreDir().path, p1.coverLocalPath!), isTrue);
    expect(await File(p1.coverLocalPath!).readAsBytes(), [9, 9]);
    final f1 = await (db2.select(db2.newReferenceImages)..where((x) => x.id.equals('f1'))).getSingle();
    expect(f1.localPath, p1.coverLocalPath, reason: 'one file, used by both');
    final ph = await db2.select(db2.photos).getSingle();
    expect(p.split(ph.localPath), contains('app_photos'));
    expect(await File(ph.localPath).readAsBytes(), [4, 5, 6]);
    expect(await db2.select(db2.placeLabels).get(), hasLength(1));
    expect(await db2.select(db2.placeVisits).get(), hasLength(1));

    final t2 = await db2.select(db2.trips).getSingle();
    expect(t2.title, 'Kansai');
    expect(await db2.select(db2.tripDays).get(), hasLength(2));
    final s2 = await db2.select(db2.stops).getSingle();
    expect(s2.area, 'Uji');
    expect(await db2.select(db2.scheduleItems).get(), hasLength(1));
    expect(await db2.select(db2.stopLabels).get(), hasLength(1));
    final sf = await (db2.select(db2.newReferenceImages)..where((x) => x.stopId.equals(stop.id))).get();
    expect(sf.map((f) => f.id), contains('sf1'));
    expect(await File(sf.firstWhere((f) => f.id == 'sf1').localPath!).readAsBytes(), [7]);
  });

  test('scope: shared trips stay out except frames that never sync; unused trip-only places and deleted trips stay out',
      () async {
    await place('lib', name: 'In the library');
    await place('hidden', visibility: 'trip_only'); // left by a removed trip
    final shared = await trips.createTrip(title: 'Shared', ownerId: 'me');
    await trips.updateTrip(TripsCompanion(id: Value(shared.id), sharing: const Value('group')));
    final spot = await trips.createTripOnlySpot(tripId: shared.id, name: 'Spot', lat: 0, lng: 0, addedBy: 'me');
    final local = await file('local.jpg');
    await db.into(db.newReferenceImages).insert(
        NewReferenceImagesCompanion.insert(id: 'mine', stopId: Value(spot.id), localPath: Value(local)));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'synced', stopId: Value(spot.id), remoteUrl: const Value('https://image.anitabi.cn/x.jpg')));
    final gone = await trips.createTrip(title: 'Deleted', ownerId: 'me');
    await trips.deleteTrip(gone.id);

    final payload = payloadOf(await export());
    expect([for (final t in payload['trips'] as List) t['title']], isEmpty);
    expect(payload['stops'], isEmpty);
    expect([for (final f in payload['referenceImages'] as List) f['id']], ['mine']);
    expect([for (final x in payload['places'] as List) x['placeKey']], ['lib'],
        reason: "the shared trip's spot and the unused hidden place aren't the library");
  });

  test('a shared trip frame finds its stop when the trip comes back after the import', () async {
    final shared = await trips.createTrip(title: 'Shared', ownerId: 'me');
    await trips.updateTrip(TripsCompanion(id: Value(shared.id), sharing: const Value('group')));
    final spot = await trips.createTripOnlySpot(tripId: shared.id, name: 'Spot', lat: 0, lng: 0, addedBy: 'me');
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'mine', stopId: Value(spot.id), localPath: Value(await file('local.jpg'))));
    final zip = await export();

    final db2 = await freshDb();
    await svc.importLibraryArchive(db2, zip, baseStorageDir: restoreDir());
    final frame = await (db2.select(db2.newReferenceImages)..where((f) => f.id.equals('mine'))).getSingle();
    expect(frame.stopId, spot.id);
    expect(await File(frame.localPath!).exists(), isTrue);
  });

  test("import keeps what's on the phone: an older backup doesn't overwrite newer edits", () async {
    await place('p1', name: 'Old name');
    final trip = await trips.createTrip(title: 'Old title', ownerId: 'me');
    final zip = await export();
    await (db.update(db.places)..where((x) => x.placeKey.equals('p1'))).write(const PlacesCompanion(name: Value('Renamed')));
    await trips.updateTrip(TripsCompanion(id: Value(trip.id), title: const Value('New title')));
    await place('p2');

    final summary = await svc.importLibraryArchive(db, zip, baseStorageDir: restoreDir());
    expect(summary.places, 0);
    expect(summary.privateTrips, 0);
    expect(summary.alreadyHere, 2);
    expect((await (db.select(db.places)..where((x) => x.placeKey.equals('p1'))).getSingle()).name, 'Renamed');
    expect((await db.select(db.trips).getSingle()).title, 'New title');
    expect(await db.select(db.places).get(), hasLength(2), reason: 'nothing removed either');
  });

  test('labels the phone already has are used, not duplicated, and references follow them', () async {
    await place('p1');
    await db.into(db.labels).insert(LabelsCompanion.insert(id: 'a-old', kind: 'anime', name: 'Eupho', bangumiId: const Value('1')));
    await db.into(db.labels).insert(LabelsCompanion.insert(id: 't-old', kind: 'tag', name: 'Bridge'));
    await db.into(db.placeLabels).insert(PlaceLabelsCompanion.insert(placeKey: 'p1', labelId: 'a-old'));
    await db.into(db.placeLabels).insert(PlaceLabelsCompanion.insert(placeKey: 'p1', labelId: 't-old'));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'f1', placeKey: const Value('p1'), localPath: Value(await file('f.jpg')), animeLabelId: const Value('a-old')));
    final zip = await export();

    final db2 = await freshDb();
    await db2.into(db2.labels).insert(LabelsCompanion.insert(id: 'a-new', kind: 'anime', name: 'Hibike', bangumiId: const Value('1')));
    await db2.into(db2.labels).insert(LabelsCompanion.insert(id: 't-new', kind: 'tag', name: 'Bridge'));
    await svc.importLibraryArchive(db2, zip, baseStorageDir: restoreDir());

    final labels = await db2.select(db2.labels).get();
    expect(labels.map((l) => l.id).toSet(), {'a-new', 't-new'});
    expect(labels.firstWhere((l) => l.id == 'a-new').name, 'Hibike', reason: "the phone's name is kept");
    expect((await db2.select(db2.placeLabels).get()).map((x) => x.labelId).toSet(), {'a-new', 't-new'});
    expect((await db2.select(db2.newReferenceImages).getSingle()).animeLabelId, 'a-new');
  });

  test('files with the same name are kept apart', () async {
    await place('p1');
    final a = File(p.join(tmp.path, 'a', 'IMG_1.jpg'))..createSync(recursive: true);
    final b = File(p.join(tmp.path, 'b', 'IMG_1.jpg'))..createSync(recursive: true);
    a.writeAsBytesSync([1]);
    b.writeAsBytesSync([2]);
    await db.into(db.photos).insert(PhotosCompanion.insert(id: 'x', placeKey: 'p1', localPath: a.path));
    await db.into(db.photos).insert(PhotosCompanion.insert(id: 'y', placeKey: 'p1', localPath: b.path));
    final zip = await export();
    final db2 = await freshDb();
    await svc.importLibraryArchive(db2, zip, baseStorageDir: restoreDir());
    final photos = {for (final ph in await db2.select(db2.photos).get()) ph.id: ph.localPath};
    expect(photos['x'], isNot(photos['y']));
    expect(File(photos['x']!).readAsBytesSync(), [1]);
    expect(File(photos['y']!).readAsBytesSync(), [2]);
  });

  test('a photo whose file is gone is left out instead of restored broken', () async {
    await place('p1');
    await db.into(db.photos).insert(PhotosCompanion.insert(id: 'gone', placeKey: 'p1', localPath: p.join(tmp.path, 'nope.jpg')));
    expect((await svc.describeExport(db)).photos, 0);
    expect(payloadOf(await export())['photos'], isEmpty);
  });

  group('refuses files it cannot read', () {
    Future<File> zipWith(Map<String, String> entries) async {
      final arc = Archive();
      for (final e in entries.entries) {
        arc.addFile(ArchiveFile.string(e.key, e.value));
      }
      return File(p.join(tmp.path, 'x.pilgrimage'))..writeAsBytesSync(ZipEncoder().encode(arc));
    }

    Future<void> expectRefused(File f, String text) async {
      await expectLater(svc.readContents(f), throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains(text))));
      await expectLater(svc.importLibraryArchive(db, f, baseStorageDir: restoreDir()), throwsA(isA<BackupFormatException>()));
    }

    test('another format', () async {
      await expectRefused(
          await zipWith({'manifest.json': jsonEncode({'format': 'other', 'version': 2}), 'library.json': '{}'}), "isn't a backup");
    });
    test('a newer version', () async {
      await expectRefused(
          await zipWith({'manifest.json': jsonEncode({'format': LibraryBackupService.format, 'version': 3}), 'library.json': '{}'}),
          'newer version');
    });
    test('no manifest', () async {
      await expectRefused(await zipWith({'library.json': '{}'}), "isn't a backup");
    });
    test('not a zip', () async {
      await expectRefused(File(p.join(tmp.path, 'x.pilgrimage'))..writeAsStringSync('hello'), "isn't a backup");
    });
  });

  test('a cancelled export leaves no file behind', () async {
    await place('p1');
    for (var i = 0; i < 20; i++) {
      await db.into(db.photos).insert(PhotosCompanion.insert(id: 'ph$i', placeKey: 'p1', localPath: await file('$i.jpg', List.filled(200000, i))));
    }
    final cancel = BackupCancel();
    final target = p.join(tmp.path, 'c.pilgrimage');
    await expectLater(
      svc.exportLibraryArchive(db, targetPath: target, cancel: cancel, onProgress: (n, _) {
        if (n == 1) cancel.cancel();
      }),
      throwsA(isA<BackupCancelled>()),
    );
    expect(File(target).existsSync(), isFalse);
  });
}
