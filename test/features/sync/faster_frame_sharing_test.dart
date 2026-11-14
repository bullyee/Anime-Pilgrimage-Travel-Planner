import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_jobs.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';
import 'package:trip_planner/features/sync/services/online_frame_matcher.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

/// A blocky random picture: the same [seed] gives the same picture at any size.
img.Image pattern(int seed, int width, int height) {
  final rnd = Random(seed);
  const cols = 24, rows = 14;
  final colors = [
    for (var i = 0; i < cols * rows; i++) img.ColorRgb8(rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256)),
  ];
  final im = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      im.setPixel(x, y, colors[(y * rows ~/ height) * cols + (x * cols ~/ width)]);
    }
  }
  return im;
}

Uint8List patternJpeg(int seed, int width, int height, {int quality = 90}) =>
    Uint8List.fromList(img.encodeJpg(pattern(seed, width, height), quality: quality));

/// [seed]'s picture at [width] x [height] inside black bars above and below.
Uint8List letterboxedJpeg(int seed, int width, int height, int bar) {
  final inner = pattern(seed, width, height);
  final im = img.Image(width: width, height: height + 2 * bar);
  img.fill(im, color: img.ColorRgb8(0, 0, 0));
  img.compositeImage(im, inner, dstY: bar);
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

Map<String, String> appPropertiesOf(http.Request req) {
  final body = utf8.decode(req.bodyBytes, allowMalformed: true);
  final m = RegExp(r'"appProperties":(\{[^}]*\})').firstMatch(body);
  return m == null ? {} : (jsonDecode(m.group(1)!) as Map).cast<String, String>();
}

const _anyoneReader = [
  {'type': 'user', 'role': 'owner'},
  {'type': 'anyone', 'role': 'reader'},
];

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('FrameHash', () {
    test('the same picture at other sizes and qualities is a few bits apart; other pictures are far', () {
      final a = FrameHash.compute(patternJpeg(1, 640, 360))!;
      final aBig = FrameHash.compute(patternJpeg(1, 1920, 1080, quality: 70))!;
      final aBars = FrameHash.compute(letterboxedJpeg(1, 640, 360, 60))!;
      final b = FrameHash.compute(patternJpeg(2, 640, 360))!;
      expect(a.distance(a), 0);
      expect(a.distance(aBig), lessThanOrEqualTo(OnlineFrameMatcher.maxDistance));
      expect(a.distance(aBars), lessThanOrEqualTo(OnlineFrameMatcher.maxDistance), reason: 'letterbox bars are trimmed');
      expect(a.distance(b), greaterThan(60));
    });

    test('undecodable bytes hash to null', () async {
      expect(FrameHash.compute(Uint8List.fromList([1, 2, 3])), isNull);
      expect(await FrameHash.computeAll([Uint8List.fromList([1, 2, 3])]), [null]);
    });

    test('distanceMeters is about right in Kyoto', () {
      // 0.001 degrees of latitude ≈ 111 m.
      expect(distanceMeters(34.9, 135.8, 34.901, 135.8), closeTo(111, 2));
    });
  });

  group('Trip folders on Drive', () {
    late List<String> calls;

    GoogleDriveFrameService service(MockClient client, {DriveTokenFetcher? getToken}) => GoogleDriveFrameService(
      client: client,
      getToken: getToken ?? ({bool interactive = true}) async => 'tok',
      compress: (b) async => b,
      retryDelays: const [],
    );

    setUp(() => calls = []);

    test('an existing link-shared trip folder is used as it is', () async {
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          final q = req.url.queryParameters['q']!;
          if (q.contains("appProperties has { key='tripId' and value='t1' }")) {
            expect(q, contains("'root_1' in parents"));
            return http.Response(jsonEncode({'files': [{'id': 'trip_1', 'permissions': _anyoneReader}]}), 200);
          }
          return http.Response(jsonEncode({'files': [{'id': 'root_1'}]}), 200);
        }
        if (req.url.path == '/upload/drive/v3/files') {
          return http.Response(jsonEncode({'id': 'f1', 'permissions': _anyoneReader}), 200);
        }
        return http.Response('Unexpected', 404);
      });
      await service(client).uploadImageBytes(rawBytes: patternJpeg(1, 64, 36), frameId: 'x', tripId: 't1');
      expect(calls, ['GET /drive/v3/files', 'GET /drive/v3/files', 'POST /upload/drive/v3/files']);
    });

    test('an existing trip folder without the link permission gets it (once)', () async {
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          final q = req.url.queryParameters['q']!;
          if (q.contains('appProperties')) {
            return http.Response(jsonEncode({'files': [{'id': 'trip_1', 'permissions': [{'type': 'user', 'role': 'owner'}]}]}), 200);
          }
          return http.Response(jsonEncode({'files': [{'id': 'root_1'}]}), 200);
        }
        if (req.url.path == '/drive/v3/files/trip_1/permissions') return http.Response('{}', 200);
        if (req.url.path == '/upload/drive/v3/files') {
          return http.Response(jsonEncode({'id': 'f${calls.length}', 'permissions': _anyoneReader}), 200);
        }
        return http.Response('Unexpected', 404);
      });
      final svc = service(client);
      await svc.uploadImageBytes(rawBytes: patternJpeg(1, 64, 36), frameId: 'x', tripId: 't1');
      await svc.uploadImageBytes(rawBytes: patternJpeg(2, 64, 36), frameId: 'y', tripId: 't1');
      expect(calls.where((c) => c == 'POST /drive/v3/files/trip_1/permissions'), hasLength(1));
      expect(calls.where((c) => c.contains('/permissions')), hasLength(1), reason: 'no per-file permission');
    });

    test('when Drive does not report the inherited link, the file is shared on its own', () async {
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'GET') {
          final q = req.url.queryParameters['q']!;
          return http.Response(
            jsonEncode({'files': [q.contains('appProperties') ? {'id': 'trip_1', 'permissions': _anyoneReader} : {'id': 'root_1'}]}),
            200,
          );
        }
        if (req.url.path == '/upload/drive/v3/files') return http.Response(jsonEncode({'id': 'f1'}), 200);
        if (req.url.path == '/drive/v3/files/f1/permissions') return http.Response('{}', 200);
        return http.Response('Unexpected', 404);
      });
      await service(client).uploadImageBytes(rawBytes: patternJpeg(1, 64, 36), frameId: 'x', tripId: 't1');
      expect(calls.last, 'POST /drive/v3/files/f1/permissions');
    });

    test('a new trip folder that cannot be shared is deleted and the upload fails', () async {
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'GET') {
          final q = req.url.queryParameters['q']!;
          return http.Response(jsonEncode({'files': q.contains('appProperties') ? [] : [{'id': 'root_1'}]}), 200);
        }
        if (req.method == 'POST' && req.url.path == '/drive/v3/files') return http.Response(jsonEncode({'id': 'trip_new'}), 200);
        if (req.url.path == '/drive/v3/files/trip_new/permissions') return http.Response('Forbidden', 403);
        if (req.method == 'DELETE') return http.Response('', 204);
        return http.Response('Unexpected', 404);
      });
      await expectLater(
        service(client).uploadImageBytes(rawBytes: patternJpeg(1, 64, 36), frameId: 'x', tripId: 't1'),
        throwsA(isA<GoogleDriveUploadException>()),
      );
      expect(calls, contains('DELETE /drive/v3/files/trip_new'));
      expect(calls, isNot(contains('POST /upload/drive/v3/files')));
    });

    test('without a trip, the file goes into the app folder and is shared on its own', () async {
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.method == 'GET') return http.Response(jsonEncode({'files': [{'id': 'root_1'}]}), 200);
        if (req.url.path == '/upload/drive/v3/files') {
          expect(utf8.decode(req.bodyBytes, allowMalformed: true), contains('"parents":["root_1"]'));
          return http.Response(jsonEncode({'id': 'f1'}), 200);
        }
        if (req.url.path == '/drive/v3/files/f1/permissions') return http.Response('{}', 200);
        return http.Response('Unexpected', 404);
      });
      await service(client).uploadImageBytes(rawBytes: patternJpeg(1, 64, 36), frameId: 'x');
      expect(calls, ['GET /drive/v3/files', 'POST /upload/drive/v3/files', 'POST /drive/v3/files/f1/permissions']);
    });
  });

  group('syncTripLocalFrames', () {
    late Directory tmp;
    late AppDatabase db;
    late DriftTripRepository tripRepo;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('faster_frames_test_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tripRepo = DriftTripRepository(db, null, 'owner', DriftPlaceRepository(db));
    });

    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    Future<String> write(String name, Uint8List bytes) async {
      final f = File(p.join(tmp.path, name));
      await f.writeAsBytes(bytes);
      return f.path;
    }

    Future<Stop> tripWithStop({double lat = 34.9, double lng = 135.8}) async {
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'anitabi:p1', name: 'Obaku', lat: lat, lng: lng));
      final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'owner', dayCount: 1);
      return tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'anitabi:p1', addedBy: 'owner');
    }

    Future<void> addStopFrame(Stop stop, String id, Uint8List bytes, {String? anime, String? source}) async {
      await db.into(db.newReferenceImages).insert(
        NewReferenceImagesCompanion.insert(
          id: id,
          stopId: Value(stop.id),
          localPath: Value(await write('$id.jpg', bytes)),
          animeLabelId: Value(anime),
          source: Value(source),
        ),
      );
    }

    Future<NewReferenceImage> frame(String id) =>
        (db.select(db.newReferenceImages)..where((r) => r.id.equals(id))).getSingle();

    /// A Drive fake: folders exist and are link-shared, each upload gets the
    /// next ID after [uploadDelay], and [onUpload] may answer instead.
    MockClient drive({
      required List<String> uploadedFrameIds,
      Duration uploadDelay = Duration.zero,
      FutureOr<http.Response?> Function(http.Request req, String frameId)? onUpload,
      List<String>? deleted,
      void Function(int inFlight)? onInFlight,
      String? rejectToken,
    }) {
      var inFlight = 0;
      return MockClient((req) async {
        if (rejectToken != null && req.headers['Authorization'] == 'Bearer $rejectToken') {
          return http.Response('Unauthorized', 401);
        }
        if (req.method == 'GET' && req.url.path == '/drive/v3/files') {
          final q = req.url.queryParameters['q']!;
          return http.Response(
            jsonEncode({'files': [q.contains('appProperties') ? {'id': 'trip_1', 'permissions': _anyoneReader} : {'id': 'root_1'}]}),
            200,
          );
        }
        if (req.method == 'POST' && req.url.path == '/upload/drive/v3/files') {
          final frameId = appPropertiesOf(req)['frameId']!;
          inFlight++;
          onInFlight?.call(inFlight);
          try {
            await Future<void>.delayed(uploadDelay);
            final custom = await onUpload?.call(req, frameId);
            if (custom != null) return custom;
            uploadedFrameIds.add(frameId);
            return http.Response(jsonEncode({'id': 'drv_$frameId', 'permissions': _anyoneReader}), 200);
          } finally {
            inFlight--;
          }
        }
        if (req.method == 'DELETE') {
          deleted?.add(req.url.pathSegments.last);
          return http.Response('', 204);
        }
        return http.Response('Unexpected ${req.method} ${req.url}', 404);
      });
    }

    test('uploads three at a time and commits every frame', () async {
      final stop = await tripWithStop();
      for (var i = 0; i < 7; i++) {
        await addStopFrame(stop, 'k$i', patternJpeg(100 + i, 96, 54));
      }
      final uploaded = <String>[];
      var maxInFlight = 0;
      final svc = GoogleDriveFrameService(
        client: drive(
          uploadedFrameIds: uploaded,
          uploadDelay: const Duration(milliseconds: 40),
          onInFlight: (n) => maxInFlight = max(maxInFlight, n),
        ),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
      );
      final progress = <int>[];
      final summary = await svc.syncTripLocalFrames(db, tripId: stop.tripId, onProgress: (d, t) => progress.add(d));
      expect(maxInFlight, GoogleDriveFrameService.uploadConcurrency);
      expect(summary.uploaded, 7);
      expect(uploaded.toSet(), {for (var i = 0; i < 7; i++) 'k$i'});
      for (var i = 0; i < 7; i++) {
        expect((await frame('k$i')).remoteUrl, GoogleDriveFrameService.downloadUrlForFileId('drv_k$i'));
      }
      expect(progress.first, 0);
      expect(progress.last, 7);
      expect(await svc.countTripLocalFrames(db, stop.tripId), 0);
    });

    test('on the first error no new upload starts; the ones in flight are committed', () async {
      final stop = await tripWithStop();
      for (var i = 0; i < 6; i++) {
        await addStopFrame(stop, 'e$i', patternJpeg(200 + i, 96, 54));
      }
      final uploaded = <String>[];
      var attempts = 0;
      final svc = GoogleDriveFrameService(
        client: drive(
          uploadedFrameIds: uploaded,
          onUpload: (req, frameId) async {
            attempts++;
            if (frameId == 'e0') return http.Response('Forbidden', 403);
            await Future<void>.delayed(const Duration(milliseconds: 80));
            return null;
          },
        ),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
      );
      await expectLater(svc.syncTripLocalFrames(db, tripId: stop.tripId), throwsA(isA<GoogleDriveUploadException>()));
      expect(attempts, 3, reason: 'e0 fails first; the two in flight finish; nothing new starts');
      final linked = [
        for (var i = 0; i < 6; i++)
          if ((await frame('e$i')).remoteUrl != null) 'e$i',
      ];
      expect(linked.toSet(), uploaded.toSet());
      expect(linked, hasLength(2));
      expect(await svc.countTripLocalFrames(db, stop.tripId), 4, reason: 'resume picks up the rest');
    });

    test('a file uploaded for a stop deleted meanwhile is deleted from Drive and not counted', () async {
      final stop = await tripWithStop();
      final other = await tripRepo.addPlaceToTrip(tripId: stop.tripId, placeKey: 'anitabi:p1', addedBy: 'owner');
      await addStopFrame(stop, 'gone', patternJpeg(301, 96, 54));
      await addStopFrame(other, 'kept', patternJpeg(302, 96, 54));
      final uploaded = <String>[];
      final deleted = <String>[];
      final svc = GoogleDriveFrameService(
        client: drive(
          uploadedFrameIds: uploaded,
          deleted: deleted,
          onUpload: (req, frameId) async {
            if (frameId == 'gone') await tripRepo.deleteStop(stop.id);
            return null;
          },
        ),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
      );
      final summary = await svc.syncTripLocalFrames(db, tripId: stop.tripId);
      expect(uploaded.toSet(), {'gone', 'kept'});
      expect(deleted, ['drv_gone']);
      expect(summary.uploaded, 1);
      expect((await frame('gone')).remoteUrl, isNull);
      expect((await frame('kept')).remoteUrl, isNotNull);
    });

    test('concurrent uploads that hit an expired token refresh it once', () async {
      final stop = await tripWithStop();
      for (var i = 0; i < 3; i++) {
        await addStopFrame(stop, 'a$i', patternJpeg(400 + i, 96, 54));
      }
      var tokenCalls = 0;
      final uploaded = <String>[];
      final svc = GoogleDriveFrameService(
        client: drive(uploadedFrameIds: uploaded, uploadDelay: const Duration(milliseconds: 10), rejectToken: 'stale'),
        getToken: ({bool interactive = true}) async => ++tokenCalls == 1 ? 'stale' : 'fresh',
        compress: (b) async => b,
      );
      final summary = await svc.syncTripLocalFrames(db, tripId: stop.tripId, interactive: false);
      expect(summary.uploaded, 3);
      expect(tokenCalls, 2);
    });

    test('a frame that is already online at Anitabi takes that link instead of being uploaded', () async {
      final stop = await tripWithStop();
      // Library frames (cached Anitabi images): one at the stop's place, one
      // 80 km away, and one of another anime.
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'anitabi:far', name: 'Tokyo', lat: 35.6, lng: 139.7));
      Future<void> libraryFrame(String id, String placeKey, int seed, String anime) async {
        await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: id,
            placeKey: Value(placeKey),
            localPath: Value(await write('$id.jpg', patternJpeg(seed, 640, 360, quality: 80))),
            remoteUrl: Value('https://image.anitabi.cn/points/1/$id.jpg?plan=h360'),
            animeLabelId: Value(anime),
            source: const Value('甜食伯爵'),
            sourceUrl: Value('https://anitabi.cn/map?bangumiId=1&pid=$id'),
          ),
        );
      }

      await libraryFrame('libA', 'anitabi:p1', 1, 'anime1');
      await libraryFrame('libFar', 'anitabi:far', 3, 'anime1');
      await libraryFrame('libOther', 'anitabi:p1', 4, 'anime2');

      // The user's own copies: A letterboxed; B new; C and D are only online
      // too far away / for another anime; A2 has its own source; E is A at
      // full HD, sharper than Anitabi's link, so it's uploaded.
      await addStopFrame(stop, 'mineA', letterboxedJpeg(1, 640, 360, 40), anime: 'anime1');
      await addStopFrame(stop, 'mineA2', patternJpeg(1, 640, 360, quality: 75), anime: 'anime1', source: 'My notes');
      await addStopFrame(stop, 'mineE', patternJpeg(1, 1920, 1080), anime: 'anime1');
      await addStopFrame(stop, 'mineB', patternJpeg(2, 1280, 720), anime: 'anime1');
      await addStopFrame(stop, 'mineC', patternJpeg(3, 1280, 720), anime: 'anime1');
      await addStopFrame(stop, 'mineD', patternJpeg(4, 1280, 720), anime: 'anime1');

      final uploaded = <String>[];
      final svc = GoogleDriveFrameService(
        client: drive(uploadedFrameIds: uploaded),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
      );
      final summary = await svc.syncTripLocalFrames(db, tripId: stop.tripId);

      expect(uploaded.toSet(), {'mineB', 'mineC', 'mineD', 'mineE'});
      expect(summary.uploaded, 4);
      expect(summary.linkedOnline, 2);

      final a = await frame('mineA');
      expect(a.remoteUrl, 'https://image.anitabi.cn/points/1/libA.jpg?plan=h360');
      expect(a.source, '甜食伯爵', reason: "Anitabi's attribution comes along");
      expect(a.sourceUrl, 'https://anitabi.cn/map?bangumiId=1&pid=libA');
      expect(a.localPath, isNotNull, reason: "the user's own copy stays on the phone");

      final a2 = await frame('mineA2');
      expect(a2.remoteUrl, a.remoteUrl);
      expect(a2.source, 'My notes', reason: "a frame's own source is kept");

      expect((await frame('libA')).remoteUrl, 'https://image.anitabi.cn/points/1/libA.jpg?plan=h360');
      expect((await tripRepo.getStop(stop.id))!.syncStatus, 1);
      expect(await svc.countTripLocalFrames(db, stop.tripId), 0);
      expect(driveSyncSummaryText(summary), contains('2 frames are already on Anitabi'));
    });

    test('a frame with no cached Anitabi image nearby is uploaded without being hashed', () async {
      final stop = await tripWithStop();
      await addStopFrame(stop, 'solo', patternJpeg(7, 320, 180));
      var hashed = 0;
      final uploaded = <String>[];
      final svc = GoogleDriveFrameService(
        client: drive(uploadedFrameIds: uploaded),
        getToken: ({bool interactive = true}) async => 'tok',
        compress: (b) async => b,
        hashFrames: (images) {
          hashed += images.length;
          return FrameHash.computeAll(images);
        },
      );
      final summary = await svc.syncTripLocalFrames(db, tripId: stop.tripId);
      expect(summary.uploaded, 1);
      expect(hashed, 0);
    });
  });
}
