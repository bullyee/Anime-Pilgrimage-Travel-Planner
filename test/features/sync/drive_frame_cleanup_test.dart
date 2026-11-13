import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/utils/archive_isolate.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/sync/providers/drive_cleanup_providers.dart';
import 'package:trip_planner/features/sync/services/drive_cleanup_journal.dart';
import 'package:trip_planner/features/sync/services/drive_frame_cleanup.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_queue.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';
import 'package:trip_planner/features/sync/services/transfer_foreground_service.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

import 'fake_transfer_service.dart';

const _folderMime = 'application/vnd.google-apps.folder';

/// An in-memory Google Drive holding this user's app-created files.
class FakeDrive {
  /// ID → {name, mimeType, appProperties, parent}.
  final files = <String, Map<String, Object?>>{};

  /// IDs Drive refuses to delete (another user's file).
  final foreign = <String>{};

  /// Other users' files: their public link still opens.
  final public = <String>{};
  final ranges = <String?>[];
  final deleted = <String>[];
  final calls = <String>[];
  bool offline = false;

  /// Goes offline after this many deletes.
  int? offlineAfterDeletes;

  void add(String id, {String? tripId, String? frameId, bool folder = false, String? name, String? parent}) {
    files[id] = {
      'name': name ?? (folder ? 'Trip $tripId' : 'frame_$frameId.jpg'),
      'mimeType': folder ? _folderMime : 'image/jpeg',
      'appProperties': {'tripId': ?tripId, 'frameId': ?frameId},
      'parent': parent,
    };
  }

  late final MockClient client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    if (offline) throw http.ClientException('Software caused connection abort');
    if (req.method == 'GET' && req.url.host == 'drive.google.com' && req.url.path == '/uc') {
      // The public link, opened without signing in.
      ranges.add(req.headers['Range']);
      final id = req.url.queryParameters['id'];
      if (files.containsKey(id) || public.contains(id)) return http.Response.bytes([0xFF], 206);
      return http.Response('<html>Sorry, the file you have requested does not exist.</html>', 404);
    }
    if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
      final q = req.url.queryParameters['q'];
      final trip = q == null ? null : RegExp(r"key='tripId' and value='([^']+)'").firstMatch(q)?.group(1);
      final all = [
        for (final e in files.entries)
          if (trip == null || (e.value['appProperties'] as Map)['tripId'] == trip)
            {'id': e.key, 'name': e.value['name'], 'mimeType': e.value['mimeType'], 'appProperties': e.value['appProperties']},
      ];
      // Two per page, to exercise paging.
      final start = int.tryParse(req.url.queryParameters['pageToken'] ?? '') ?? 0;
      final page = all.skip(start).take(2).toList();
      return http.Response(
        jsonEncode({'files': page, if (start + 2 < all.length) 'nextPageToken': '${start + 2}'}),
        200,
      );
    }
    if (req.method == 'DELETE') {
      final id = req.url.pathSegments.last;
      if (foreign.contains(id)) return http.Response('{"error":{"message":"insufficientFilePermissions"}}', 403);
      if (!files.containsKey(id)) return http.Response('Not found', 404);
      if (offlineAfterDeletes != null && deleted.length >= offlineAfterDeletes!) {
        throw http.ClientException('Software caused connection abort');
      }
      files.remove(id);
      files.removeWhere((_, f) => f['parent'] == id); // a folder takes its files along
      deleted.add(id);
      return http.Response('', 204);
    }
    return http.Response('Unexpected ${req.method} ${req.url}', 404);
  });
}

String driveUrl(String id) => GoogleDriveFrameService.downloadUrlForFileId(id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Directory tmp;
  late AppDatabase db;
  late DriftTripRepository tripRepo;
  late DriftPlaceRepository placeRepo;
  late FakeDrive fake;
  late InMemoryDriveCleanupJournal journal;
  late DriveFrameCleanup cleanup;
  var tokenFails = false;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('drive_cleanup_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'me', placeRepo);
    fake = FakeDrive();
    journal = InMemoryDriveCleanupJournal();
    tokenFails = false;
    final drive = GoogleDriveFrameService(
      client: fake.client,
      getToken: ({bool interactive = true}) async {
        if (tokenFails && !interactive) throw Exception('needs the user');
        return 'tok';
      },
      retryDelays: const [],
      journal: journal,
    );
    cleanup = DriveFrameCleanup(drive: drive, journal: journal);
    await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl1', name: 'Uji', lat: 34.9, lng: 135.8));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<Trip> sharedTrip(String title) async {
    final trip = await tripRepo.createTrip(title: title, ownerId: 'me', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(const TripsCompanion(sharing: Value('group')));
    return (await tripRepo.getTrip(trip.id))!;
  }

  Future<Stop> stopOn(Trip trip) => tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl1', addedBy: 'me');

  /// A stop frame of this user: a local file with [fileId]'s Drive link.
  Future<void> frame(Stop stop, String id, String? fileId, {String source = 'Google Drive'}) async {
    final local = File(p.join(tmp.path, '$id.jpg'));
    await local.writeAsBytes(img.encodeJpg(img.Image(width: 4, height: 4)));
    await db.into(db.newReferenceImages).insert(
      NewReferenceImagesCompanion.insert(
        id: id,
        stopId: Value(stop.id),
        localPath: Value(local.path),
        remoteUrl: Value(fileId == null ? null : driveUrl(fileId)),
        source: Value(source),
        sourceUrl: Value(fileId == null ? null : driveUrl(fileId)),
      ),
    );
  }

  /// Puts [fileId] on the fake Drive (in [folder]) and in the journal, as an upload does.
  Future<void> uploaded(String fileId, Trip trip, {String? folder}) async {
    fake.add(fileId, tripId: trip.id, frameId: 'fr_$fileId', parent: folder);
    await journal.recordFile(fileId, trip.id);
  }

  Future<void> tripFolder(String folderId, Trip trip) async {
    fake.add(folderId, tripId: trip.id, folder: true);
    await journal.recordFolder(folderId, trip.id);
  }

  Future<NewReferenceImage> row(String id) => (db.select(db.newReferenceImages)..where((r) => r.id.equals(id))).getSingle();

  /// A trip with a folder and two uploaded frames on one stop.
  Future<(Trip, Stop)> tripWithUploads() async {
    final trip = await sharedTrip('Kansai');
    final stop = await stopOn(trip);
    await tripFolder('folder_k', trip);
    await uploaded('d1', trip, folder: 'folder_k');
    await uploaded('d2', trip, folder: 'folder_k');
    await frame(stop, 'r1', 'd1');
    await frame(stop, 'r2', 'd2');
    return (trip, stop);
  }

  Future<void> expectTripTakenBack(Trip trip) async {
    expect(await cleanup.waitingCount(db), 1, reason: 'the trip is waiting');
    final result = await cleanup.sweep(db);
    expect(fake.files, isEmpty);
    expect(fake.deleted.toSet(), {'d1', 'd2', 'folder_k'});
    expect(fake.calls.where((c) => c.startsWith('DELETE')).last, 'DELETE /drive/v3/files/folder_k', reason: 'files first');
    expect(result.framesReset, 2);
    for (final id in ['r1', 'r2']) {
      final r = await row(id);
      expect(r.remoteUrl, isNull);
      expect(r.source, isNull);
      expect(r.sourceUrl, isNull);
      expect(r.localPath, isNotNull);
    }
    expect((await journal.read()).isEmpty, isTrue);
    expect(await cleanup.waitingCount(db), 0);
  }

  group('automatic cleanup', () {
    test('a deleted trip: its files and folder are deleted for good, its frames go back to local-only', () async {
      final (trip, _) = await tripWithUploads();
      expect(await cleanup.waitingCount(db), 0, reason: 'a live shared trip needs its frames');
      await tripRepo.deleteTrip(trip.id);
      await expectTripTakenBack(trip);
    });

    test('an unshared trip', () async {
      final (trip, _) = await tripWithUploads();
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(const TripsCompanion(sharing: Value('private')));
      await expectTripTakenBack(trip);
    });

    test("a trip left: only this user's uploads go; another member's frame is left alone", () async {
      final (trip, stop) = await tripWithUploads();
      await frame(stop, 'theirs', 'their_file', source: 'Mika');
      // What GroupSharingService.leaveTrip leaves: a private copy owned by me.
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(const TripsCompanion(sharing: Value('private'), ownerId: Value('me'), syncStatus: Value(0)));
      await expectTripTakenBack(trip);
      expect(fake.calls, isNot(contains('DELETE /drive/v3/files/their_file')));
      expect((await row('theirs')).remoteUrl, driveUrl('their_file'));
    });

    test('a trip the owner deleted or unshared (sync turned the copy private)', () async {
      final (trip, stop) = await tripWithUploads();
      await tripRepo.deleteStop(stop.id);
      // What SyncEngineServiceV2._convertCollaboratorTripToPrivate writes.
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(const TripsCompanion(ownerId: Value('me'), sharing: Value('private'), deletedAt: Value(null), syncStatus: Value(0)));
      await (db.update(db.stops)..where((s) => s.tripId.equals(trip.id)))
          .write(const StopsCompanion(deletedAt: Value(null), syncStatus: Value(0)));
      await expectTripTakenBack(trip);
    });

    test('a removed stop: its file goes, an identical image another stop still shows stays', () async {
      final trip = await sharedTrip('Kansai');
      final a = await stopOn(trip);
      final b = await stopOn(trip);
      await tripFolder('folder_k', trip);
      await uploaded('only_a', trip, folder: 'folder_k');
      await uploaded('both', trip, folder: 'folder_k');
      await frame(a, 'a1', 'only_a');
      await frame(a, 'a2', 'both');
      await frame(b, 'b1', 'both'); // identical bytes: one upload, two frames
      await tripRepo.deleteStop(a.id);

      expect(await cleanup.waitingCount(db), 1);
      await cleanup.sweep(db);
      expect(fake.deleted, ['only_a']);
      expect(fake.files.keys.toSet(), {'folder_k', 'both'});
      expect((await row('a1')).remoteUrl, isNull);
      expect((await row('b1')).remoteUrl, driveUrl('both'));
      expect((await journal.read()).files, {'both': trip.id});
      expect(await cleanup.waitingCount(db), 0);
    });

    test('a removed frame: its file goes', () async {
      final (_, _) = await tripWithUploads();
      await placeRepo.deleteReferenceImage('r1');
      await cleanup.sweep(db);
      expect(fake.deleted, ['d1']);
      expect((await row('r2')).remoteUrl, driveUrl('d2'));
    });

    test('offline: the removal waits, then finishes on a later pass', () async {
      final (trip, _) = await tripWithUploads();
      await tripRepo.deleteTrip(trip.id);
      fake.offline = true;
      final r = await cleanup.sweep(db);
      expect(r.deleted, 0);
      expect(await cleanup.waitingCount(db), 1);
      expect((await row('r1')).remoteUrl, driveUrl('d1'), reason: 'nothing changes until the file is gone');

      fake.offline = false;
      await expectTripTakenBack(trip);
    });

    test('cut off midway: what was deleted is recorded, the rest waits', () async {
      final (trip, _) = await tripWithUploads();
      await tripRepo.deleteTrip(trip.id);
      fake.offlineAfterDeletes = 1;
      await cleanup.sweep(db);
      expect(fake.deleted, hasLength(1));
      final gone = fake.deleted.single;
      final goneRow = gone == 'd1' ? 'r1' : 'r2';
      expect((await row(goneRow)).remoteUrl, isNull);
      expect((await journal.read()).files.keys, isNot(contains(gone)));
      expect((await journal.read()).pendingTrips, [trip.id]);

      fake.offlineAfterDeletes = null;
      await cleanup.sweep(db);
      expect(fake.files, isEmpty);
      expect(await cleanup.waitingCount(db), 0);
    });

    test('when Google needs the user, nothing is asked: the removal waits', () async {
      final (trip, _) = await tripWithUploads();
      await tripRepo.deleteTrip(trip.id);
      tokenFails = true;
      await cleanup.sweep(db);
      expect(fake.deleted, isEmpty);
      expect(await cleanup.waitingCount(db), 1);
    });

    test('an image another shared trip still uses is kept and handed to that trip', () async {
      final (trip, _) = await tripWithUploads();
      final other = await sharedTrip('Kansai (copy)');
      final otherStop = await stopOn(other);
      await frame(otherStop, 'o1', 'd2');
      await tripRepo.deleteTrip(trip.id);

      final r = await cleanup.sweep(db);
      expect(fake.deleted, ['d1']);
      expect(r.keptInUse, 1);
      expect(fake.files.keys, contains('d2'));
      expect(fake.files.keys, contains('folder_k'), reason: 'd2 inherits its link sharing from the folder');
      expect((await journal.read()).files, {'d2': other.id});
      expect(await cleanup.waitingCount(db), 0);
      expect((await row('o1')).remoteUrl, driveUrl('d2'));

      // When that trip goes too, so does the image.
      await tripRepo.deleteTrip(other.id);
      await cleanup.sweep(db);
      expect(fake.files.keys, isNot(contains('d2')));
    });

    test('nothing recorded, nothing deleted (a fresh install never deletes by guesswork)', () async {
      final trip = await sharedTrip('Kansai');
      final stop = await stopOn(trip);
      fake.add('legacy', tripId: trip.id, frameId: 'x');
      await frame(stop, 'r', 'legacy');
      await tripRepo.deleteTrip(trip.id);
      await cleanup.sweep(db);
      expect(fake.calls, isEmpty);
    });
  });

  group('dead links before an upload', () {
    test('frames whose Drive file is gone go back to local-only; known uploads and links that still open are left', () async {
      final trip = await sharedTrip('Kansai');
      final stop = await stopOn(trip);
      await uploaded('known', trip); // in the journal: not checked
      fake.public.add('teammate'); // someone else's, still opens
      await frame(stop, 'r1', 'old_gone'); // uploaded before the journal, then deleted in Drive by hand
      await frame(stop, 'r2', 'known');
      await frame(stop, 'r3', 'teammate');
      await frame(stop, 'r4', 'old_gone'); // the same file on a second frame

      final ids = await cleanup.linksToCheck(db, trip.id);
      expect(ids, {'old_gone', 'teammate'});
      final progress = <int>[];
      expect(await cleanup.resetGoneLinks(db, ids, onProgress: (done, _) => progress.add(done)), 2);
      expect(progress, [1, 2]);
      expect(fake.ranges, everyElement('bytes=0-0'), reason: 'only the first byte is asked for');

      expect((await row('r1')).remoteUrl, isNull);
      expect((await row('r1')).source, isNull);
      expect((await row('r4')).remoteUrl, isNull);
      expect((await row('r2')).remoteUrl, driveUrl('known'));
      expect((await row('r3')).remoteUrl, driveUrl('teammate'));
      expect(fake.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      final s = await (db.select(db.stops)..where((t) => t.id.equals(stop.id))).getSingle();
      expect(s.syncStatus, 1, reason: 'members drop the dead link');
    });

    test('without a network nothing is reset, and a frame whose image is not on this phone is not checked', () async {
      final trip = await sharedTrip('Kansai');
      final stop = await stopOn(trip);
      await frame(stop, 'r1', 'old_gone');
      await frame(stop, 'r2', 'no_file');
      await File((await row('r2')).localPath!).delete();

      final ids = await cleanup.linksToCheck(db, trip.id);
      expect(ids, {'old_gone'});
      fake.offline = true;
      expect(await cleanup.resetGoneLinks(db, ids), 0);
      expect((await row('r1')).remoteUrl, driveUrl('old_gone'));
    });
  });

  group('explicit removals', () {
    test("removeTripFramesFromDrive on a shared trip finds older uploads too and tells members' phones", () async {
      final (trip, stop) = await tripWithUploads();
      // An upload from before the journal: in the top folder, found by its tripId.
      fake.add('legacy', tripId: trip.id, frameId: 'old');
      await frame(stop, 'r3', 'legacy');
      final other = await sharedTrip('Tokyo');
      await uploaded('tokyo_file', other);
      await (db.update(db.stops)..where((s) => s.id.equals(stop.id))).write(const StopsCompanion(syncStatus: Value(0)));

      final r = await cleanup.removeTripFramesFromDrive(db, trip.id, interactive: true);
      expect(fake.deleted.toSet(), {'d1', 'd2', 'legacy', 'folder_k'});
      expect(fake.files.keys, ['tokyo_file']);
      expect(r.deleted, 4);
      expect(r.framesReset, 3);
      expect((await tripRepo.getStop(stop.id))!.syncStatus, 1, reason: 'pushed, so members drop those frames');
      expect((await journal.read()).files, {'tokyo_file': other.id});
      expect((await journal.read()).pendingTrips, isEmpty);
      expect(r.text, contains('Removed 4 items'));
    });

    test('removeTripFramesFromDrive offline stays pending and rethrows', () async {
      final (trip, _) = await tripWithUploads();
      fake.offline = true;
      await expectLater(cleanup.removeTripFramesFromDrive(db, trip.id), throwsA(isA<http.ClientException>()));
      expect((await journal.read()).pendingTrips, [trip.id]);
      expect(await cleanup.waitingCount(db), 1);
      fake.offline = false;
      await cleanup.sweep(db);
      expect(fake.files, isEmpty);
      expect(await cleanup.waitingCount(db), 0);
    });

    test('removeAllSharedFramesFromDrive deletes everything the app made, trashed and older files too, top folder last', () async {
      final (trip, stop) = await tripWithUploads();
      final other = await sharedTrip('Tokyo');
      final otherStop = await stopOn(other);
      fake.add('app_root', name: GoogleDriveFrameService.appFolderName, folder: true);
      fake.add('legacy_tokyo', tripId: other.id, frameId: 'old', parent: 'app_root');
      await frame(otherStop, 't1', 'legacy_tokyo');
      fake.add('unrelated', name: 'notes.txt'); // not marked as the app's: left alone
      fake.files['unrelated']!['appProperties'] = <String, String>{};

      final r = await cleanup.removeAllSharedFramesFromDrive(db, interactive: true);
      expect(fake.files.keys, ['unrelated']);
      expect(fake.calls.where((c) => c.startsWith('DELETE')).last, 'DELETE /drive/v3/files/app_root');
      expect(fake.calls.where((c) => c.startsWith('GET')).length, greaterThan(1), reason: 'paged listing');
      expect(r.framesReset, 3);
      for (final id in ['r1', 'r2', 't1']) {
        expect((await row(id)).remoteUrl, isNull);
      }
      expect((await tripRepo.getStop(stop.id))!.syncStatus, 1);
      expect((await journal.read()).isEmpty, isTrue);
      expect(trip.id, isNotEmpty);
    });

    test('a file Drive refuses (not this user\'s) is skipped and forgotten', () async {
      final (trip, _) = await tripWithUploads();
      fake.foreign.add('d2');
      await tripRepo.deleteTrip(trip.id);
      await cleanup.sweep(db);
      expect(fake.deleted, contains('d1'));
      expect(fake.calls, contains('DELETE /drive/v3/files/d2'));
      expect(fake.deleted, isNot(contains('d2')));
      expect((await row('r2')).remoteUrl, driveUrl('d2'));
      expect(await cleanup.waitingCount(db), 0);
    });
  });

  test('uploads are recorded: the trip folder, and each file once its frame is committed', () async {
    final trip = await sharedTrip('Kansai');
    final stop = await stopOn(trip);
    await frame(stop, 'new', null);
    final client = MockClient((req) async {
      if (req.method == 'GET') {
        final q = req.url.queryParameters['q'] ?? '';
        return http.Response(
          jsonEncode({
            'files': [
              q.contains('appProperties')
                  ? {
                      'id': 'folder_k',
                      'permissions': [
                        {'type': 'anyone', 'role': 'reader'},
                      ],
                    }
                  : {'id': 'root'},
            ],
          }),
          200,
        );
      }
      if (req.url.path == '/upload/drive/v3/files') {
        return http.Response(
          jsonEncode({
            'id': 'up1',
            'permissions': [
              {'type': 'anyone', 'role': 'reader'},
            ],
          }),
          200,
        );
      }
      return http.Response('?', 404);
    });
    final drive = GoogleDriveFrameService(
      client: client,
      getToken: ({bool interactive = true}) async => 'tok',
      compress: (b) async => b,
      journal: journal,
    );
    await drive.syncTripLocalFrames(db, tripId: trip.id);
    final state = await journal.read();
    expect(state.files, {'up1': trip.id});
    expect(state.folders, {'folder_k': trip.id});
  });

  test('the queue cancels a trip\'s uploads and waits until the running one stopped', () async {
    final container = ProviderContainer(overrides: [
      transferForegroundServiceProvider.overrideWithValue(FakeTransferService()),
      transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
      appVisibleProvider.overrideWithValue(() => true),
    ]);
    addTearDown(container.dispose);
    final queue = container.read(frameTransferQueueProvider.notifier);
    final started = Completer<void>();
    var finished = false;
    queue.enqueue(TransferJobSpec(
      kind: TransferKind.driveUpload,
      tripId: 't1',
      tripTitle: 'T1',
      run: (ctx) async {
        started.complete();
        while (!ctx.cancel.isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20)); // the frames in flight
        finished = true;
        throw const BackupCancelled();
      },
    ));
    queue.enqueue(TransferJobSpec(kind: TransferKind.driveUpload, tripId: 't1', tripTitle: 'T1', dedupe: false, run: (_) async => 'x'));
    queue.enqueue(TransferJobSpec(kind: TransferKind.download, tripId: 't1', tripTitle: 'T1', run: (_) async => 'd'));
    await started.future;
    await queue.cancelUploads(tripId: 't1');
    expect(finished, isTrue);
    final s = container.read(frameTransferQueueProvider);
    expect([for (final q in s.queued) q.kind], isNot(contains(TransferKind.driveUpload)));
    await queue.whenIdle();
  });

  test('the runner cancels uploads of a trip that is no longer shared, then takes its files back', () async {
    final (trip, _) = await tripWithUploads();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('me'),
      driveFrameCleanupProvider.overrideWithValue(cleanup),
      transferForegroundServiceProvider.overrideWithValue(FakeTransferService()),
      transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
      appVisibleProvider.overrideWithValue(() => true),
    ]);
    addTearDown(container.dispose);
    final queue = container.read(frameTransferQueueProvider.notifier);
    final started = Completer<void>();
    var cancelled = false;
    queue.enqueue(TransferJobSpec(
      kind: TransferKind.driveUpload,
      tripId: trip.id,
      tripTitle: trip.title,
      run: (ctx) async {
        started.complete();
        while (!ctx.cancel.isCancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        cancelled = true;
        throw const BackupCancelled();
      },
    ));
    await started.future;
    final runner = container.read(driveCleanupRunnerProvider);

    await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(const TripsCompanion(sharing: Value('private')));
    final result = await runner.sweep();
    expect(cancelled, isTrue);
    expect(result.deleted, 3);
    expect(fake.files, isEmpty);
  });

  test('signed out, the runner does nothing', () async {
    final (trip, _) = await tripWithUploads();
    await tripRepo.deleteTrip(trip.id);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('guest_local_user'),
      driveFrameCleanupProvider.overrideWithValue(cleanup),
      transferForegroundServiceProvider.overrideWithValue(FakeTransferService()),
      transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
    ]);
    addTearDown(container.dispose);
    await container.read(driveCleanupRunnerProvider).sweep();
    expect(fake.calls, isEmpty);
  });
}
