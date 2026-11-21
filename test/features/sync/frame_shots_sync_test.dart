import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/sync/services/sync_engine_service_v2.dart';

import 'sync_engine_v2_test.dart' show FakeFirestoreSyncV2Service;

/// Where frames are shot from rides on the stop doc as `frameShots`, a map of
/// its own that an older version's upload leaves alone, and a stop merged on
/// one phone carries `mergedInto` so the others move their own frames over.
void main() {
  late AppDatabase db;
  late FakeFirestoreSyncV2Service cloud;
  late SyncEngineServiceV2 engine;
  final t0 = DateTime(2026, 11, 20, 10);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cloud = FakeFirestoreSyncV2Service();
    engine = SyncEngineServiceV2(localDb: db, firestoreSync: cloud, currentUserId: 'alice');
  });
  tearDown(() async {
    engine.stopSync();
    await db.close();
  });

  Future<void> waitFor(Future<bool> Function() done) async {
    for (var i = 0; i < 40; i++) {
      if (await done()) return;
      await Future.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<NewReferenceImage> frame(String id) =>
      (db.select(db.newReferenceImages)..where((r) => r.id.equals(id))).getSingle();

  /// A shared trip this phone already has, synced, with the cloud's copy.
  Future<void> sharedTrip() async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 'trip',
          title: 'Uji',
          ownerId: 'bob',
          sharing: const Value('group'),
          updatedAt: Value(t0),
          syncStatus: const Value(0),
        ));
    engine.startSync();
    cloud.emitUserTrips([
      {'id': 'trip', 'title': 'Uji', 'ownerId': 'bob', 'sharing': 'group', 'updatedAt': t0, 'members': ['bob', 'alice']},
    ]);
    await Future.delayed(const Duration(milliseconds: 60));
  }

  Future<void> localStop(String id, String name, {String? area, double lat = 34.892, double lng = 135.8075}) =>
      db.into(db.stops).insert(StopsCompanion.insert(
            id: id,
            tripId: 'trip',
            placeKey: 'p-$id',
            name: name,
            lat: lat,
            lng: lng,
            area: Value(area),
            addedBy: 'bob',
            updatedAt: Value(t0),
            syncStatus: const Value(0),
          ));

  Map<String, dynamic> remoteStop(String id, String name, {required DateTime at, Map<String, dynamic> extra = const {}}) => {
        'id': id,
        'tripId': 'trip',
        'placeKey': 'p-$id',
        'name': name,
        'lat': 34.892,
        'lng': 135.8075,
        'addedBy': 'bob',
        'updatedAt': at,
        ...extra,
      };

  test('frameShotsOf: only frames that say something, nulls left out', () {
    NewReferenceImage f(String id, {double? lat, double? lng, String? note, double? heading}) =>
        NewReferenceImage(id: id, lat: lat, lng: lng, note: note, heading: heading, createdAt: t0);
    final shots = frameShotsOf([
      f('a', lat: 1, lng: 2, note: '三の間'),
      f('b'),
      f('c', note: '  '),
      f('d', heading: 90),
    ]);
    expect(shots, {
      'a': {'lat': 1.0, 'lng': 2.0, 'note': '三の間'},
      'd': {'heading': 90.0},
    });
  });

  test('a stop uploads where its frames are shot from, local-only frames too', () async {
    await sharedTrip();
    await localStop('s1', 'Uji Bridge');
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f-url',
          stopId: const Value('s1'),
          remoteUrl: const Value('https://example.com/1.jpg'),
          lat: const Value(34.8921),
          lng: const Value(135.8075),
          note: const Value('三の間'),
        ));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f-local',
          stopId: const Value('s1'),
          localPath: const Value('frames/2.png'),
          note: const Value('東詰'),
        ));
    await (db.update(db.stops)..where((s) => s.id.equals('s1')))
        .write(StopsCompanion(syncStatus: const Value(1), updatedAt: Value(t0.add(const Duration(minutes: 1)))));

    await waitFor(() async => cloud.tripStops['trip']?['s1'] != null);
    final doc = cloud.tripStops['trip']!['s1']!;
    expect(doc['frameShots'], {
      'f-local': {'note': '東詰'},
      'f-url': {'lat': 34.8921, 'lng': 135.8075, 'note': '三の間'},
    });
    expect((doc['referenceImages'] as List).single['id'], 'f-url', reason: 'the array stays URL frames only');
  });

  test('frameShots from the cloud land on the frames, by id or by link', () async {
    await sharedTrip();
    await localStop('s1', 'Uji Bridge');
    // This phone has the link frame under its own id, and a local-only frame
    // a frames pack brought with the sender's id.
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'mine',
          stopId: const Value('s1'),
          remoteUrl: const Value('https://example.com/1.jpg'),
        ));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'packed',
          stopId: const Value('s1'),
          localPath: const Value('frames/2.png'),
        ));

    cloud.emitStops('trip', [
      remoteStop('s1', 'Uji Bridge', at: t0.add(const Duration(hours: 1)), extra: {
        'referenceImages': [
          {'id': 'theirs', 'remoteUrl': 'https://example.com/1.jpg'},
        ],
        'frameShots': {
          'theirs': {'lat': 34.8921, 'lng': 135.8075, 'note': '三の間', 'heading': 270},
          'packed': {'note': '東詰'},
          'unknown': {'note': 'nobody has this'},
        },
      }),
    ]);
    await waitFor(() async => (await frame('mine')).note != null);

    final mine = await frame('mine');
    expect(mine.lat, 34.8921);
    expect(mine.note, '三の間');
    expect(mine.heading, 270);
    expect((await frame('packed')).note, '東詰');
    expect(await (db.select(db.newReferenceImages)..where((r) => r.id.equals('unknown'))).get(), isEmpty);
  });

  test('a stop uploaded by an older version, without frameShots, keeps the positions here', () async {
    await sharedTrip();
    await localStop('s1', 'Uji Bridge');
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f1',
          stopId: const Value('s1'),
          remoteUrl: const Value('https://example.com/1.jpg'),
          lat: const Value(34.8921),
          lng: const Value(135.8075),
          note: const Value('三の間'),
        ));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f2',
          stopId: const Value('s1'),
          localPath: const Value('frames/2.png'),
          note: const Value('東詰'),
        ));

    // The teammate on the old version renames the stop: its upload rebuilds
    // the frames array with only the keys it knows.
    cloud.emitStops('trip', [
      remoteStop('s1', 'Uji Bridge (renamed)', at: t0.add(const Duration(hours: 1)), extra: {
        'referenceImages': [
          {'id': 'f1', 'remoteUrl': 'https://example.com/1.jpg', 'episode': '3'},
        ],
      }),
    ]);
    await waitFor(() async => (await (db.select(db.stops)..where((s) => s.id.equals('s1'))).getSingle()).name != 'Uji Bridge');

    final f1 = await frame('f1');
    expect(f1.episode, '3', reason: 'the rest of the frame still syncs');
    expect(f1.note, '三の間');
    expect(f1.lat, 34.8921);
    expect((await frame('f2')).note, '東詰');
  });

  test('a stop merged on another phone takes this phone\'s own frames to the kept stop', () async {
    await sharedTrip();
    await localStop('keep', '宇治橋', area: '宇治橋');
    await localStop('gone', '宇治橋 三の間', area: '宇治橋', lat: 34.8925, lng: 135.8071);
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'only-here',
          stopId: const Value('gone'),
          localPath: const Value('frames/mine.png'),
        ));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'uploaded',
          stopId: const Value('gone'),
          remoteUrl: const Value('https://example.com/u.jpg'),
        ));

    final later = t0.add(const Duration(hours: 1));
    cloud.emitStops('trip', [
      remoteStop('keep', '宇治橋', at: later, extra: {
        'referenceImages': [
          {'id': 'uploaded', 'remoteUrl': 'https://example.com/u.jpg'},
        ],
        'frameShots': {
          'uploaded': {'lat': 34.8925, 'lng': 135.8071, 'note': '三の間'},
        },
      }),
      remoteStop('gone', '宇治橋 三の間', at: later, extra: {'deletedAt': later, 'mergedInto': 'keep', 'area': '宇治橋'}),
    ]);
    await waitFor(() async => (await frame('only-here')).stopId == 'keep');

    final moved = await frame('only-here');
    expect(moved.stopId, 'keep');
    expect(moved.lat, 34.8925, reason: 'where the merged stop was');
    expect(moved.note, '三の間', reason: 'its name without the group\'s');
    final uploaded = await frame('uploaded');
    expect(uploaded.stopId, 'keep', reason: 'the kept stop\'s doc brings it over');
    expect(uploaded.note, '三の間');
    final gone = await (db.select(db.stops)..where((s) => s.id.equals('gone'))).getSingle();
    expect(gone.deletedAt, isNotNull);
    expect(gone.mergedInto, 'keep');
  });
}
