import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../trip/models/stop_group.dart';

/// A stop on a day, with the times worked out from the order, stays and
/// transits.
class PlannerItem {
  final ScheduleItem item;
  final Stop stop;
  final int startMinutes;
  final int endMinutes;

  /// Whether the time was entered by hand rather than worked out.
  final bool fixed;

  /// Whether a fixed time comes before the previous stop ends.
  final bool conflict;

  const PlannerItem({
    required this.item,
    required this.stop,
    required this.startMinutes,
    required this.endMinutes,
    required this.fixed,
    required this.conflict,
  });

  bool get done => item.status == 'done';

  /// The group its stop is in, or null.
  String? get group => stopGroup(stop);
}

/// A slot of a day: a group's stops that follow each other on the day, shown
/// as one, or a single stop. A stop whose group has no other stop next to it
/// is a single stop here.
class PlannerBlock {
  /// In the day's order; never empty.
  final List<PlannerItem> items;

  /// The group's name, for a block of two or more of a group's stops.
  final String? group;

  const PlannerBlock({required this.items, this.group});

  bool get isGroup => group != null;
  PlannerItem get first => items.first;
  int get startMinutes => items.first.startMinutes;
  int get endMinutes => items.last.endMinutes;
  int get visited => items.where((it) => it.done).length;
}

/// [items], in order, made into blocks: consecutive stops of one group form
/// one block.
List<PlannerBlock> planBlocks(List<PlannerItem> items) {
  final runs = <List<PlannerItem>>[];
  for (final it in items) {
    final group = it.group;
    if (group != null && runs.isNotEmpty && runs.last.last.group == group) {
      runs.last.add(it);
    } else {
      runs.add([it]);
    }
  }
  return [for (final run in runs) PlannerBlock(items: run, group: run.length > 1 ? run.first.group : null)];
}

/// An entry of the backlog: a group's stops that are on no day, shown as one,
/// or a single stop.
class BacklogEntry {
  /// Never empty.
  final List<Stop> stops;

  /// The group's name, when two or more of its stops are in the backlog.
  final String? group;

  const BacklogEntry({required this.stops, this.group});

  bool get isGroup => group != null;
  String get name => group ?? stops.single.name;
}

/// One day block: its date (by position, or pinned), and its stops in order.
class PlannerDay {
  final TripDay day;

  /// Position among all of the trip's days, backup days included.
  final int index;
  final bool isBackup;
  final DateTime? date;

  /// A stored pin that comes too early; the day then follows the one before.
  final bool pinConflict;

  /// Dates left free between the dated day before this one and this one,
  /// which a pin can leave.
  final int freeDaysBefore;
  final List<PlannerItem> items;

  const PlannerDay({
    required this.day,
    required this.index,
    required this.isBackup,
    required this.date,
    required this.pinConflict,
    required this.freeDaysBefore,
    required this.items,
  });

  bool get isPinned => day.pinnedDate != null;

  /// [items] as the day shows them, with a group's consecutive stops as one
  /// block. [items] stays flat for everything that counts or maps stops.
  List<PlannerBlock> get blocks => planBlocks(items);
}

/// The dates a pin on a day may take. [min] or [max] is null when there is
/// no limit on that side.
class PinRange {
  final DateTime? min;
  final DateTime? max;

  /// The next pinned day, which sets [max].
  final PlannerDay? nextPinned;

  const PinRange({this.min, this.max, this.nextPinned});

  bool get isEmpty => min != null && max != null && max!.isBefore(min!);

  bool allows(DateTime date) {
    final d = normalizeDateOnly(date);
    return (min == null || !d.isBefore(min!)) && (max == null || !d.isAfter(max!));
  }
}

/// Everything the day planner shows for one trip.
class PlannerView {
  final Trip trip;

  /// Dated days first, then backup days.
  final List<PlannerDay> days;

  /// The trip's stops that are not on any day.
  final List<Stop> backlog;

  const PlannerView({required this.trip, required this.days, required this.backlog});

  /// [backlog] as the backlog shows it: a group's stops in it as one entry,
  /// placed by the group's name among the stops' names.
  List<BacklogEntry> get backlogEntries {
    final byGroup = <String, List<Stop>>{};
    for (final s in backlog) {
      final group = stopGroup(s);
      if (group != null) byGroup.putIfAbsent(group, () => []).add(s);
    }
    final entries = <BacklogEntry>[
      for (final s in backlog)
        if ((byGroup[stopGroup(s)]?.length ?? 0) < 2) BacklogEntry(stops: [s]),
      for (final MapEntry(:key, :value) in byGroup.entries)
        if (value.length > 1) BacklogEntry(stops: value, group: key),
    ];
    // The backlog comes sorted by name; a group takes its place by its name.
    return entries..sort((a, b) => a.name.compareTo(b.name));
  }

  List<PlannerDay> get datedDays => days.where((d) => !d.isBackup).toList();
  List<PlannerDay> get backupDays => days.where((d) => d.isBackup).toList();

  PlannerDay? dayById(String id) => days.where((d) => d.day.id == id).firstOrNull;

  /// The date a new day would get when added after the last dated day.
  DateTime? get nextDayDate {
    final dated = datedDays;
    if (dated.isNotEmpty && dated.last.date != null) return dated.last.date!.add(const Duration(days: 1));
    final start = trip.startDate == null ? null : DateTime.tryParse(trip.startDate!);
    return start == null ? null : normalizeDateOnly(start);
  }

  /// The dates [day] may be pinned to: after the day before it, and early
  /// enough that every day up to the next pinned one still gets a date of
  /// its own.
  PinRange pinRangeFor(PlannerDay day) {
    final dated = datedDays;
    final i = dated.indexOf(day);
    if (i < 0) return const PinRange();
    final start = trip.startDate == null ? null : DateTime.tryParse(trip.startDate!);
    final DateTime? min = i == 0
        ? (start == null ? null : normalizeDateOnly(start))
        : dated[i - 1].date?.add(const Duration(days: 1));
    for (var j = i + 1; j < dated.length; j++) {
      final pin = dated[j].day.pinnedDate;
      if (pin != null) {
        final next = normalizeDateOnly(DateTime.parse(pin));
        return PinRange(min: min, max: next.subtract(Duration(days: j - i)), nextPinned: dated[j]);
      }
    }
    return PinRange(min: min);
  }
}

/// Builds the planner's view of a trip from its rows. Skipped schedule items
/// count as not planned, the same as the backlog rule in `docs/data-model.md`.
PlannerView buildPlannerView({
  required Trip trip,
  required List<TripDay> days,
  required List<Stop> stops,
  required List<ScheduleItem> items,
}) {
  final ordered = [...days]
    ..sort((a, b) {
      final c = a.sortKey.compareTo(b.sortKey);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final resolved = ScheduleLogicEngine.computeBlockDates(
    blocks: [
      for (final d in ordered)
        DayBlockInfo(
          id: d.id,
          sortKey: d.sortKey,
          title: d.title,
          pinnedDate: d.pinnedDate == null ? null : DateTime.tryParse(d.pinnedDate!),
        ),
    ],
    startDate: trip.startDate == null ? null : DateTime.tryParse(trip.startDate!),
    dayCount: trip.dayCount,
  );

  final stopsById = {for (final s in stops) s.id: s};
  final planned = <String>{};
  final plannerDays = <PlannerDay>[];
  DateTime? previousDate;
  for (var i = 0; i < ordered.length; i++) {
    final day = ordered[i];
    final date = resolved[i].isBackup ? null : resolved[i].date;
    final freeDays = date != null && previousDate != null ? date.difference(previousDate).inDays - 1 : 0;
    if (date != null) previousDate = date;
    final dayItems = items
        .where((it) => it.dayId == day.id && it.status != 'skipped' && stopsById.containsKey(it.stopId))
        .toList();
    final byId = {for (final it in dayItems) it.id: it};
    final timeline = ScheduleLogicEngine.computeScheduleTimes([
      for (final it in dayItems)
        ScheduleItemInfo(
          id: it.id,
          stopId: it.stopId,
          dayId: it.dayId,
          sortKey: it.sortKey,
          stayMinutes: it.stayMinutes,
          transitMinutes: it.transitMinutes,
          fixedTimeMinutes: it.fixedTime,
          status: it.status,
        ),
    ]);
    plannerDays.add(PlannerDay(
      day: day,
      index: i,
      isBackup: resolved[i].isBackup,
      date: resolved[i].date,
      pinConflict: resolved[i].hasConflict,
      freeDaysBefore: freeDays > 0 ? freeDays : 0,
      items: [
        for (final t in timeline)
          PlannerItem(
            item: byId[t.item.id]!,
            stop: stopsById[t.item.stopId]!,
            startMinutes: t.startMinutes,
            endMinutes: t.endMinutes,
            fixed: t.item.fixedTimeMinutes != null,
            conflict: t.hasConflict,
          ),
      ],
    ));
    planned.addAll(dayItems.map((it) => it.stopId));
  }

  final backlog = stops.where((s) => !planned.contains(s.id)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return PlannerView(trip: trip, days: plannerDays, backlog: backlog);
}
