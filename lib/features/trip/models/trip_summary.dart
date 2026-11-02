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

/// Orders the trip list: trips under way first, then upcoming trips by start
/// date, then trips without dates (newest first), then finished trips with
/// the most recent first.
List<TripSummary> sortTripSummaries(Iterable<TripSummary> trips) {
  int group(TripSummary t) => switch (t.status) {
        TripStatus.ongoing => 0,
        TripStatus.planning => t.firstDate == null ? 2 : 1,
        TripStatus.finished => 3,
      };

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
