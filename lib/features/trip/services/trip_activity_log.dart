import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';

/// What a member did, as stored in an activity entry's `action`.
///
/// Adapted from ck's draft in #115. The values are what Firestore stores, so
/// keep them stable.
enum TripActivityAction {
  updateTrip('update_trip'),
  deleteTrip('delete_trip'),
  restoreTrip('restore_trip'),
  addDay('add_day'),
  updateDay('update_day'),
  moveDay('move_day'),
  removeDay('remove_day'),
  restoreDay('restore_day'),
  addStop('add_stop'),
  updateStop('update_stop'),
  groupStops('group_stops'),
  mergeStops('merge_stops'),
  removeStop('remove_stop'),
  restoreStop('restore_stop'),
  scheduleStop('schedule_stop'),
  moveStop('move_stop'),
  unscheduleStop('unschedule_stop'),
  changeTime('change_time'),
  setVisited('set_visited');

  final String value;
  const TripActivityAction(this.value);

  static TripActivityAction? fromValue(String value) {
    for (final a in values) {
      if (a.value == value) return a;
    }
    return null;
  }

  /// Edits that come in quick succession (typing a note, nudging times) and
  /// read better as one entry: the same person's same edit to the same thing
  /// within [TripActivityLog.mergeWindow] replaces the waiting entry.
  bool get mergesRepeats => switch (this) {
        updateTrip || updateDay || updateStop || changeTime || moveDay => true,
        _ => false,
      };
}

/// Records and reads a shared trip's activity log (What changed).
///
/// Entries are written in the same local transaction as the change, with
/// syncStatus 1, and the sync engine pushes them in the same batch as the rows
/// they describe. Private trips have no log.
class TripActivityLog {
  final AppDatabase _db;
  final Uuid _uuid;

  TripActivityLog(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// How long an entry is kept, here and in Firestore (TTL on `expireAt`).
  static const lifetime = Duration(days: 30);

  /// See [TripActivityAction.mergesRepeats].
  static const mergeWindow = Duration(minutes: 10);

  static const _guest = 'guest_local_user';

  /// Adds an entry for [tripId] when the trip is shared and [actorId] is a
  /// signed-in user. [summary] leaves out the actor ("moved Uji Bridge to Day 3");
  /// the screen puts their name in front.
  Future<void> record({
    required String tripId,
    required String actorId,
    required TripActivityAction action,
    required String entityType,
    required String entityId,
    required String summary,
    DateTime? at,
  }) async {
    if (actorId.isEmpty || actorId == _guest) return;
    final trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null || trip.sharing != 'group') return;
    final now = at ?? DateTime.now();

    if (action.mergesRepeats) {
      final waiting = await (_db.select(_db.tripActivities)
            ..where((a) =>
                a.tripId.equals(tripId) &
                a.actorId.equals(actorId) &
                a.action.equals(action.value) &
                a.entityId.equals(entityId) &
                a.syncStatus.equals(1) &
                a.createdAt.isBiggerOrEqualValue(now.subtract(mergeWindow).millisecondsSinceEpoch))
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
            ..limit(1))
          .getSingleOrNull();
      if (waiting != null) {
        await (_db.update(_db.tripActivities)..where((a) => a.id.equals(waiting.id)))
            .write(TripActivitiesCompanion(summary: Value(summary), createdAt: Value(now)));
        return;
      }
    }

    await _db.into(_db.tripActivities).insert(TripActivitiesCompanion.insert(
          id: _uuid.v4(),
          tripId: tripId,
          actorId: actorId,
          action: action.value,
          entityType: entityType,
          entityId: entityId,
          summary: _clip(summary),
          createdAt: now,
          syncStatus: const Value(1),
        ));
  }

  /// "Day 3", "Day 3 (Uji)" or "a backup day", by the day's place among the
  /// trip's days. Pass [days] (the live days, in order) when it's already read.
  Future<String> dayLabel(String tripId, String dayId, {List<TripDay>? days}) async {
    final trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    final ordered = days ??
        await (_db.select(_db.tripDays)
              ..where((d) => d.tripId.equals(tripId) & d.deletedAt.isNull())
              ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
            .get();
    final index = ordered.indexWhere((d) => d.id == dayId);
    final day = index >= 0
        ? ordered[index]
        : await (_db.select(_db.tripDays)..where((d) => d.id.equals(dayId))).getSingleOrNull();
    final title = day?.title?.trim();
    final named = title == null || title.isEmpty ? '' : ' ($title)';
    if (index < 0) return title == null || title.isEmpty ? 'a day' : '"$title"';
    if (index >= (trip?.dayCount ?? ordered.length)) return 'a backup day$named';
    return 'Day ${index + 1}$named';
  }

  /// The stop's name as the trip has it.
  Future<String> stopName(String stopId) async {
    final stop = await (_db.select(_db.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
    return stop?.name ?? 'a stop';
  }

  /// The trip's entries, newest first.
  Stream<List<TripActivity>> watch(String tripId, {int limit = 200}) {
    return (_db.select(_db.tripActivities)
          ..where((a) => a.tripId.equals(tripId))
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)])
          ..limit(limit))
        .watch();
  }

  /// When someone other than [userId] last changed the trip, or null.
  Stream<DateTime?> watchLatestByOthers(String tripId, String userId) {
    final latest = _db.tripActivities.createdAt.max();
    final query = _db.selectOnly(_db.tripActivities)
      ..addColumns([latest])
      ..where(_db.tripActivities.tripId.equals(tripId) & _db.tripActivities.actorId.equals(userId).not());
    return query.watchSingle().map((row) {
      final ms = row.read(latest);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    });
  }

  /// Drops entries past [lifetime] that are already in Firestore (or never
  /// will be); Firestore's TTL does the same there.
  Future<int> expireOld({DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(lifetime).millisecondsSinceEpoch;
    return (_db.delete(_db.tripActivities)..where((a) => a.createdAt.isSmallerThanValue(cutoff))).go();
  }

  static String _clip(String s) => s.length <= 480 ? s : '${s.substring(0, 479)}…';
}

/// "Uji Bridge", "Uji Bridge and Daikichiyama", "Uji Bridge and 2 more".
String stopNames(List<String> names) {
  if (names.isEmpty) return 'no stops';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  return '${names.first} and ${names.length - 1} more';
}
