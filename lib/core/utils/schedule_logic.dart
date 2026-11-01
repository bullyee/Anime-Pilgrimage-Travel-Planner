/// Pure business logic for trips, day blocks, scheduling timelines, and backlog.
///
/// Implements the Stage 1a requirements from `docs/data-model.md` and `docs/mvp-plan.md`:
/// - Day block dates calculation with pins, backup blocks, and strictly increasing pin validation.
/// - Schedule timeline time computation (order, stay, transit, fixed times, past-24:00 support e.g. 25:30).
/// - Trip status (planning / ongoing / finished) derived from dated blocks.
/// - Backlog calculation derived from stops without schedule items.
library;

/// Status of a trip derived from its dated blocks and current date.
enum TripStatus {
  /// Start date has not arrived yet, or trip has no dates.
  planning,

  /// Current date falls within the dated blocks.
  ongoing,

  /// Trip's last dated block has passed.
  finished,
}

/// Represents an abstract day block for pure date computation.
class DayBlockInfo {
  final String id;
  final String sortKey;
  final String? title;
  final DateTime? pinnedDate;

  const DayBlockInfo({
    required this.id,
    required this.sortKey,
    this.title,
    this.pinnedDate,
  });

  DayBlockInfo copyWith({
    String? id,
    String? sortKey,
    String? title,
    DateTime? pinnedDate,
  }) {
    return DayBlockInfo(
      id: id ?? this.id,
      sortKey: sortKey ?? this.sortKey,
      title: title ?? this.title,
      pinnedDate: pinnedDate ?? this.pinnedDate,
    );
  }
}

/// Resolved date information for a day block.
class ResolvedBlockDate {
  final DayBlockInfo block;
  final int index;
  final bool isBackup;
  final DateTime? date;
  final bool hasConflict;

  const ResolvedBlockDate({
    required this.block,
    required this.index,
    required this.isBackup,
    this.date,
    this.hasConflict = false,
  });
}

/// Represents an abstract schedule item for pure timeline computation.
class ScheduleItemInfo {
  final String id;
  final String stopId;
  final String dayId;
  final String sortKey;
  final int stayMinutes;
  final int transitMinutes;
  final int? fixedTimeMinutes;
  final String status; // 'planned' | 'done' | 'skipped'

  const ScheduleItemInfo({
    required this.id,
    required this.stopId,
    required this.dayId,
    required this.sortKey,
    this.stayMinutes = 60,
    this.transitMinutes = 0,
    this.fixedTimeMinutes,
    this.status = 'planned',
  });
}

/// A schedule item with calculated start and end minutes.
class ComputedTimelineItem {
  final ScheduleItemInfo item;
  final int startMinutes;
  final int endMinutes;
  final bool hasConflict;

  const ComputedTimelineItem({
    required this.item,
    required this.startMinutes,
    required this.endMinutes,
    required this.hasConflict,
  });

  String get startTimeFormatted => formatTimelineMinutes(startMinutes);
  String get endTimeFormatted => formatTimelineMinutes(endMinutes);
}

/// Formats minutes from midnight into "HH:mm", supporting values beyond 24:00 (e.g. 1530 -> "25:30").
String formatTimelineMinutes(int totalMinutes) {
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

/// Parses "HH:mm" time string into minutes from midnight, supporting values beyond 24:00 (e.g. "25:30" -> 1530).
int parseTimelineTimeString(String timeString) {
  final parts = timeString.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

/// Normalizes a [DateTime] to UTC midnight (stripping time-of-day).
DateTime normalizeDateOnly(DateTime dt) {
  return DateTime.utc(dt.year, dt.month, dt.day);
}

/// Core scheduling engine implementing the pure logic of `docs/data-model.md`.
class ScheduleLogicEngine {
  const ScheduleLogicEngine._();

  /// Validates that all pinned dates in [blocks] strictly increase along their
  /// `sortKey` (and `id` tie-breaker) order, and that no pin falls on or before
  /// the previous block's computed date or before [startDate].
  ///
  /// Throws [ArgumentError] if any pin conflicts.
  static void validatePinnedDates(
    List<DayBlockInfo> blocks, {
    DateTime? startDate,
    int? dayCount,
  }) {
    final sorted = List<DayBlockInfo>.from(blocks)
      ..sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });

    DateTime? lastPin;
    for (final b in sorted) {
      if (b.pinnedDate != null) {
        final currentPin = normalizeDateOnly(b.pinnedDate!);
        if (lastPin != null) {
          if (currentPin.isBefore(lastPin) || currentPin.isAtSameMomentAs(lastPin)) {
            throw ArgumentError(
              'Pinned dates must strictly increase along sort order. '
              'Found ${currentPin.toIso8601String().substring(0, 10)} after '
              '${lastPin.toIso8601String().substring(0, 10)}.',
            );
          }
        }
        lastPin = currentPin;
      }
    }

    final resolved = computeBlockDates(
      blocks: sorted,
      startDate: startDate,
      dayCount: dayCount ?? sorted.length,
    );
    for (final r in resolved) {
      if (r.hasConflict) {
        throw ArgumentError(
          'Pinned date on block ${r.block.id} conflicts with start date or previous block date.',
        );
      }
    }
  }

  /// Computes the dates for day blocks.
  ///
  /// - The blocks are sorted by `sortKey`, then `id`.
  /// - Blocks with index < [dayCount] are dated blocks.
  /// - Blocks with index >= [dayCount] are backup blocks (no date).
  /// - Block 0 starts at [startDate] (or its pinned date). Subsequent blocks
  ///   continue consecutive dates unless a block has a [DayBlockInfo.pinnedDate],
  ///   in which case it and subsequent blocks continue from that pin.
  /// - Never throws on stored data: if a stored pin is before [startDate] or on/before
  ///   the previous block's computed date, `hasConflict` is set to `true` and the
  ///   conflicting pin is ignored in favor of the consecutive date.
  static List<ResolvedBlockDate> computeBlockDates({
    required List<DayBlockInfo> blocks,
    required DateTime? startDate,
    required int dayCount,
  }) {
    final sorted = List<DayBlockInfo>.from(blocks)
      ..sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });

    final results = <ResolvedBlockDate>[];
    DateTime? lastComputedDate;
    DateTime? lastSeenPin;

    for (int i = 0; i < sorted.length; i++) {
      final block = sorted[i];
      final bool isBackup = i >= dayCount;
      final pin = block.pinnedDate != null ? normalizeDateOnly(block.pinnedDate!) : null;

      if (isBackup) {
        bool hasConflict = false;
        final minAllowedAfter = lastComputedDate ?? lastSeenPin;
        if (pin != null && minAllowedAfter != null && !pin.isAfter(minAllowedAfter)) {
          hasConflict = true;
        }
        if (pin != null && !hasConflict) {
          lastSeenPin = pin;
        }
        results.add(ResolvedBlockDate(
          block: block,
          index: i,
          isBackup: true,
          date: null,
          hasConflict: hasConflict,
        ));
        continue;
      }

      DateTime? blockDate;
      bool hasConflict = false;

      if (i == 0) {
        final baseStart = startDate != null ? normalizeDateOnly(startDate) : null;
        if (pin != null) {
          if (baseStart != null && pin.isBefore(baseStart)) {
            // Pin is before trip start date: conflict! Fall back to base start.
            blockDate = baseStart;
            hasConflict = true;
          } else {
            blockDate = pin;
          }
        } else {
          blockDate = baseStart;
        }
      } else {
        final consecutiveDate = lastComputedDate?.add(const Duration(days: 1));
        final minAllowedAfter = lastComputedDate ?? lastSeenPin;

        if (pin != null) {
          if (minAllowedAfter != null && !pin.isAfter(minAllowedAfter)) {
            // Pin is on or before previous block's computed date: reject pin, continue consecutively!
            blockDate = consecutiveDate;
            hasConflict = true;
          } else {
            blockDate = pin;
          }
        } else {
          blockDate = consecutiveDate;
        }
      }

      if (pin != null && !hasConflict) {
        lastSeenPin = pin;
      }
      lastComputedDate = blockDate;

      results.add(ResolvedBlockDate(
        block: block,
        index: i,
        isBackup: false,
        date: blockDate,
        hasConflict: hasConflict,
      ));
    }

    return results;
  }

  /// Computes continuous timeline times for a list of schedule items on a day.
  ///
  /// - [items] are sorted by `sortKey`.
  /// - [defaultDayStartMinutes] defaults to 09:00 (540 min).
  /// - Each item starts at the end of the previous item + previous transit time,
  ///   or at its [fixedTimeMinutes] if provided.
  /// - Supports times beyond 24:00 (1440 min), such as late-night anime pilgrimage spots (e.g. 25:30).
  static List<ComputedTimelineItem> computeScheduleTimes(
    List<ScheduleItemInfo> items, {
    int defaultDayStartMinutes = 540,
  }) {
    if (items.isEmpty) return const [];

    final sorted = List<ScheduleItemInfo>.from(items)
      ..sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });

    final results = <ComputedTimelineItem>[];
    int currentMinute = sorted.first.fixedTimeMinutes ?? defaultDayStartMinutes;

    for (final item in sorted) {
      int itemStart;
      bool hasConflict = false;

      if (item.fixedTimeMinutes != null) {
        itemStart = item.fixedTimeMinutes!;
        if (results.isNotEmpty && itemStart < currentMinute) {
          hasConflict = true;
        }
      } else {
        itemStart = currentMinute;
      }

      final itemEnd = itemStart + item.stayMinutes;
      results.add(ComputedTimelineItem(
        item: item,
        startMinutes: itemStart,
        endMinutes: itemEnd,
        hasConflict: hasConflict,
      ));

      currentMinute = itemEnd + item.transitMinutes;
    }

    return results;
  }

  /// Derives trip status (`planning`, `ongoing`, `finished`) from dated blocks and [now].
  static TripStatus computeTripStatus({
    required List<ResolvedBlockDate> resolvedBlocks,
    required DateTime now,
  }) {
    final datedBlocks = resolvedBlocks
        .where((b) => !b.isBackup && b.date != null)
        .toList();

    if (datedBlocks.isEmpty) {
      return TripStatus.planning;
    }

    final today = normalizeDateOnly(now);
    final firstDate = datedBlocks.first.date!;
    final lastDate = datedBlocks.last.date!;

    if (today.isBefore(firstDate)) {
      return TripStatus.planning;
    } else if (today.isAfter(lastDate)) {
      return TripStatus.finished;
    } else {
      return TripStatus.ongoing;
    }
  }

  /// Derives the backlog (stops belonging to a trip that have no active schedule item).
  static List<String> computeBacklog({
    required List<String> allTripStopIds,
    required List<ScheduleItemInfo> scheduleItems,
  }) {
    final scheduledStopIds = scheduleItems
        .where((item) => item.status != 'skipped')
        .map((item) => item.stopId)
        .toSet();

    return allTripStopIds
        .where((stopId) => !scheduledStopIds.contains(stopId))
        .toList();
  }
}

