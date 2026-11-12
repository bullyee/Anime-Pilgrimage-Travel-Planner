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
import 'package:trip_planner/features/trip/services/trip_frames_pack_service.dart';

void main() {
  const svc = TripFramesPackService();
  late Directory tmp;
  late AppDatabase ownerDb;
  late DriftTripRepository ownerTrips;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('frames_pack_test_');
    ownerDb = AppDatabase.forTesting(NativeDatabase.memory());
    ownerTrips = DriftTripRepository(ownerDb, null, 'owner', DriftPlaceRepository(ownerDb));
  });

  tearDown(() async {
    await ownerDb.close();
    await tmp.delete(recursive: true);
  });

  Future<String> writeImg(String name, [List<int> bytes = const [1, 2, 3, 4]]) async {
    final f = File(p.join(tmp.path, 'src', name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<void> addPlace(AppDatabase db, String key, String name) =>
      db.into(db.places).insert(PlacesCompanion.insert(placeKey: key, name: name, lat: 34.89, lng: 135.80));

  Future<AppDatabase> openReceiverDb() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  test('exports only local-only frames for target trip (including place frames) and skips URL frames', () async {
    final imgStop = await writeImg('stop_custom.jpg', [10, 20, 30]);
    final imgPlaceAfter = await writeImg('place_custom.jpg', [40, 50, 60]);
    final imgOtherTrip = await writeImg('other_trip.jpg', [70, 80, 90]);
    final imgCachedAnitabi = await writeImg('anitabi_cached.jpg', [1, 1, 1]);

    await addPlace(ownerDb, 'p1', 'Obaku Station');
    await addPlace(ownerDb, 'p2', 'Deleted Spot');
    await addPlace(ownerDb, 'p3', 'Other Trip Spot');

    final trip = await ownerTrips.createTrip(title: 'Kansai Pilgrimage', ownerId: 'owner', dayCount: 1);
    final stop1 = await ownerTrips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'owner');
    final stopDeleted = await ownerTrips.addPlaceToTrip(tripId: trip.id, placeKey: 'p2', addedBy: 'owner');
    await ownerTrips.deleteStop(stopDeleted.id);

    final otherTrip = await ownerTrips.createTrip(title: 'Tokyo', ownerId: 'owner', dayCount: 1);
    final otherStop = await ownerTrips.addPlaceToTrip(tripId: otherTrip.id, placeKey: 'p3', addedBy: 'owner');

    // Local-only frame attached directly to stop1
    await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f_stop_local',
          stopId: Value(stop1.id),
          localPath: Value(imgStop),
          episode: const Value('5'),
          source: const Value('You'),
        ));
    // URL-backed frame on stop1 (must NOT be packed)
    await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f_stop_url',
          stopId: Value(stop1.id),
          localPath: Value(imgCachedAnitabi),
          remoteUrl: const Value('https://image.anitabi.cn/frame1.jpg'),
        ));
    // Duplicate local frame already on stop1 via another row, plus a newer place frame added later
    await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f_place_local_new',
          placeKey: const Value('p1'),
          localPath: Value(imgPlaceAfter),
          source: const Value('You'),
        ));
    // Deleted stop & other trip frames (must NOT be packed)
    await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f_deleted_stop',
          stopId: Value(stopDeleted.id),
          localPath: Value(imgOtherTrip),
        ));
    await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f_other_trip',
          stopId: Value(otherStop.id),
          localPath: Value(imgOtherTrip),
        ));

    final packPath = p.join(tmp.path, 'out', 'kansai.${TripFramesPackService.fileExtension}');
    final file = await svc.exportFramesPack(ownerDb, tripId: trip.id, targetPath: packPath);
    final contents = await svc.describeExport(ownerDb, trip.id);
    expect(contents.stops, 1);
    expect(contents.frames, 2);

    // Collaborator device has the synced shared trip (with same tripId & stop1.id)
    final memberDb = await openReceiverDb();
    await addPlace(memberDb, 'p1', 'Obaku Station');
    final memberTrips = DriftTripRepository(memberDb, null, 'member', DriftPlaceRepository(memberDb));
    final syncedTrip = await memberTrips.createTrip(title: 'Kansai Pilgrimage', ownerId: 'owner', dayCount: 1);
    // Insert synced stop matching stop1.id
    await memberDb.into(memberDb.stops).insert(StopsCompanion.insert(
          id: stop1.id,
          tripId: syncedTrip.id,
          placeKey: 'p1',
          name: 'Obaku Station',
          lat: 34.89,
          lng: 135.80,
          addedBy: 'owner',
        ));

    final memberStorage = Directory(p.join(tmp.path, 'member_app'));
    final summary = await svc.importFramesPack(
      memberDb,
      tripId: syncedTrip.id,
      zip: file,
      baseStorageDir: memberStorage,
    );
    expect(summary.framesAdded, 2);
    expect(summary.alreadyPresent, 0);
    expect(summary.unmatchedStops, 0);

    final imported = await (memberDb.select(memberDb.newReferenceImages)..where((r) => r.stopId.equals(stop1.id))).get();
    expect(imported.length, 2);
    for (final f in imported) {
      expect(f.remoteUrl, isNull);
      expect(f.localPath, isNotNull);
      expect(File(f.localPath!).existsSync(), isTrue);
      expect(p.isWithin(p.join(memberStorage.path, 'reference_images'), f.localPath!), isTrue);
    }

    // Re-importing the exact same pack deduplicates by ID/hash
    final repeat = await svc.importFramesPack(
      memberDb,
      tripId: syncedTrip.id,
      zip: file,
      baseStorageDir: memberStorage,
    );
    expect(repeat.framesAdded, 0);
    expect(repeat.alreadyPresent, 2);
  });

  test('falls back to matching placeKey within target trip and isolates other trips', () async {
    final img = await writeImg('custom.jpg', [5, 6, 7]);
    await addPlace(ownerDb, 'p_shared', 'Uji Bridge');
    final srcTrip = await ownerTrips.createTrip(title: 'Trip A', ownerId: 'owner', dayCount: 1);
    final srcStop = await ownerTrips.addPlaceToTrip(tripId: srcTrip.id, placeKey: 'p_shared', addedBy: 'owner');
    await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f1',
          stopId: Value(srcStop.id),
          localPath: Value(img),
        ));

    final zip = await svc.exportFramesPack(
      ownerDb,
      tripId: srcTrip.id,
      targetPath: p.join(tmp.path, 'out', 'a.${TripFramesPackService.fileExtension}'),
    );

    final rxDb = await openReceiverDb();
    await addPlace(rxDb, 'p_shared', 'Uji Bridge');
    await addPlace(rxDb, 'p_other', 'Other');
    final rxTrips = DriftTripRepository(rxDb, null, 'me', DriftPlaceRepository(rxDb));
    final targetTrip = await rxTrips.createTrip(title: 'Trip B', ownerId: 'me', dayCount: 1);
    // Different stopId, same placeKey in targetTrip
    final targetStop = await rxTrips.addPlaceToTrip(tripId: targetTrip.id, placeKey: 'p_shared', addedBy: 'me');
    // Unrelated trip with the SAME placeKey must NOT receive frames
    final unrelatedTrip = await rxTrips.createTrip(title: 'Trip C', ownerId: 'me', dayCount: 1);
    final unrelatedStop = await rxTrips.addPlaceToTrip(tripId: unrelatedTrip.id, placeKey: 'p_shared', addedBy: 'me');

    final summary = await svc.importFramesPack(
      rxDb,
      tripId: targetTrip.id,
      zip: zip,
      baseStorageDir: Directory(p.join(tmp.path, 'rx')),
    );
    expect(summary.framesAdded, 1);
    expect(summary.foreignTripTitle, 'Trip A');

    final onTarget = await (rxDb.select(rxDb.newReferenceImages)..where((r) => r.stopId.equals(targetStop.id))).get();
    final onUnrelated =
        await (rxDb.select(rxDb.newReferenceImages)..where((r) => r.stopId.equals(unrelatedStop.id))).get();
    expect(onTarget.length, 1);
    expect(onUnrelated, isEmpty);
  });

  test('refuses non-zip, wrong format, and newer version packs', () async {
    final notZip = File(p.join(tmp.path, 'junk.pilgrimage-frames'))..writeAsStringSync('not a zip');
    await expectLater(svc.readContents(notZip), throwsA(isA<BackupFormatException>()));

    final wrongFormat = File(p.join(tmp.path, 'lib.pilgrimage'));
    final arc = Archive()
      ..addFile(ArchiveFile.string(
          'manifest.json', jsonEncode({'format': LibraryBackupService.format, 'version': 2})));
    wrongFormat.writeAsBytesSync(ZipEncoder().encode(arc));
    await expectLater(svc.readContents(wrongFormat), throwsA(isA<BackupFormatException>()));

    final newerVersion = File(p.join(tmp.path, 'v99.pilgrimage-frames'));
    final arc2 = Archive()
      ..addFile(ArchiveFile.string(
          'manifest.json', jsonEncode({'format': TripFramesPackService.format, 'version': 99})));
    newerVersion.writeAsBytesSync(ZipEncoder().encode(arc2));
    await expectLater(svc.readContents(newerVersion), throwsA(isA<BackupFormatException>()));
  });

  test('cancelling mid-import leaves DB untouched and removes partial extracted files', () async {
    await addPlace(ownerDb, 'p1', 'Spot 1');
    final trip = await ownerTrips.createTrip(title: 'Cancel Test', ownerId: 'owner', dayCount: 1);
    final stop = await ownerTrips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'owner');
    for (var i = 0; i < 20; i++) {
      final path = await writeImg('cancel_$i.jpg', List.filled(200000, i));
      await ownerDb.into(ownerDb.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'f_$i',
            stopId: Value(stop.id),
            localPath: Value(path),
          ));
    }

    final zip = await svc.exportFramesPack(
      ownerDb,
      tripId: trip.id,
      targetPath: p.join(tmp.path, 'cancel.${TripFramesPackService.fileExtension}'),
    );

    final rxDb = await openReceiverDb();
    await addPlace(rxDb, 'p1', 'Spot 1');
    final rxTrips = DriftTripRepository(rxDb, null, 'me', DriftPlaceRepository(rxDb));
    final rxTrip = await rxTrips.createTrip(title: 'Cancel Test', ownerId: 'owner', dayCount: 1);
    await rxDb.into(rxDb.stops).insert(StopsCompanion.insert(
          id: stop.id,
          tripId: rxTrip.id,
          placeKey: 'p1',
          name: 'Spot 1',
          lat: 34.89,
          lng: 135.80,
          addedBy: 'owner',
        ));

    final storage = Directory(p.join(tmp.path, 'rx_cancel'));
    final cancel = BackupCancel();
    await expectLater(
      svc.importFramesPack(
        rxDb,
        tripId: rxTrip.id,
        zip: zip,
        baseStorageDir: storage,
        cancel: cancel,
        onProgress: (done, _) {
          if (done >= 1) cancel.cancel();
        },
      ),
      throwsA(isA<BackupCancelled>()),
    );

    expect(await rxDb.select(rxDb.newReferenceImages).get(), isEmpty);
    final refDir = Directory(p.join(storage.path, 'reference_images'));
    if (await refDir.exists()) {
      expect(refDir.listSync(), isEmpty);
    }
  });
}
