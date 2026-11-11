import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';
import '../models/stop_group.dart';
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

  /// Its place in its day's order, from 0.
  final int? position;

  const TripStopEntry({
    required this.stop,
    this.dayIndex,
    this.onBackupDay = false,
    this.startMinutes,
    this.position,
  });

  bool get isPlanned => dayIndex != null;
}

/// How the stop list is ordered.
enum StopOrder {
  /// Planned stops by day and time, then the rest by name: the order
  /// [buildStopEntries] gives.
  plan('Plan order'),
  name('Name'),

  /// The most recently added first.
  added('Recently added');

  final String label;

  const StopOrder(this.label);
}

/// [entries], which come in plan order, put in [order].
List<TripStopEntry> orderStopEntries(List<TripStopEntry> entries, StopOrder order) => switch (order) {
      StopOrder.plan => entries,
      // A group's stops sort by the group's name, so the group takes its place
  // by its name.
  StopOrder.name => [...entries]..sort((a, b) {
          final byGroup = (stopGroup(a.stop) ?? a.stop.name).toLowerCase().compareTo((stopGroup(b.stop) ?? b.stop.name).toLowerCase());
          if (byGroup != 0) return byGroup;
          final byName = a.stop.name.toLowerCase().compareTo(b.stop.name.toLowerCase());
          return byName != 0 ? byName : a.stop.id.compareTo(b.stop.id);
        }),
      StopOrder.added => [...entries]..sort((a, b) {
          final byTime = b.stop.createdAt.compareTo(a.stop.createdAt);
          return byTime != 0 ? byTime : a.stop.name.toLowerCase().compareTo(b.stop.name.toLowerCase());
        }),
    };

/// The stop of [picked] that a merge keeps unless the user picks another:
/// the first in the plan, by day and then place in the day, or else the
/// first added.
TripStopEntry stopToKeep(List<TripStopEntry> picked) {
  final planned = picked.where((e) => e.isPlanned).toList()
    ..sort((a, b) {
      final byDay = a.dayIndex!.compareTo(b.dayIndex!);
      return byDay != 0 ? byDay : a.position!.compareTo(b.position!);
    });
  if (planned.isNotEmpty) return planned.first;
  return ([...picked]..sort((a, b) => a.stop.createdAt.compareTo(b.stop.createdAt))).first;
}

/// A row of the stop list: one stop, or a group with its stops.
class StopListRow {
  /// The group's name, for a group's row.
  final String? group;

  /// The row's stop, or the group's stops in list order; never empty.
  final List<TripStopEntry> entries;

  const StopListRow({this.group, required this.entries});

  bool get isGroup => group != null;
}

/// [ordered] as the list's rows: a group's stops make one row, which comes
/// where its first stop does.
List<StopListRow> stopListRows(List<TripStopEntry> ordered) {
  final rows = <StopListRow>[];
  final groups = <String, List<TripStopEntry>>{};
  for (final e in ordered) {
    final group = stopGroup(e.stop);
    if (group == null) {
      rows.add(StopListRow(entries: [e]));
    } else if (groups[group] case final members?) {
      members.add(e);
    } else {
      final members = groups[group] = [e];
      rows.add(StopListRow(group: group, entries: members));
    }
  }
  return rows;
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
  final positionOf = <String, int>{};
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
    for (final (position, t) in ScheduleLogicEngine.computeScheduleTimes(dayItems.toList()).indexed) {
      if (t.item.status == 'skipped' || dayOf.containsKey(t.item.stopId)) continue;
      dayOf[t.item.stopId] = i;
      startOf[t.item.stopId] = t.startMinutes;
      positionOf[t.item.stopId] = position;
    }
  }

  final entries = [
    for (final s in stops)
      TripStopEntry(
        stop: s,
        dayIndex: dayOf[s.id],
        onBackupDay: (dayOf[s.id] ?? -1) >= dayCount,
        startMinutes: startOf[s.id],
        position: positionOf[s.id],
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
