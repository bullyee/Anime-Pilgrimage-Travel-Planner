import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../services/trip_activity_log.dart';

/// How long deleted things can be restored. Matches the cloud's tombstone TTL
/// and the repository's restore window.
const trashWindow = Duration(days: 30);

/// Something in a trip's trash: a day or a stop deleted in the last 30 days.
class TrashEntry {
  final String kind; // 'day' | 'stop'
  final String id;
  final String tripId;
  final String title;
  final String? detail;
  final DateTime deletedAt;
  final String? deletedBy;

  const TrashEntry({
    required this.kind,
    required this.id,
    required this.tripId,
    required this.title,
    this.detail,
    required this.deletedAt,
    this.deletedBy,
  });

  /// Whole days left before it's gone for good (at least 0).
  int daysLeft(DateTime now) {
    final left = deletedAt.add(trashWindow).difference(now);
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }
}

int _cutoffMs() => DateTime.now().subtract(trashWindow).millisecondsSinceEpoch;

/// Days deleted from a live trip in the last 30 days, newest first. Days that
/// went with the trip itself, and rows hidden because the cloud had already
/// purged them (no deleter), aren't listed.
final deletedDaysProvider = StreamProvider.autoDispose.family<List<TrashEntry>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.tripDays)
    ..where((d) =>
        d.tripId.equals(tripId) &
        d.deletedAt.isNotNull() &
        d.deletedAt.isBiggerOrEqualValue(_cutoffMs()) &
        d.updatedBy.isNotNull())
    ..orderBy([(d) => OrderingTerm.desc(d.deletedAt)]);
  return query.watch().asyncMap((days) async {
    final entries = <TrashEntry>[];
    for (final day in days) {
      final items = await (db.select(db.scheduleItems)
            ..where((i) => i.dayId.equals(day.id) & i.deletedAt.equals(day.deletedAt!.millisecondsSinceEpoch)))
          .get();
      final names = <String>[];
      for (final item in items) {
        final stop = await (db.select(db.stops)..where((s) => s.id.equals(item.stopId))).getSingleOrNull();
        if (stop != null) names.add(stop.name);
      }
      final title = day.title?.trim();
      entries.add(TrashEntry(
        kind: 'day',
        id: day.id,
        tripId: tripId,
        title: title == null || title.isEmpty ? 'A day' : title,
        detail: names.isEmpty ? 'No stops planned' : 'With ${stopNames(names)}',
        deletedAt: day.deletedAt!,
        deletedBy: day.updatedBy,
      ));
    }
    return entries;
  });
});

/// Stops deleted from a live trip in the last 30 days, newest first.
final deletedStopsProvider = StreamProvider.autoDispose.family<List<TrashEntry>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.stops)
    ..where((s) =>
        s.tripId.equals(tripId) &
        s.deletedAt.isNotNull() &
        s.deletedAt.isBiggerOrEqualValue(_cutoffMs()) &
        s.updatedBy.isNotNull())
    ..orderBy([(s) => OrderingTerm.desc(s.deletedAt)]);
  return query.watch().map((stops) => [
        for (final stop in stops)
          TrashEntry(
            kind: 'stop',
            id: stop.id,
            tripId: tripId,
            title: stop.name,
            detail: stop.area,
            deletedAt: stop.deletedAt!,
            deletedBy: stop.updatedBy,
          ),
      ]);
});

/// A trip's trash: its deleted days and stops together, newest first.
final tripTrashProvider = Provider.autoDispose.family<AsyncValue<List<TrashEntry>>, String>((ref, tripId) {
  final days = ref.watch(deletedDaysProvider(tripId));
  final stops = ref.watch(deletedStopsProvider(tripId));
  if (days.hasError) return AsyncValue.error(days.error!, days.stackTrace ?? StackTrace.current);
  if (stops.hasError) return AsyncValue.error(stops.error!, stops.stackTrace ?? StackTrace.current);
  final d = days.valueOrNull;
  final s = stops.valueOrNull;
  if (d == null || s == null) return const AsyncValue.loading();
  return AsyncValue.data([...d, ...s]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt)));
});

/// Trips deleted in the last 30 days that the current user can bring back:
/// their own (private or shared). A member of someone else's trip can't.
final deletedTripsProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  final db = ref.watch(databaseProvider);
  final me = ref.watch(currentUserIdProvider);
  final query = db.select(db.trips)
    ..where((t) =>
        t.deletedAt.isNotNull() &
        t.deletedAt.isBiggerOrEqualValue(_cutoffMs()) &
        (t.ownerId.equals(me) | t.ownerId.equals(guestUserId)))
    ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]);
  return query.watch();
});

/// "you", a member's name, or "someone" for [userId].
final memberNameProvider = Provider.autoDispose.family<String, ({String tripId, String? userId})>((ref, key) {
  final me = ref.watch(currentUserIdProvider);
  if (key.userId == null || key.userId!.isEmpty) return 'Someone';
  if (key.userId == me) return 'You';
  final members = ref.watch(tripMembersProvider(key.tripId)).valueOrNull;
  final name = members?.where((m) => m.userId == key.userId).firstOrNull?.displayName.trim();
  return name == null || name.isEmpty ? 'A former member' : name;
});

/// The trip's activity log (What changed), newest first.
final tripActivityProvider = StreamProvider.autoDispose.family<List<TripActivity>, String>((ref, tripId) {
  return TripActivityLog(ref.watch(databaseProvider)).watch(tripId);
});

/// When the current user last opened the trip's What changed.
final tripViewedAtProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final me = ref.watch(currentUserIdProvider);
  return (db.select(db.tripViews)..where((v) => v.tripId.equals(tripId) & v.userId.equals(me)))
      .watchSingleOrNull()
      .map((row) => row?.viewedAt);
});

/// Whether someone else changed a shared trip since the current user last
/// opened its What changed. Private trips never have a dot.
final tripHasUnreadProvider = Provider.autoDispose.family<bool, String>((ref, tripId) {
  final me = ref.watch(currentUserIdProvider);
  final latest = ref.watch(_latestByOthersProvider((tripId: tripId, userId: me))).valueOrNull;
  if (latest == null) return false;
  final viewed = ref.watch(tripViewedAtProvider(tripId));
  if (viewed.isLoading) return false;
  final at = viewed.valueOrNull;
  return at == null || latest.isAfter(at);
});

final _latestByOthersProvider =
    StreamProvider.autoDispose.family<DateTime?, ({String tripId, String userId})>((ref, key) {
  return TripActivityLog(ref.watch(databaseProvider)).watchLatestByOthers(key.tripId, key.userId);
});

/// Marks the trip's activity as seen now, which clears its dot.
Future<void> markTripActivitySeen(AppDatabase db, String tripId, String userId, {DateTime? at}) {
  return db.into(db.tripViews).insertOnConflictUpdate(
        TripViewsCompanion.insert(tripId: tripId, userId: userId, viewedAt: at ?? DateTime.now()),
      );
}
