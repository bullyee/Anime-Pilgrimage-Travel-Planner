import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';

/// What the trip list shows for one trip.
class TripSummary {
  final Trip trip;
  final TripStatus status;

  /// The first and last dated day, or null while the trip has no start date.
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Dated days only; backup days aren't counted.
  final int dayCount;
  final int stopCount;

  const TripSummary({
    required this.trip,
    required this.status,
    required this.firstDate,
    required this.lastDate,
    required this.dayCount,
    required this.stopCount,
  });

  /// Builds a summary from the trip's day blocks. [days] is null while they
  /// are still loading; the dates are then worked out from the start date and
  /// day count alone, which only differs when a day is pinned.
  factory TripSummary.from({
    required Trip trip,
    required List<TripDay>? days,
    required int stopCount,
    required DateTime now,
  }) {
    final infos = days == null
        ? [
            for (var i = 0; i < trip.dayCount; i++)
              DayBlockInfo(id: '$i', sortKey: i.toString().padLeft(6, '0')),
          ]
        : [
            for (final d in days)
              DayBlockInfo(
                id: d.id,
                sortKey: d.sortKey,
                pinnedDate: d.pinnedDate == null ? null : DateTime.tryParse(d.pinnedDate!),
              ),
          ];
    final blocks = ScheduleLogicEngine.computeBlockDates(
      blocks: infos,
      startDate: trip.startDate == null ? null : DateTime.tryParse(trip.startDate!),
      dayCount: trip.dayCount,
    );
    final dated = blocks.where((b) => !b.isBackup && b.date != null).toList();
    return TripSummary(
      trip: trip,
      status: ScheduleLogicEngine.computeTripStatus(resolvedBlocks: blocks, now: now),
      firstDate: dated.isEmpty ? null : dated.first.date,
      lastDate: dated.isEmpty ? null : dated.last.date,
      dayCount: blocks.where((b) => !b.isBackup).length,
      stopCount: stopCount,
    );
  }
}

/// The sections of the trip list, in order. Their headers carry the trip's
/// status, so the cards don't repeat it.
enum TripSection {
  ongoing('Ongoing'),
  comingUp('Coming up'),
  undated('No dates yet'),
  finished('Finished');

  final String title;

  const TripSection(this.title);

  static TripSection of(TripSummary t) => switch (t.status) {
        TripStatus.ongoing => TripSection.ongoing,
        TripStatus.planning => t.firstDate == null ? TripSection.undated : TripSection.comingUp,
        TripStatus.finished => TripSection.finished,
      };
}

/// Which trips the list shows: all, the ones shared with a group, or the
/// private ones.
enum TripFilter {
  all,
  shared,
  private;

  bool matches(Trip trip) => switch (this) {
        TripFilter.all => true,
        TripFilter.shared => trip.sharing == 'group',
        TripFilter.private => trip.sharing != 'group',
      };
}

/// [trips], already in [sortTripSummaries] order, under their sections,
/// leaving out the empty ones.
List<(TripSection, List<TripSummary>)> groupTripSummaries(Iterable<TripSummary> trips) {
  final bySection = <TripSection, List<TripSummary>>{};
  for (final t in trips) {
    bySection.putIfAbsent(TripSection.of(t), () => []).add(t);
  }
  return [
    for (final section in TripSection.values)
      if (bySection[section] case final items?) (section, items),
  ];
}

/// Orders the trip list: trips under way first, then upcoming trips by start
/// date, then trips without dates (newest first), then finished trips with
/// the most recent first.
List<TripSummary> sortTripSummaries(Iterable<TripSummary> trips) {
  int group(TripSummary t) => TripSection.of(t).index;

  return trips.toList()
    ..sort((a, b) {
      final byGroup = group(a).compareTo(group(b));
      if (byGroup != 0) return byGroup;
      final byDate = switch (group(a)) {
        0 || 1 => a.firstDate!.compareTo(b.firstDate!),
        2 => b.trip.createdAt.compareTo(a.trip.createdAt),
        _ => b.lastDate!.compareTo(a.lastDate!),
      };
      return byDate != 0 ? byDate : a.trip.title.compareTo(b.trip.title);
    });
}
