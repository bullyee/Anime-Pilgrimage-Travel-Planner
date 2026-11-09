import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/camera/services/shot_plan.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftTripRepository trips;
  late Trip kyoto;
  late List<TripDay> days;

  /// Day 2 of the trip, when the shots are taken.
  final day2 = DateTime(2026, 11, 8, 14, 30);

  Future<void> place(String key, {int frames = 0}) async {
    await db.into(db.places).insert(PlacesCompanion.insert(placeKey: key, name: key, lat: 34.89, lng: 135.8));
    for (var i = 1; i <= frames; i++) {
      await db
          .into(db.newReferenceImages)
          .insert(
            NewReferenceImagesCompanion.insert(
              id: '$key-$i',
              placeKey: Value(key),
              localPath: Value('/frames/$key-$i.jpg'),
            ),
          );
    }
  }

  Future<void> photo(String placeKey, String frameId) => db
      .into(db.photos)
      .insert(
        PhotosCompanion.insert(
          id: 'photo-$frameId',
          placeKey: placeKey,
          localPath: '/photos/$frameId.jpg',
          referenceImageId: Value(frameId),
        ),
      );

  /// Adds [placeKey] to the trip, on day [day] (from 1) when given.
  Future<ScheduleItem?> stop(String placeKey, {int? day}) async {
    final stop = await trips.addPlaceToTrip(tripId: kyoto.id, placeKey: placeKey, addedBy: 'me');
    if (day == null) return null;
    return trips.scheduleStop(tripId: kyoto.id, stopId: stop.id, dayId: days[day - 1].id);
  }

  Future<List<ScheduleItem>> items() => db.select(db.scheduleItems).get();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trips = DriftTripRepository(db, null, 'me');
    kyoto = await trips.createTrip(title: 'Kyoto', ownerId: 'me', startDate: '2026-11-07', dayCount: 3);
    days = await trips.getDaysForTrip(kyoto.id);
  });
  tearDown(() => db.close());

  test('a one-frame stop on the day is offered done, already ticked, and marked done only when kept so', () async {
    await place('bench', frames: 1);
    final item = await stop('bench', day: 2);

    final plan = (await loadShotPlan(db, placeKey: 'bench', takenAt: day2, referenceImageIds: ['bench-1']))!;
    expect(plan.trip.id, kyoto.id);
    expect((plan.canMarkDone, plan.canAddToDay), (true, false));
    expect((plan.itemDay, plan.shotDayNumber), (2, 2));
    expect((plan.framesShot, plan.frames), (1, 1));
    expect(plan.progress, '1 of 1 frame');
    expect(plan.suggestDone, isTrue);
    expect((await items()).single.status, 'planned', reason: 'loading changes nothing');

    expect(
      await applyShotPlan(trips, plan, placeKey: 'bench', userId: 'me', markDone: true),
      ShotPlanChange.markedDone,
    );
    expect(
      (await items()).single,
      isA<ScheduleItem>().having((i) => i.id, 'id', item!.id).having((i) => i.status, 'status', 'done'),
    );
  });

  test("a big spot isn't done after one of its frames, and stays planned unless ticked", () async {
    await place('bridge', frames: 3);
    await stop('bridge', day: 2);
    await photo('bridge', 'bridge-1');

    final plan = (await loadShotPlan(db, placeKey: 'bridge', takenAt: day2, referenceImageIds: ['bridge-2']))!;
    expect((plan.framesShot, plan.frames), (2, 3), reason: 'the earlier photo and this series');
    expect(plan.progress, '2 of 3 frames');
    expect(plan.suggestDone, isFalse);

    expect(await applyShotPlan(trips, plan, placeKey: 'bridge', userId: 'me', markDone: false), isNull);
    expect((await items()).single.status, 'planned');
  });

  test('shots switched between frames count each frame they were taken with, once', () async {
    await place('bridge', frames: 3);
    await stop('bridge', day: 2);
    await photo('bridge', 'bridge-1');

    final plan = (await loadShotPlan(db, placeKey: 'bridge', takenAt: day2))!;
    expect(plan.progress, '1 of 3 frames', reason: 'only the saved photo so far');
    expect(plan.withShotFrames(['bridge-2', 'bridge-2', null]).progress, '2 of 3 frames');
    final all = plan.withShotFrames(['bridge-1', 'bridge-2', 'bridge-3', 'not-a-frame']);
    expect((all.framesShot, all.frames), (3, 3));
    expect(all.suggestDone, isTrue);
    expect(plan.withShotFrames(const []).framesShot, 1, reason: 'nothing kept: back to the saved photos');
  });

  test('a stop planned for another day stays on that day, and done marks it there', () async {
    await place('bench', frames: 1);
    await stop('bench', day: 3);

    final plan = (await loadShotPlan(db, placeKey: 'bench', takenAt: day2, referenceImageIds: ['bench-1']))!;
    expect((plan.itemDay, plan.shotDayNumber), (3, 2));
    expect(plan.canMarkDone, isTrue);

    await applyShotPlan(trips, plan, placeKey: 'bench', userId: 'me', markDone: true);
    final all = await items();
    expect(all, hasLength(1), reason: 'nothing is added to the day of the shot');
    expect((all.single.dayId, all.single.status), (days[2].id, 'done'));
  });

  test('a place off the plan joins the day only when the user adds it', () async {
    await place('shrine');

    final plan = (await loadShotPlan(db, placeKey: 'shrine', takenAt: day2))!;
    expect(plan.trip.id, kyoto.id, reason: 'the trip on the day, though it has no stop there');
    expect((plan.stop, plan.canMarkDone, plan.canAddToDay, plan.shotDayNumber), (null, false, true, 2));
    expect(plan.suggestDone, isTrue, reason: 'no frames to shoot');

    expect(await applyShotPlan(trips, plan, placeKey: 'shrine', userId: 'me', markDone: true), isNull);
    expect(await db.select(db.stops).get(), isEmpty);
    expect(await items(), isEmpty);

    expect(
      await applyShotPlan(trips, plan, placeKey: 'shrine', userId: 'me', markDone: false, addToDay: true),
      ShotPlanChange.added,
    );
    final added = (await items()).single;
    expect((added.dayId, added.status), (days[1].id, 'planned'));
    expect((await db.select(db.stops).get()).single.placeKey, 'shrine');
  });

  test("a stop that isn't on a day is added from where it is, done when ticked", () async {
    await place('bench', frames: 1);
    await stop('bench');

    final plan = (await loadShotPlan(db, placeKey: 'bench', takenAt: day2, referenceImageIds: ['bench-1']))!;
    expect((plan.stop?.placeKey, plan.canAddToDay), ('bench', true));

    expect(
      await applyShotPlan(trips, plan, placeKey: 'bench', userId: 'me', markDone: true, addToDay: true),
      ShotPlanChange.addedDone,
    );
    expect(await db.select(db.stops).get(), hasLength(1), reason: 'the stop it had, not a new one');
    final added = (await items()).single;
    expect((added.dayId, added.status), (days[1].id, 'done'));
  });

  test('unticking a stop that was done sets it back to planned', () async {
    await place('bench', frames: 1);
    final item = await stop('bench', day: 2);
    await trips.updateScheduleItemStatus(itemId: item!.id, status: 'done');

    final plan = (await loadShotPlan(db, placeKey: 'bench', takenAt: day2, referenceImageIds: ['bench-1']))!;
    expect((plan.done, plan.suggestDone), (true, true));

    expect(await applyShotPlan(trips, plan, placeKey: 'bench', userId: 'me', markDone: false), ShotPlanChange.unmarked);
    expect((await items()).single.status, 'planned');
  });

  test('a frame copied to the stop counts once, whichever copy was shot with', () async {
    await place('bench', frames: 2);
    await stop('bench', day: 2);
    final copy = (await (db.select(
      db.newReferenceImages,
    )..where((f) => f.stopId.isNotNull())).get()).firstWhere((f) => f.localPath == '/frames/bench-1.jpg');
    await photo('bench', copy.id);

    final plan = (await loadShotPlan(db, placeKey: 'bench', takenAt: day2, referenceImageIds: ['bench-1']))!;
    expect((plan.framesShot, plan.frames), (1, 2));
  });

  test('frames a shared trip links to the stop count as the spot’s', () async {
    await place('bench');
    await stop('bench', day: 2);
    final stopId = (await db.select(db.stops).getSingle()).id;
    await db
        .into(db.newReferenceImages)
        .insert(
          NewReferenceImagesCompanion.insert(
            id: 'shared-1',
            stopId: Value(stopId),
            localPath: const Value('/frames/shared-1.jpg'),
          ),
        );

    final plan = (await loadShotPlan(db, placeKey: 'bench', takenAt: day2, referenceImageIds: ['shared-1']))!;
    expect((plan.framesShot, plan.frames), (1, 1));
  });

  test('no trip on the day: nothing to offer', () async {
    await place('bench', frames: 1);
    await stop('bench', day: 2);

    expect(await loadShotPlan(db, placeKey: 'bench', takenAt: DateTime(2026, 12, 1)), isNull);
  });
}
