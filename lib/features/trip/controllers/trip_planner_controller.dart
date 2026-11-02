import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../../../core/utils/schedule_logic.dart';
import '../repositories/trip_repository.dart';
import '../providers/trip_providers.dart';

class TripPlannerState {
  final Trip? trip;
  final List<ResolvedBlockDate> days;
  final List<Stop> stops;
  final List<ComputedTimelineItem> scheduledTimeline;
  final List<ScheduleItem> rawScheduleItems;
  final List<Stop> backlogStops;
  final TripStatus tripStatus;
  final bool isLoading;
  final String? errorMessage;

  const TripPlannerState({
    this.trip,
    this.days = const [],
    this.stops = const [],
    this.scheduledTimeline = const [],
    this.rawScheduleItems = const [],
    this.backlogStops = const [],
    this.tripStatus = TripStatus.planning,
    this.isLoading = false,
    this.errorMessage,
  });

  TripPlannerState copyWith({
    Trip? trip,
    List<ResolvedBlockDate>? days,
    List<Stop>? stops,
    List<ComputedTimelineItem>? scheduledTimeline,
    List<ScheduleItem>? rawScheduleItems,
    List<Stop>? backlogStops,
    TripStatus? tripStatus,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TripPlannerState(
      trip: trip ?? this.trip,
      days: days ?? this.days,
      stops: stops ?? this.stops,
      scheduledTimeline: scheduledTimeline ?? this.scheduledTimeline,
      rawScheduleItems: rawScheduleItems ?? this.rawScheduleItems,
      backlogStops: backlogStops ?? this.backlogStops,
      tripStatus: tripStatus ?? this.tripStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TripPlannerController extends StateNotifier<TripPlannerState> {
  final TripRepository _repository;
  final String tripId;

  TripPlannerController({
    required TripRepository repository,
    required this.tripId,
  })  : _repository = repository,
        super(const TripPlannerState(isLoading: true)) {
    load();
  }

  /// Load and compute the full trip plan.
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final trip = await _repository.getTrip(tripId);
      if (!mounted) return;
      if (trip == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Trip not found');
        return;
      }

      final days = await _repository.getDaysForTrip(tripId);
      final stops = await _repository.getStopsForTrip(tripId);
      final scheduleItems = await _repository.getScheduleItemsForTrip(tripId);
      if (!mounted) return;

      _computeAndEmitState(trip: trip, days: days, stops: stops, items: scheduleItems);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _computeAndEmitState({
    required Trip trip,
    required List<TripDay> days,
    required List<Stop> stops,
    required List<ScheduleItem> items,
  }) {
    // 1. Compute Day Block dates with position and pins
    final blockInfos = days.map((d) {
      return DayBlockInfo(
        id: d.id,
        sortKey: d.sortKey,
        title: d.title,
        pinnedDate: d.pinnedDate != null ? DateTime.tryParse(d.pinnedDate!) : null,
      );
    }).toList();

    final startDate = trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;

    final resolvedBlocks = ScheduleLogicEngine.computeBlockDates(
      blocks: blockInfos,
      startDate: startDate,
      dayCount: trip.dayCount,
    );

    // 2. Compute timeline schedules per day (so each day starts fresh at defaultDayStartMinutes)
    final itemInfos = items.map((i) {
      return ScheduleItemInfo(
        id: i.id,
        stopId: i.stopId,
        dayId: i.dayId,
        sortKey: i.sortKey,
        stayMinutes: i.stayMinutes,
        transitMinutes: i.transitMinutes,
        fixedTimeMinutes: i.fixedTime,
        status: i.status,
      );
    }).toList();

    final itemsByDay = <String, List<ScheduleItemInfo>>{};
    for (final info in itemInfos) {
      itemsByDay.putIfAbsent(info.dayId, () => []).add(info);
    }

    final timelineItems = <ComputedTimelineItem>[];
    final orderedDayIds = [
      for (final b in resolvedBlocks) b.block.id,
      for (final dayId in itemsByDay.keys)
        if (!resolvedBlocks.any((b) => b.block.id == dayId)) dayId,
    ];
    for (final dayId in orderedDayIds) {
      final dayItems = itemsByDay[dayId];
      if (dayItems != null && dayItems.isNotEmpty) {
        timelineItems.addAll(ScheduleLogicEngine.computeScheduleTimes(dayItems));
      }
    }

    // 3. Derive Backlog stops (stops belonging to this trip that have no active schedule item)
    final backlogStopIds = ScheduleLogicEngine.computeBacklog(
      allTripStopIds: stops.map((s) => s.id).toList(),
      scheduleItems: itemInfos,
    ).toSet();

    final backlogStops = stops.where((s) => backlogStopIds.contains(s.id)).toList();

    // 4. Derive Trip Status
    final status = ScheduleLogicEngine.computeTripStatus(
      resolvedBlocks: resolvedBlocks,
      now: DateTime.now(),
    );

    state = TripPlannerState(
      trip: trip,
      days: resolvedBlocks,
      stops: stops,
      scheduledTimeline: timelineItems,
      rawScheduleItems: items,
      backlogStops: backlogStops,
      tripStatus: status,
      isLoading: false,
    );
  }

  /// Swap two day blocks by index.
  Future<void> swapDayBlocks(int indexA, int indexB) async {
    final days = await _repository.getDaysForTrip(tripId);
    if (indexA < 0 || indexA >= days.length || indexB < 0 || indexB >= days.length) return;

    final dayA = days[indexA];
    final dayB = days[indexB];

    await _repository.swapDayBlocks(dayA.id, dayB.id);
    await load();
  }

  /// Pin a date on a day block, enforcing strictly increasing rule.
  Future<void> pinDate(String dayId, String? date) async {
    try {
      await _repository.pinDayBlockDate(dayId, date);
      await load();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      rethrow;
    }
  }

  /// Schedule a backlog stop into a day block.
  Future<void> scheduleStop(
    String stopId,
    String dayId, {
    int stayMinutes = 60,
    int transitMinutes = 0,
    int? fixedTime,
  }) async {
    final dayItems = await _repository.getScheduleItemsForDay(dayId);
    dayItems.sort((a, b) {
      final cmp = a.sortKey.compareTo(b.sortKey);
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });

    final lastKey = dayItems.isEmpty ? null : dayItems.last.sortKey;
    final newSortKey = FractionalIndexUtil.append(lastKey == null ? [] : [lastKey]);

    await _repository.scheduleStop(
      tripId: tripId,
      stopId: stopId,
      dayId: dayId,
      sortKey: newSortKey,
      stayMinutes: stayMinutes,
      transitMinutes: transitMinutes,
      fixedTime: fixedTime,
    );

    await load();
  }

  /// Remove a schedule item, which returns the stop to the backlog.
  Future<void> removeScheduleItem(String itemId) async {
    await _repository.deleteScheduleItem(itemId);
    await load();
  }

  /// Reorder schedule item or move it to another day.
  Future<void> reorderScheduleItem({
    required String itemId,
    required String newSortKey,
    String? targetDayId,
  }) async {
    await _repository.reorderScheduleItem(
      itemId: itemId,
      newSortKey: newSortKey,
      targetDayId: targetDayId,
    );
    await load();
  }

  /// Update schedule item status (e.g. 'done', 'skipped', 'planned').
  Future<void> updateScheduleItemStatus({
    required String itemId,
    required String status,
  }) async {
    await _repository.updateScheduleItemStatus(
      itemId: itemId,
      status: status,
    );
    await load();
  }

  /// Create, rename, or dissolve (when [area] is null) an area across [stopIds].
  Future<void> setStopsArea(List<String> stopIds, String? area) async {
    await _repository.setStopsArea(stopIds, area);
    await load();
  }

  /// Schedule several stops at once into [dayId] in a single transaction.
  Future<List<ScheduleItem>> scheduleStops({
    required String dayId,
    required List<String> stopIds,
    List<String>? sortKeys,
    int stayMinutes = 60,
    int transitMinutes = 0,
  }) async {
    final items = await _repository.scheduleStops(
      tripId: tripId,
      dayId: dayId,
      stopIds: stopIds,
      sortKeys: sortKeys,
      stayMinutes: stayMinutes,
      transitMinutes: transitMinutes,
    );
    await load();
    return items;
  }

  /// Move several schedule items to a day with new sort keys in a single transaction.
  Future<void> moveScheduleItems({
    required List<String> itemIds,
    required List<String> newSortKeys,
    String? dayId,
    String? targetDayId,
  }) async {
    await _repository.moveScheduleItems(
      itemIds: itemIds,
      newSortKeys: newSortKeys,
      dayId: dayId,
      targetDayId: targetDayId,
    );
    await load();
  }
}

/// Provider family for TripPlannerController keyed by tripId.
/// Automatically refreshes when underlying trip, days, stops, or schedule items change.
final tripPlannerControllerProvider =
    StateNotifierProvider.autoDispose.family<TripPlannerController, TripPlannerState, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  final controller = TripPlannerController(repository: repo, tripId: tripId);

  ref.listen(tripDetailProvider(tripId), (_, _) => controller.load());
  ref.listen(tripDaysProvider(tripId), (_, _) => controller.load());
  ref.listen(tripStopsProvider(tripId), (_, _) => controller.load());
  ref.listen(scheduleItemsForTripProvider(tripId), (_, _) => controller.load());

  return controller;
});
