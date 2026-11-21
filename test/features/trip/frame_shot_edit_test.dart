import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/utils/app_result.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/trip/controllers/trip_stops_controller.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';

/// Editing a spot on the place page writes every frame of the spot and
/// marks its stop for sync, so the `frameShots` map goes up.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('u1'),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<NewReferenceImage> frame(String id) =>
      (db.select(db.newReferenceImages)..where((f) => f.id.equals(id))).getSingle();
  Future<Stop> stop(String id) => (db.select(db.stops)..where((s) => s.id.equals(id))).getSingle();

  Future<({String tripId, String stopId})> seed({bool shared = true}) async {
    final repo = container.read(tripRepositoryProvider);
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1');
    if (shared) {
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(const TripsCompanion(sharing: Value('group')));
    }
    final s = await repo.createTripOnlySpot(tripId: trip.id, name: '宇治橋', lat: 34.892, lng: 135.808, addedBy: 'u1');
    for (final id in ['f1', 'f2']) {
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(s.id),
            localPath: Value('$id.png'),
            note: const Value('三の間'),
          ));
    }
    // A library frame of the same place, shown on the page but not the trip's.
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'lib',
          placeKey: Value(s.placeKey),
          localPath: const Value('lib.png'),
        ));
    await (db.update(db.stops)..where((x) => x.id.equals(s.id))).write(const StopsCompanion(syncStatus: Value(0)));
    return (tripId: trip.id, stopId: s.id);
  }

  test('setFrameShot moves every frame of the spot and marks the stop for sync', () async {
    final ids = await seed();
    final frames = [await frame('f1'), await frame('f2'), await frame('lib')];
    final result = await container.read(tripStopsControllerProvider.notifier).setFrameShot(frames, lat: 34.8925, lng: 135.8071);

    expect(result, isA<Success<void>>());
    for (final id in ['f1', 'f2']) {
      final f = await frame(id);
      expect((f.lat, f.lng, f.note), (34.8925, 135.8071, '三の間'), reason: 'the note stays');
    }
    final lib = await frame('lib');
    expect((lib.lat, lib.lng), (null, null), reason: "the library's frame stays the library's");
    expect((await stop(ids.stopId)).syncStatus, 1, reason: 'the stop goes up with its frameShots');

    final log = await db.select(db.tripActivities).get();
    expect(log.map((a) => a.summary), contains('moved a spot of 宇治橋'));
  });

  test('setFrameNote names the spot, and an empty note takes it off', () async {
    final ids = await seed(shared: false);
    final controller = container.read(tripStopsControllerProvider.notifier);
    final frames = [await frame('f1'), await frame('f2')];

    await controller.setFrameNote(frames, '  東詰 ');
    expect([(await frame('f1')).note, (await frame('f2')).note], ['東詰', '東詰']);
    expect((await stop(ids.stopId)).syncStatus, 1);

    await controller.setFrameNote(frames, ' ');
    expect((await frame('f1')).note, isNull);

    final tooLong = await controller.setFrameNote(frames, 'x' * (maxFrameNoteLength + 1));
    expect(tooLong, isA<Failure<void>>());
    expect((await frame('f1')).note, isNull);
  });
}
