import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../library/services/photo_trip.dart';
import '../../trip/repositories/trip_repository.dart';
import 'pilgrimage_shooting_service.dart';

/// Where the place of a shot series stands in a trip on the day it was shot,
/// for the pick screen's "Mark done" and "Add to Day N".
///
/// The plan follows the user (roadmap v0.3.0): a shot changes nothing in the
/// plan by itself. A big spot can take many shots over several frames, so
/// marking a stop done is the user's call; a stop planned for another day
/// stays on that day; and a place that isn't on a day joins one only when
/// the user asks.
class ShotPlan {
  final Trip trip;

  /// The trip's stop at the place, if it has one.
  final Stop? stop;

  /// The stop's schedule item: the one on the day of the shot, else the one
  /// on the earliest day. Null when the stop isn't on a day, or there's no
  /// stop.
  final ScheduleItem? item;

  /// The number of the day [item] is on, from 1; null on a backup day.
  final int? itemDay;

  /// The trip's day on the day of the shot, and its number; null when the
  /// trip has no day then.
  final TripDay? shotDay;
  final int? shotDayNumber;

  /// The spot's frames, and how many of them have a photo, counting the
  /// shots about to be kept.
  final int frames;
  final int framesShot;

  const ShotPlan({
    required this.trip,
    this.stop,
    this.item,
    this.itemDay,
    this.shotDay,
    this.shotDayNumber,
    this.frames = 0,
    this.framesShot = 0,
  });

  bool get done => item?.status == 'done';

  /// Every frame of the spot has a photo now, so the stop is likely done.
  /// A spot with one frame then needs no extra tap; a big one with several
  /// isn't done after one.
  bool get allFramesShot => framesShot >= frames;

  /// "Mark done" is offered when the stop is on a day.
  bool get canMarkDone => item != null;

  /// "Add to Day N" is offered when the place isn't on any day of the trip
  /// and the trip has a day on the day of the shot.
  bool get canAddToDay => item == null && shotDay != null;

  /// What the tick starts as: done already, or every frame shot.
  bool get suggestDone => done || allFramesShot;

  /// "2 of 5 frames", or null when the spot has no frames.
  String? get progress => frames == 0 ? null : '$framesShot of $frames ${frames == 1 ? 'frame' : 'frames'}';
}

/// The trip shots of [placeKey] taken at [takenAt] are filed under: [tripId]
/// when given, else the trip that has the place on that day, else the trip
/// on that day ([PilgrimageShootingService.recordShot] files under it too).
Future<Trip?> shotTrip(AppDatabase db, {required String placeKey, required DateTime takenAt, String? tripId}) async {
  final id = tripId ?? await tripForPhoto(db, placeKey, takenAt);
  if (id != null) {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (trip != null) return trip;
  }
  return (await const PilgrimageShootingService().getTodayTrip(db, now: takenAt))?.trip;
}

/// Finds the [ShotPlan] for photos of [placeKey] shot at [takenAt] with the
/// frame [referenceImageId], in the trip [shotTrip] picks. Null when there
/// is no trip.
Future<ShotPlan?> loadShotPlan(
  AppDatabase db, {
  required String placeKey,
  required DateTime takenAt,
  String? tripId,
  String? referenceImageId,
}) async {
  final trip = await shotTrip(db, placeKey: placeKey, takenAt: takenAt, tripId: tripId);
  if (trip == null) return null;

  // The trip's days with their dates and numbers.
  final days =
      await (db.select(db.tripDays)
            ..where((d) => d.tripId.equals(trip.id) & d.deletedAt.isNull())
            ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
          .get();
  final resolved = ScheduleLogicEngine.computeBlockDates(
    blocks: [
      for (final d in days)
        DayBlockInfo(
          id: d.id,
          sortKey: d.sortKey,
          pinnedDate: d.pinnedDate == null ? null : DateTime.tryParse(d.pinnedDate!),
        ),
    ],
    startDate: trip.startDate == null ? null : DateTime.tryParse(trip.startDate!),
    dayCount: trip.dayCount,
  );
  final dayById = {for (final d in days) d.id: d};
  final number = {for (final r in resolved) r.block.id: r.isBackup ? null : r.index + 1};
  final order = {for (final r in resolved) r.block.id: r.index};
  final shotDate = normalizeDateOnly(takenAt);
  final onShotDay = resolved.where((r) => !r.isBackup && (r.date?.isAtSameMomentAs(shotDate) ?? false)).firstOrNull;
  final shotDay = onShotDay == null ? null : dayById[onShotDay.block.id];

  final stop =
      await (db.select(db.stops)
            ..where((s) => s.tripId.equals(trip.id) & s.placeKey.equals(placeKey) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  ScheduleItem? item;
  if (stop != null) {
    final items = await (db.select(
      db.scheduleItems,
    )..where((i) => i.stopId.equals(stop.id) & i.deletedAt.isNull())).get();
    items.sort((a, b) => (order[a.dayId] ?? 1 << 30).compareTo(order[b.dayId] ?? 1 << 30));
    item = items.where((i) => i.dayId == shotDay?.id).firstOrNull ?? items.firstOrNull;
  }

  // The spot's frames: the place's own, and those a shared trip links to the stop.
  final frames =
      await (db.select(db.newReferenceImages)..where(
            (f) => f.placeKey.equals(placeKey) | (stop == null ? const Constant(false) : f.stopId.equals(stop.id)),
          ))
          .get();
  // A stop's frames are copies of its place's (the same picture under a new
  // id), so a frame counts once, whichever copy a photo was shot with.
  final picture = {for (final f in frames) f.id: f.localPath ?? f.remoteUrl ?? f.id};
  final shot = <String>{
    if (referenceImageId != null && picture.containsKey(referenceImageId)) picture[referenceImageId]!,
  };
  if (picture.isNotEmpty) {
    final photos = await (db.select(
      db.photos,
    )..where((p) => p.placeKey.equals(placeKey) & p.referenceImageId.isIn(picture.keys))).get();
    shot.addAll(photos.map((p) => picture[p.referenceImageId]!));
  }

  return ShotPlan(
    trip: trip,
    stop: stop,
    item: item,
    itemDay: item == null ? null : number[item.dayId],
    shotDay: shotDay,
    shotDayNumber: shotDay == null ? null : number[shotDay.id],
    frames: picture.values.toSet().length,
    framesShot: shot.length,
  );
}

/// What [applyShotPlan] changed in the plan.
enum ShotPlanChange { markedDone, unmarked, added, addedDone }

/// Applies the pick screen's ticks to [plan]. Only what the user ticked
/// changes: with [addToDay], the place joins the day of the shot (as a new
/// stop when the trip has none there); [markDone] then sets the stop's item
/// done, or back to planned when it was done. Null when nothing changed.
Future<ShotPlanChange?> applyShotPlan(
  TripRepository trips,
  ShotPlan plan, {
  required String placeKey,
  required String userId,
  required bool markDone,
  bool addToDay = false,
}) async {
  var item = plan.item;
  var added = false;
  if (addToDay && plan.canAddToDay) {
    final stop = plan.stop ?? await trips.addPlaceToTrip(tripId: plan.trip.id, placeKey: placeKey, addedBy: userId);
    item = await trips.scheduleStop(tripId: plan.trip.id, stopId: stop.id, dayId: plan.shotDay!.id);
    added = true;
  }
  if (item == null) return null;
  final wasDone = item.status == 'done';
  if (markDone && !wasDone) {
    await trips.updateScheduleItemStatus(itemId: item.id, status: 'done');
    return added ? ShotPlanChange.addedDone : ShotPlanChange.markedDone;
  }
  if (!markDone && wasDone) {
    await trips.updateScheduleItemStatus(itemId: item.id, status: 'planned');
    return ShotPlanChange.unmarked;
  }
  return added ? ShotPlanChange.added : null;
}
