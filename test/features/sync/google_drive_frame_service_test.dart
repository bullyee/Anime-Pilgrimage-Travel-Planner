import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/services/thumbnail_cache_service.dart';
import 'package:trip_planner/core/utils/archive_isolate.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/sync/services/drive_upload_quality.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Uint8List makeJpeg(int width, int height, {int r = 10, int g = 20, int b = 30}) {
    final im = img.Image(width: width, height: height);
    img.fill(im, color: img.ColorRgb8(r, g, b));
    return Uint8List.fromList(img.encodeJpg(im));
  }

  group('GoogleDriveFrameService API & compression', () {
    test('scales an image larger than full HD down to 1920 px', () async {
      final large = makeJpeg(2560, 1440);
      final resized = await GoogleDriveFrameService.compressForDriveUpload(large);
      final decoded = img.decodeImage(resized)!;
      expect(decoded.width, DriveUploadQuality.original.maxEdge);
      expect(decoded.height, 1080);
    });

    test('a frame up to full HD goes up byte for byte, JPEG or PNG', () async {
      final jpeg = makeJpeg(1920, 1080);
      expect(await GoogleDriveFrameService.compressForDriveUpload(jpeg), jpeg);
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 800, height: 450)));
      expect(await GoogleDriveFrameService.compressForDriveUpload(png), png);
    });

    test('Smaller and Smallest scale a full HD frame to 1280 px, smaller files at lower quality', () async {
      // Noise, so the JPEG size depends on the quality.
      final im = img.Image(width: 1920, height: 1080);
      var seed = 7;
      for (final px in im) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        px.setRgb(seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff);
      }
      final full = Uint8List.fromList(img.encodeJpg(im, quality: 95));
      final smaller = await GoogleDriveFrameService.compressForDriveUpload(full, quality: DriveUploadQuality.smaller);
      final smallest = await GoogleDriveFrameService.compressForDriveUpload(full, quality: DriveUploadQuality.smallest);
      expect(img.decodeImage(smaller)!.width, 1280);
      expect(img.decodeImage(smallest)!.width, 1280);
      expect(smallest.length, lessThan(smaller.length));
      expect(smaller.length, lessThan(full.length));
      // Already small enough: goes as it is whatever the choice.
      final small = makeJpeg(1280, 720);
      expect(await GoogleDriveFrameService.compressForDriveUpload(small, quality: DriveUploadQuality.smallest), small);
    });

    test('the service compresses with the quality chosen when the upload runs', () async {
      var chosen = DriveUploadQuality.original;
      final sent = <Uint8List>[];
      final svc = GoogleDriveFrameService(
        getToken: ({bool interactive = true}) async => 't',
        uploadQuality: () async => chosen,
        client: MockClient((req) async {
          if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
            sent.add(req.bodyBytes);
            return http.Response(
                jsonEncode({
                  'id': 'f${sent.length}',
                  'permissions': [
                    {'type': 'anyone', 'role': 'reader'}
                  ]
                }),
                200);
          }
          if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
            return http.Response(
                jsonEncode({
                  'files': [
                    {'id': 'folder_existing'}
                  ]
                }),
                200);
          }
          return http.Response('Unexpected ${req.method} ${req.url}', 404);
        }),
      );
      // The JPEG inside the multipart body: from its start marker to its end marker.
      int widthSent(Uint8List body) {
        var start = 0;
        while (!(body[start] == 0xFF && body[start + 1] == 0xD8 && body[start + 2] == 0xFF)) {
          start++;
        }
        var end = body.length - 2;
        while (!(body[end] == 0xFF && body[end + 1] == 0xD9)) {
          end--;
        }
        return img.decodeJpg(Uint8List.sublistView(body, start, end + 2))!.width;
      }

      final frame = makeJpeg(1920, 1080);
      await svc.uploadImageBytes(rawBytes: frame, frameId: 'a');
      chosen = DriveUploadQuality.smaller;
      await svc.uploadImageBytes(rawBytes: frame, frameId: 'b');
      expect(widthSent(sent[0]), 1920);
      expect(widthSent(sent[1]), 1280);
    });

    test('the upload keeps the type of the file', () {
      expect(GoogleDriveFrameService.uploadType(makeJpeg(4, 4)), ('image/jpeg', 'jpg'));
      expect(GoogleDriveFrameService.uploadType(Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)))),
          ('image/png', 'png'));
    });

    test('creates the app folder and a link-shared trip folder, then uploads into it without a per-file permission', () async {
      final calls = <String>[];
      String? authHeaderSeen;
      var uploadCount = 0;
      final createdFolders = <Map<String, dynamic>>[];

      final mockClient = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        authHeaderSeen = req.headers['Authorization'];
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          expect(req.url.queryParameters['fields'], 'files(id,permissions(type,role))');
          return http.Response(jsonEncode({'files': []}), 200);
        }
        if (req.method == 'POST' && req.url.path == '/drive/v3/files') {
          createdFolders.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'id': createdFolders.length == 1 ? 'folder_root' : 'folder_trip'}), 200);
        }
        if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
          uploadCount++;
          expect(req.headers['Content-Type'], startsWith('multipart/related; boundary='));
          expect(req.url.queryParameters['fields'], 'id,permissions(type,role)');
          expect(utf8.decode(req.bodyBytes, allowMalformed: true), contains('"parents":["folder_trip"]'));
          return http.Response(
            jsonEncode({
              'id': 'file_$uploadCount',
              'permissions': [
                {'type': 'user', 'role': 'owner'},
                {'type': 'anyone', 'role': 'reader'},
              ],
            }),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path == '/drive/v3/files/folder_trip/permissions') {
          final perm = jsonDecode(req.body) as Map<String, dynamic>;
          expect(perm, {'role': 'reader', 'type': 'anyone'});
          return http.Response(jsonEncode({'id': 'anyoneWithLink'}), 200);
        }
        return http.Response('Unexpected ${req.method} ${req.url}', 404);
      });

      final svc = GoogleDriveFrameService(
        client: mockClient,
        getToken: ({bool interactive = true}) async => 'tok_123',
      );
      final res = await svc.uploadImageBytes(
        rawBytes: makeJpeg(640, 360),
        frameId: 'fr1',
        tripId: 't1',
        tripTitle: 'Kansai',
        stopId: 's1',
      );

      expect(authHeaderSeen, 'Bearer tok_123');
      expect(res.fileId, 'file_1');
      expect(res.downloadUrl, 'https://drive.google.com/uc?export=download&id=file_1');
      expect(calls, [
        'GET /drive/v3/files', // app folder
        'POST /drive/v3/files',
        'GET /drive/v3/files', // trip folder
        'POST /drive/v3/files',
        'POST /drive/v3/files/folder_trip/permissions',
        'POST /upload/drive/v3/files',
      ]);
      expect(createdFolders[0], {'name': GoogleDriveFrameService.appFolderName, 'mimeType': 'application/vnd.google-apps.folder'});
      expect(createdFolders[1], {
        'name': 'Kansai',
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': ['folder_root'],
        'appProperties': {'tripId': 't1'},
      });

      // The next frame of the trip is one request: the upload.
      calls.clear();
      await svc.uploadImageBytes(rawBytes: makeJpeg(640, 360), frameId: 'fr2', tripId: 't1', tripTitle: 'Kansai');
      expect(calls, ['POST /upload/drive/v3/files']);
    });

    test('deletes orphan Drive file if granting permission fails', () async {
      final calls = <String>[];
      final mockClient = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'folder_existing'}
              ]
            }),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
          return http.Response(jsonEncode({'id': 'orphan_1'}), 200);
        }
        if (req.method == 'POST' && req.url.path == '/drive/v3/files/orphan_1/permissions') {
          return http.Response('Forbidden', 403);
        }
        if (req.method == 'DELETE' && req.url.path == '/drive/v3/files/orphan_1') {
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      final svc = GoogleDriveFrameService(
        client: mockClient,
        getToken: ({bool interactive = true}) async => 'tok',
      );

      await expectLater(
        svc.uploadImageBytes(rawBytes: makeJpeg(300, 200), frameId: 'f1'),
        throwsA(isA<GoogleDriveUploadException>()),
      );
      expect(calls, contains('DELETE /drive/v3/files/orphan_1'));
    });

    test('refreshes token once silently on HTTP 401 and retries', () async {
      var tokenCalls = 0;
      final mockClient = MockClient((req) async {
        if (req.headers['Authorization'] == 'Bearer stale_tok') {
          return http.Response('Unauthorized', 401);
        }
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'f_id'}
              ]
            }),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
          return http.Response(jsonEncode({'id': 'drv_ok'}), 200);
        }
        if (req.method == 'POST' && req.url.path == '/drive/v3/files/drv_ok/permissions') {
          return http.Response('{}', 200);
        }
        return http.Response('', 404);
      });

      final svc = GoogleDriveFrameService(
        client: mockClient,
        getToken: ({bool interactive = true}) async {
          tokenCalls++;
          return tokenCalls == 1 ? 'stale_tok' : 'fresh_tok';
        },
      );

      final res = await svc.uploadImageBytes(rawBytes: makeJpeg(320, 240), frameId: 'f1');
      expect(tokenCalls, 2);
      expect(res.fileId, 'drv_ok');
    });
  });

  group('GoogleDriveFrameService DB sync & ThumbnailCacheService', () {
    late Directory tmp;
    late AppDatabase db;
    late DriftTripRepository tripRepo;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('drive_sync_test_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tripRepo = DriftTripRepository(db, null, 'owner', DriftPlaceRepository(db));
    });

    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    Future<String> writeJpeg(String name, Uint8List bytes) async {
      final f = File(p.join(tmp.path, name));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes);
      return f.path;
    }

    test('syncTripLocalFrames deduplicates identical bytes, preserves columns, and marks stops dirty', () async {
      final bytesSame1 = makeJpeg(400, 300, r: 100);
      final bytesUnique = makeJpeg(400, 300, r: 220);
      final p1 = await writeJpeg('a1.jpg', bytesSame1);
      final p2Copy = await writeJpeg('a2_same_bytes.jpg', bytesSame1);
      final p3Place = await writeJpeg('p_unique.jpg', bytesUnique);
      final p4OtherTrip = await writeJpeg('other.jpg', bytesUnique);

      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl1', name: 'Obaku', lat: 34.9, lng: 135.8));
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl2', name: 'Uji', lat: 34.9, lng: 135.8));
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl3', name: 'Tokyo', lat: 35.6, lng: 139.7));

      final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'owner', dayCount: 1);
      final stop1 = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl1', addedBy: 'owner');
      final stop2 = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl2', addedBy: 'owner');

      final otherTrip = await tripRepo.createTrip(title: 'Tokyo', ownerId: 'owner', dayCount: 1);
      final otherStop = await tripRepo.addPlaceToTrip(tripId: otherTrip.id, placeKey: 'pl3', addedBy: 'owner');

      // Reset syncStatus to 0
      await (db.update(db.stops)..where((s) => s.tripId.equals(trip.id)))
          .write(const StopsCompanion(syncStatus: Value(0)));

      // stop1 frame + stop2 frame with DIFFERENT paths but IDENTICAL bytes -> only 1 Drive upload!
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'f_s1',
            stopId: Value(stop1.id),
            localPath: Value(p1),
            episode: const Value('5'),
            timestampS: const Value(90),
            source: const Value('You'),
          ));
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'f_s2',
            stopId: Value(stop2.id),
            localPath: Value(p2Copy),
          ));
      // Post-add Place frame -> should upload & attach onto stop1
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'f_place_later',
            placeKey: const Value('pl1'),
            localPath: Value(p3Place),
          ));
      // Frame on another trip -> must stay untouched
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'f_other',
            stopId: Value(otherStop.id),
            localPath: Value(p4OtherTrip),
          ));

      var uploadSeq = 0;
      final mockClient = MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'folder_k'}
              ]
            }),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
          uploadSeq++;
          return http.Response(jsonEncode({'id': 'drv_$uploadSeq'}), 200);
        }
        if (req.method == 'POST' && req.url.path.endsWith('/permissions')) {
          return http.Response('{}', 200);
        }
        return http.Response('', 404);
      });

      final svc = GoogleDriveFrameService(
        client: mockClient,
        getToken: ({bool interactive = true}) async => 'tok',
      );

      expect(await svc.countTripLocalFrames(db, trip.id), 3);
      final summary = await svc.syncTripLocalFrames(db, tripId: trip.id);

      expect(summary.uploaded, 2, reason: 'identical bytes on stop1 and stop2 upload once');
      expect(summary.reused, 1);
      expect(summary.updatedStops, 2);

      // Partial update preserved localPath, episode, timestampS
      final fS1 = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f_s1'))).getSingle();
      expect(fS1.localPath, p1);
      expect(fS1.episode, '5');
      expect(fS1.timestampS, 90);
      // Uploads run concurrently, so either upload may be drv_1.
      expect(
        fS1.remoteUrl,
        anyOf('https://drive.google.com/uc?export=download&id=drv_1', 'https://drive.google.com/uc?export=download&id=drv_2'),
      );

      final fS2 = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f_s2'))).getSingle();
      expect(fS2.remoteUrl, fS1.remoteUrl);

      final stop1Frames = await tripRepo.getReferenceImagesForStop(stop1.id);
      expect(stop1Frames.map((f) => f.remoteUrl).toSet(), {
        'https://drive.google.com/uc?export=download&id=drv_1',
        'https://drive.google.com/uc?export=download&id=drv_2',
      });
      final uniqueUrl = stop1Frames.map((f) => f.remoteUrl).firstWhere((u) => u != fS1.remoteUrl);

      expect((await tripRepo.getStop(stop1.id))!.syncStatus, 1);
      expect((await tripRepo.getStop(stop2.id))!.syncStatus, 1);

      // Finding #3: personal library place row must stay untouched (no Drive remoteUrl written)
      final placeLater =
          await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f_place_later'))).getSingle();
      expect(placeLater.remoteUrl, isNull);

      final otherFrame = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f_other'))).getSingle();
      expect(otherFrame.remoteUrl, isNull);
      expect(await svc.countTripLocalFrames(db, trip.id), 0);

      // Finding #8: a subsequent session reuses existing Drive URL for identical bytes at a different path
      final pSecondSessionSameBytes = await writeJpeg('later_copy.jpg', bytesUnique);
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'f_session2',
            stopId: Value(stop2.id),
            localPath: Value(pSecondSessionSameBytes),
          ));
      final secondSummary = await svc.syncTripLocalFrames(db, tripId: trip.id);
      expect(secondSummary.uploaded, 0);
      expect(secondSummary.reused, 1);
      final fSession2 = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f_session2'))).getSingle();
      expect(fSession2.remoteUrl, uniqueUrl);
    });

    test('mid-sync cancel commits the uploads in flight, starts no more, and uploadNewStopFrame rejects deleted stops', () async {
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl1', name: 'Obaku', lat: 34.9, lng: 135.8));
      final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'owner', dayCount: 1);
      final stop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl1', addedBy: 'owner');

      final paths = <String>[];
      for (var i = 0; i < 6; i++) {
        final path = await writeJpeg('m$i.jpg', makeJpeg(200, 150, r: 10 + 30 * i));
        paths.add(path);
        await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
              id: 'c$i',
              stopId: Value(stop.id),
              localPath: Value(path),
            ));
      }
      final p2 = paths[1];

      final cancel = BackupCancel();
      var uploads = 0;
      final mockClient = MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'folder_1'}
              ]
            }),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
          uploads++;
          cancel.cancel(); // Cancel arrives during upload #1
          return http.Response(jsonEncode({'id': 'drv_u$uploads'}), 200);
        }
        if (req.method == 'POST' && req.url.path.endsWith('/permissions')) {
          return http.Response('{}', 200);
        }
        return http.Response('', 404);
      });

      final svc = GoogleDriveFrameService(
        client: mockClient,
        getToken: ({bool interactive = true}) async => 'tok',
      );

      await expectLater(
        svc.syncTripLocalFrames(db, tripId: trip.id, cancel: cancel),
        throwsA(isA<BackupCancelled>()),
      );

      // The uploads already in flight (at most three) are committed so they
      // aren't orphaned in Drive; no new one starts after the cancel.
      expect(uploads, inInclusiveRange(1, GoogleDriveFrameService.uploadConcurrency));
      final rows = await (db.select(db.newReferenceImages)..where((r) => r.stopId.equals(stop.id))).get();
      final linked = rows.where((r) => r.remoteUrl != null).map((r) => r.remoteUrl).toSet();
      expect(linked, {for (var i = 1; i <= uploads; i++) 'https://drive.google.com/uc?export=download&id=drv_u$i'});
      expect(rows.where((r) => r.remoteUrl == null), hasLength(6 - uploads));
      final uploadsAtCancel = uploads;

      // Deleted stop must refuse BEFORE calling Drive API
      await tripRepo.deleteStop(stop.id);
      await expectLater(
        svc.uploadNewStopFrame(db, tripId: trip.id, stopId: stop.id, localPath: p2),
        throwsStateError,
      );
      expect(uploads, uploadsAtCancel);
    });

    test('ThumbnailCacheService rejects HTML error responses and falls back to lh3 for Drive URLs', () async {
      final jpegBytes = makeJpeg(100, 100);
      final client = MockClient((req) async {
        if (req.url.host == 'drive.google.com') {
          return http.Response('<html>Sign in</html>', 200, headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (req.url.host == 'lh3.googleusercontent.com') {
          return http.Response.bytes(jpegBytes, 200, headers: {'content-type': 'image/jpeg'});
        }
        return http.Response('', 404);
      });

      final cache = ThumbnailCacheService(client: client, overrideCacheDir: tmp);
      final cachedPath = await cache.getOrFetchThumbnail('https://drive.google.com/uc?export=download&id=abc123');
      expect(cachedPath, isNotNull);
      expect(await File(cachedPath!).readAsBytes(), jpegBytes);
    });
  });
}
