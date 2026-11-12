import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/providers/thumbnail_cache_provider.dart';
import 'package:trip_planner/core/services/thumbnail_cache_service.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/poi/services/anitabi_api_service.dart';
import 'package:trip_planner/features/sync/providers/frame_transfer_providers.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_jobs.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_queue.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';
import 'package:trip_planner/features/sync/services/transfer_foreground_service.dart';
import 'package:trip_planner/features/sync/services/trip_frame_downloader.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

import 'fake_transfer_service.dart';

/// A fake Drive: folder exists, uploads get sequential IDs, permissions pass.
/// [onUpload] can answer an upload differently (e.g. 401, or throw).
MockClient fakeDrive({List<String>? log, Future<http.Response?> Function(http.Request req, int n)? onUpload}) {
  var uploads = 0;
  return MockClient((req) async {
    log?.add('${req.method} ${req.url.host}${req.url.path} ${req.headers['Authorization']}');
    if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
      return http.Response(jsonEncode({'files': [{'id': 'folder'}]}), 200);
    }
    if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
      uploads++;
      final custom = await onUpload?.call(req, uploads);
      if (custom != null) return custom;
      return http.Response(jsonEncode({'id': 'drv_$uploads'}), 200);
    }
    if (req.method == 'POST' && req.url.path.endsWith('/permissions')) return http.Response('{}', 200);
    if (req.method == 'DELETE') return http.Response('', 204);
    return http.Response('unexpected', 404);
  });
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Directory tmp;
  late AppDatabase db;
  late DriftTripRepository tripRepo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('frame_jobs_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tripRepo = DriftTripRepository(db, null, 'owner', DriftPlaceRepository(db));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<String> writeFile(String name, List<int> bytes) async {
    final f = File(p.join(tmp.path, name));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<Trip> makeTrip({String sharing = 'group', String title = 'Kansai'}) async {
    final trip = await tripRepo.createTrip(title: title, ownerId: 'owner', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(TripsCompanion(sharing: Value(sharing)));
    return (await (db.select(db.trips)..where((t) => t.id.equals(trip.id))).getSingle());
  }

  Future<Stop> addStop(Trip trip, String placeKey) async {
    await db.into(db.places).insertOnConflictUpdate(
          PlacesCompanion.insert(placeKey: placeKey, name: placeKey, lat: 34.9, lng: 135.8),
        );
    return tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: placeKey, addedBy: 'owner');
  }

  Future<void> addFrame(String id, {String? stopId, String? placeKey, String? localPath, String? remoteUrl}) =>
      db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(stopId),
            placeKey: Value(placeKey),
            localPath: Value(localPath),
            remoteUrl: Value(remoteUrl),
          ));

  Future<NewReferenceImage> frame(String id) =>
      (db.select(db.newReferenceImages)..where((r) => r.id.equals(id))).getSingle();

  ProviderContainer makeContainer({
    required FakeTransferService service,
    InMemoryTransferJournal? journal,
    bool Function()? visible,
    GoogleDriveFrameService? drive,
    ThumbnailCacheService? cache,
  }) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      transferForegroundServiceProvider.overrideWithValue(service),
      transferJournalProvider.overrideWithValue(journal ?? InMemoryTransferJournal()),
      appVisibleProvider.overrideWithValue(visible ?? () => true),
      currentUserIdProvider.overrideWithValue('owner'),
      if (drive != null) googleDriveFrameServiceProvider.overrideWithValue(drive),
      if (cache != null) thumbnailCacheServiceProvider.overrideWithValue(cache),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('Drive upload rules (#158)', () {
    final drive = GoogleDriveFrameService(client: fakeDrive(), getToken: ({bool interactive = true}) async => 'tok');

    test('a private trip or a viewer cannot queue an upload', () async {
      final private = await makeTrip(sharing: 'private');
      final shared = await makeTrip(title: 'Shared');
      expect(canUploadTripFramesToDrive(private, canEdit: true), isFalse);
      expect(canUploadTripFramesToDrive(shared, canEdit: false), isFalse);
      expect(canUploadTripFramesToDrive(shared, canEdit: true), isTrue);

      expect(() => driveUploadJob(db: db, drive: drive, trip: private, canEdit: true), throwsStateError);
      expect(() => driveUploadJob(db: db, drive: drive, trip: shared, canEdit: false), throwsStateError);
      expect(
        () => stopUploadJob(db: db, drive: drive, trip: private, canEdit: true, stopId: 's', localPaths: const []),
        throwsStateError,
      );
      expect(
        () => stopUploadJob(db: db, drive: drive, trip: shared, canEdit: false, stopId: 's', localPaths: const []),
        throwsStateError,
      );
    });
  });

  group('Drive upload job', () {
    test('runs in the queue with progress, links stop rows and leaves the library row untouched', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      final s2 = await addStop(trip, 'pl2');
      await addFrame('f1', stopId: s1.id, localPath: await writeFile('a.jpg', [1, 2, 3]));
      await addFrame('f2', stopId: s2.id, localPath: await writeFile('b.jpg', [4, 5, 6]));
      await addFrame('lib', placeKey: 'pl2', localPath: await writeFile('c.jpg', [7, 8, 9]));

      final tokenCalls = <bool>[];
      final drive = GoogleDriveFrameService(
        client: fakeDrive(),
        getToken: ({bool interactive = true}) async {
          tokenCalls.add(interactive);
          return 'tok';
        },
        compress: (b) async => b,
      );
      await drive.prepareToken(); // in the foreground, before queueing
      final service = FakeTransferService();
      final c = makeContainer(service: service, drive: drive);
      final queue = c.read(frameTransferQueueProvider.notifier);
      final progress = <String>[];
      c.listen(frameTransferQueueProvider, (_, s) {
        final j = s.current;
        if (j != null && j.total > 0) progress.add(j.countText);
      });

      queue.enqueue(driveUploadJob(db: db, drive: drive, trip: trip, canEdit: true));
      await queue.whenIdle();

      expect(progress, containsAllInOrder(['0 of 3', '1 of 3', '2 of 3', '3 of 3']));
      expect(tokenCalls, [true], reason: 'only the foreground call may prompt');
      final notice = c.read(frameTransferQueueProvider).notices.single;
      expect(notice.type, TransferNoticeType.done);
      expect(notice.message, contains('Uploaded 3 frames to Google Drive.'));
      expect((await frame('f1')).remoteUrl, GoogleDriveFrameService.downloadUrlForFileId('drv_1'));
      expect((await frame('f2')).remoteUrl, GoogleDriveFrameService.downloadUrlForFileId('drv_2'));
      expect((await frame('lib')).remoteUrl, isNull, reason: 'never write a URL onto the personal library row');
      final s2Rows = await (db.select(db.newReferenceImages)..where((r) => r.stopId.equals(s2.id))).get();
      expect(s2Rows.map((r) => r.remoteUrl), contains(GoogleDriveFrameService.downloadUrlForFileId('drv_3')));
    });

    test('an expired token that needs Google sign-in pauses the job while the app is hidden', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      await addFrame('f1', stopId: s1.id, localPath: await writeFile('a.jpg', [1]));
      await addFrame('f2', stopId: s1.id, localPath: await writeFile('b.jpg', [2]));

      final tokenCalls = <bool>[];
      final drive = GoogleDriveFrameService(
        client: fakeDrive(onUpload: (req, n) async => n >= 2 ? http.Response('expired', 401) : null),
        getToken: ({bool interactive = true}) async {
          tokenCalls.add(interactive);
          if (!interactive) throw const AuthConfigurationException('Google session expired.');
          return 'tok';
        },
        compress: (b) async => b,
      );
      await drive.prepareToken();
      final service = FakeTransferService();
      final journal = InMemoryTransferJournal();
      final c = makeContainer(service: service, journal: journal, drive: drive, visible: () => false);
      final queue = c.read(frameTransferQueueProvider.notifier);

      queue.enqueue(driveUploadJob(db: db, drive: drive, trip: trip, canEdit: true));
      await queue.whenIdle();

      expect(tokenCalls, [true, false], reason: 'a silent refresh only, never an interactive prompt in the background');
      final notice = c.read(frameTransferQueueProvider).notices.single;
      expect(notice.type, TransferNoticeType.needsUser);
      expect(notice.offersResume, isTrue);
      expect(service.lastStop?.title, 'Open Trip Planner to continue');
      expect((await frame('f1')).remoteUrl, isNotNull, reason: 'what was uploaded before the pause is kept');
      expect((await frame('f2')).remoteUrl, isNull);
      expect(await journal.read(), hasLength(1), reason: 'still offered on the next start');
    });

    test('with the app on screen, an expired token asks Google again and carries on', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      await addFrame('f1', stopId: s1.id, localPath: await writeFile('a.jpg', [1]));
      var refreshed = false;
      final tokenCalls = <bool>[];
      final drive = GoogleDriveFrameService(
        client: fakeDrive(
          onUpload: (req, n) async =>
              req.headers['Authorization'] == 'Bearer old' ? http.Response('expired', 401) : null,
        ),
        getToken: ({bool interactive = true}) async {
          tokenCalls.add(interactive);
          if (!interactive) throw const AuthConfigurationException('Google session expired.');
          if (refreshed) return 'new';
          refreshed = true;
          return 'old';
        },
        compress: (b) async => b,
      );
      await drive.prepareToken();
      final c = makeContainer(service: FakeTransferService(), drive: drive, visible: () => true);
      final queue = c.read(frameTransferQueueProvider.notifier);
      queue.enqueue(driveUploadJob(db: db, drive: drive, trip: trip, canEdit: true));
      await queue.whenIdle();

      expect(tokenCalls, [true, false, true]);
      expect(c.read(frameTransferQueueProvider).notices.single.type, TransferNoticeType.done);
      expect((await frame('f1')).remoteUrl, isNotNull);
    });

    test('a dropped connection to Google is retried with backoff', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      await addFrame('f1', stopId: s1.id, localPath: await writeFile('a.jpg', [1]));
      final sleeps = <Duration>[];
      final drive = GoogleDriveFrameService(
        client: fakeDrive(onUpload: (req, n) async {
          if (n == 1) throw http.ClientException('Software caused connection abort');
          if (n == 2) return http.Response('busy', 503);
          return null;
        }),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
        sleep: (d) async => sleeps.add(d),
      );
      final summary = await drive.syncTripLocalFrames(db, tripId: trip.id, interactive: false);
      expect(summary.uploaded, 1);
      expect(sleeps, [const Duration(seconds: 2), const Duration(seconds: 6)]);
      expect((await frame('f1')).remoteUrl, GoogleDriveFrameService.downloadUrlForFileId('drv_3'));
    });

    test('gives up after the last retry with the real cause', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      await addFrame('f1', stopId: s1.id, localPath: await writeFile('a.jpg', [1]));
      final drive = GoogleDriveFrameService(
        client: fakeDrive(onUpload: (req, n) async => throw http.ClientException('Software caused connection abort')),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
        sleep: (_) async {},
      );
      await drive.prepareToken();
      final c = makeContainer(service: FakeTransferService(), drive: drive);
      final queue = c.read(frameTransferQueueProvider.notifier);
      queue.enqueue(driveUploadJob(db: db, drive: drive, trip: trip, canEdit: true));
      await queue.whenIdle();
      final n = c.read(frameTransferQueueProvider).notices.single;
      expect(n.isError, isTrue);
      expect(n.message, contains('Software caused connection abort'));
    });
  });

  group('Frame downloads', () {
    final jpeg = List<int>.generate(64, (i) => i);

    test('pendingUrls skips frames with a file on the phone or a cached copy', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      final local = await writeFile('mine.jpg', [1]);
      await addFrame('a', stopId: s1.id, remoteUrl: 'https://drive.google.com/uc?export=download&id=A');
      await addFrame('b', stopId: s1.id, remoteUrl: 'https://drive.google.com/uc?export=download&id=B', localPath: local);
      await addFrame('c', stopId: s1.id, remoteUrl: 'https://image.anitabi.cn/points/1/c.jpg');
      await addFrame('d', stopId: s1.id, remoteUrl: 'https://cdn.example.com/cached.jpg');
      await addFrame('lib', placeKey: 'pl1', remoteUrl: 'https://drive.google.com/uc?export=download&id=LIB');
      final cache = ThumbnailCacheService(client: MockClient((_) async => http.Response('', 404)), overrideCacheDir: tmp);
      await (await cache.getCacheFile('https://cdn.example.com/cached.jpg')).writeAsBytes([1]);

      final urls = await TripFrameDownloader(cache).pendingUrls(db, trip.id);
      expect(urls, [
        'https://drive.google.com/uc?export=download&id=A',
        'https://image.anitabi.cn/points/1/c.jpg',
      ]);
    });

    test('Anitabi: its User-Agent, no retry on 403, and no further Anitabi requests; Drive gets retried', () async {
      final requests = <http.Request>[];
      var driveAttempts = 0;
      final client = MockClient((req) async {
        requests.add(req);
        if (req.url.host.endsWith('anitabi.cn')) return http.Response('blocked', 403);
        if (req.url.host == 'drive.google.com') {
          driveAttempts++;
          if (driveAttempts == 1) throw http.ClientException('Software caused connection abort');
          return http.Response.bytes(jpeg, 200, headers: {'content-type': 'image/jpeg'});
        }
        if (req.url.host == 'lh3.googleusercontent.com') return http.Response('', 404);
        return http.Response('', 404);
      });
      final cache = ThumbnailCacheService(client: client, overrideCacheDir: tmp);
      final sleeps = <Duration>[];
      final downloader = TripFrameDownloader(cache, sleep: (d) async => sleeps.add(d));

      final summary = await downloader.download([
        'https://image.anitabi.cn/points/1/a.jpg',
        'https://image.anitabi.cn/points/1/b.jpg',
        'https://drive.google.com/uc?export=download&id=D1',
      ]);

      final anitabiRequests = requests.where((r) => r.url.host.endsWith('anitabi.cn')).toList();
      expect(anitabiRequests, hasLength(1), reason: 'no retry, no mirror, no second image after a 403');
      expect(requests.every((r) => r.headers['User-Agent'] == AnitabiApiService.userAgent), isTrue);
      expect(requests.any((r) => r.url.host == 'api.anitabi.cn'), isFalse);
      expect(summary.downloaded, 1);
      expect(summary.skippedBlocked, 2);
      expect(summary.failed, 0);
      expect(sleeps, [const Duration(seconds: 3)], reason: 'only the Drive link waits and tries again');
      expect(summary.text, contains('Anitabi is refusing requests for now'));
    });

    test('download runs in the queue and can be cancelled between frames', () async {
      final trip = await makeTrip();
      final s1 = await addStop(trip, 'pl1');
      for (var i = 0; i < 5; i++) {
        await addFrame('f$i', stopId: s1.id, remoteUrl: 'https://cdn.example.com/$i.jpg');
      }
      late ProviderContainer c;
      var fetched = 0;
      final client = MockClient((req) async {
        fetched++;
        if (fetched == 2) c.read(frameTransferQueueProvider.notifier).cancelCurrent();
        return http.Response.bytes(jpeg, 200, headers: {'content-type': 'image/jpeg'});
      });
      final cache = ThumbnailCacheService(client: client, overrideCacheDir: tmp);
      c = makeContainer(service: FakeTransferService(), cache: cache);
      final queue = c.read(frameTransferQueueProvider.notifier);
      queue.enqueue(frameDownloadJob(
        db: db,
        downloader: c.read(tripFrameDownloaderProvider),
        tripId: trip.id,
        tripTitle: trip.title,
      ));
      await queue.whenIdle();
      expect(fetched, 2);
      expect(c.read(frameTransferQueueProvider).notices.single.message, 'Download cancelled.');
    });
  });

  group('Start-up resume and automatic downloads', () {
    test('an interrupted upload becomes "N frames left · Resume"; an interrupted download runs again', () async {
      final up = await makeTrip(title: 'Up');
      final s1 = await addStop(up, 'pl1');
      await addFrame('f1', stopId: s1.id, localPath: await writeFile('a.jpg', [1]));
      await addFrame('f2', stopId: s1.id, localPath: await writeFile('b.jpg', [2]));
      final down = await makeTrip(title: 'Down');
      final s2 = await addStop(down, 'pl2');
      await addFrame('r1', stopId: s2.id, remoteUrl: 'https://cdn.example.com/r1.jpg');

      final journal = InMemoryTransferJournal()
        ..entries.addAll([
          TransferJournalEntry(kind: TransferKind.driveUpload, tripId: up.id, tripTitle: 'Up'),
          TransferJournalEntry(kind: TransferKind.download, tripId: down.id, tripTitle: 'Down'),
        ]);
      final uploads = <String>[];
      final drive = GoogleDriveFrameService(
        client: fakeDrive(log: uploads),
        getToken: ({bool interactive = true}) async => 'tok',
      );
      final cache = ThumbnailCacheService(
        client: MockClient((_) async => http.Response.bytes([1, 2], 200, headers: {'content-type': 'image/jpeg'})),
        overrideCacheDir: tmp,
      );
      final c = makeContainer(service: FakeTransferService(), journal: journal, drive: drive, cache: cache);

      await c.read(frameTransferResumeProvider.future);
      final notice = c.read(frameTransferQueueProvider).notices.single;
      expect(notice.type, TransferNoticeType.resumable);
      expect(notice.tripId, up.id);
      expect(notice.message, '2 frames left to upload to Google Drive.');
      expect(c.read(frameTransferQueueProvider).jobFor(up.id, TransferKind.driveUpload), isNull,
          reason: 'uploads never start by themselves (they need a Google token)');

      await c.read(frameTransferQueueProvider.notifier).whenIdle();
      expect(uploads, isEmpty);
      expect(await (await cache.getCacheFile('https://cdn.example.com/r1.jpg')).exists(), isTrue);
    });

    test('new Drive frames on a shared trip download by themselves on an unmetered network, Anitabi ones do not',
        () async {
      final shared = await makeTrip();
      final s1 = await addStop(shared, 'pl1');
      await addFrame('d', stopId: s1.id, remoteUrl: 'https://drive.google.com/uc?export=download&id=D');
      await addFrame('a', stopId: s1.id, remoteUrl: 'https://image.anitabi.cn/points/1/a.jpg');
      final private = await makeTrip(sharing: 'private', title: 'Mine');
      final s2 = await addStop(private, 'pl2');
      await addFrame('p', stopId: s2.id, remoteUrl: 'https://drive.google.com/uc?export=download&id=P');

      final hosts = <String>[];
      final cache = ThumbnailCacheService(
        client: MockClient((req) async {
          hosts.add('${req.url.host}${req.url.query}');
          return http.Response.bytes([1, 2], 200, headers: {'content-type': 'image/jpeg'});
        }),
        overrideCacheDir: tmp,
      );
      final service = FakeTransferService()..unmetered = false;
      final c = makeContainer(service: service, cache: cache);
      final auto = c.read(frameAutoDownloaderProvider);

      await auto.check();
      expect(c.read(frameTransferQueueProvider).isBusy, isFalse, reason: 'metered network: wait');
      expect(hosts, isEmpty);

      service.unmetered = true;
      await auto.check();
      await c.read(frameTransferQueueProvider.notifier).whenIdle();
      expect(hosts, ['drive.google.comexport=download&id=D']);
      expect(c.read(frameTransferQueueProvider).notices, isEmpty, reason: 'automatic downloads are quiet');

      // Already tried this session: not again.
      await auto.check();
      await c.read(frameTransferQueueProvider.notifier).whenIdle();
      expect(hosts, hasLength(1));
    });
  });
}
