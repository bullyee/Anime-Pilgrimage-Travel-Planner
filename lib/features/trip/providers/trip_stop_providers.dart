import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';
import 'trip_providers.dart';

/// A stop in the trip's stop list, with where it is planned.
class TripStopEntry {
  final Stop stop;

  /// The position of its day among the trip's days, or null when the stop is
  /// not on any day (or was skipped there).
  final int? dayIndex;

  /// Whether that day is a backup day.
  final bool onBackupDay;

  /// When it starts on its day, in minutes from midnight.
  final int? startMinutes;

  const TripStopEntry({
    required this.stop,
    this.dayIndex,
    this.onBackupDay = false,
    this.startMinutes,
  });

  bool get isPlanned => dayIndex != null;
}

/// Orders the stops for the list: planned stops by day and time, then the
/// stops that are not on a day yet, by name.
List<TripStopEntry> buildStopEntries({
  required List<Stop> stops,
  required List<TripDay> days,
  required List<ScheduleItem> items,
  required int dayCount,
}) {
  final ordered = [...days]
    ..sort((a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final dayOf = <String, int>{};
  final startOf = <String, int>{};
  for (var i = 0; i < ordered.length; i++) {
    final dayItems = items.where((it) => it.dayId == ordered[i].id).map((it) => ScheduleItemInfo(
          id: it.id,
          stopId: it.stopId,
          dayId: it.dayId,
          sortKey: it.sortKey,
          stayMinutes: it.stayMinutes,
          transitMinutes: it.transitMinutes,
          fixedTimeMinutes: it.fixedTime,
          status: it.status,
        ));
    for (final t in ScheduleLogicEngine.computeScheduleTimes(dayItems.toList())) {
      if (t.item.status == 'skipped' || dayOf.containsKey(t.item.stopId)) continue;
      dayOf[t.item.stopId] = i;
      startOf[t.item.stopId] = t.startMinutes;
    }
  }

  final entries = [
    for (final s in stops)
      TripStopEntry(
        stop: s,
        dayIndex: dayOf[s.id],
        onBackupDay: (dayOf[s.id] ?? -1) >= dayCount,
        startMinutes: startOf[s.id],
      ),
  ];
  entries.sort((a, b) {
    if (a.isPlanned != b.isPlanned) return a.isPlanned ? -1 : 1;
    if (a.isPlanned) {
      final byDay = a.dayIndex!.compareTo(b.dayIndex!);
      if (byDay != 0) return byDay;
      final byTime = a.startMinutes!.compareTo(b.startMinutes!);
      if (byTime != 0) return byTime;
    }
    return a.stop.name.compareTo(b.stop.name);
  });
  return entries;
}

/// The trip's stops with where each one is planned, for the stop list.
final tripStopEntriesProvider =
    Provider.autoDispose.family<AsyncValue<List<TripStopEntry>>, String>((ref, tripId) {
  final items = ref.watch(scheduleItemsForTripProvider(tripId)).valueOrNull ?? const <ScheduleItem>[];
  final days = ref.watch(tripDaysProvider(tripId)).valueOrNull ?? const <TripDay>[];
  final dayCount = ref.watch(tripDetailProvider(tripId)).valueOrNull?.dayCount ?? days.length;
  return ref.watch(tripStopsProvider(tripId)).whenData(
        (stops) => buildStopEntries(stops: stops, days: days, items: items, dayCount: dayCount),
      );
});
