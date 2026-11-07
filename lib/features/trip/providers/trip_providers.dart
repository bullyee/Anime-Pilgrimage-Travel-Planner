import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/trip_view_state_service.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/providers/place_providers.dart';
import '../repositories/trip_repository.dart';

/// Provides the [TripRepository] instance backed by Drift.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  final placeRepo = ref.watch(placeRepositoryProvider);
  return DriftTripRepository(db, null, userId, placeRepo);
});

/// Streams all active trips.
final tripsListProvider = StreamProvider.autoDispose<List<Trip>>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchTrips();
});

/// Streams a single trip by [tripId].
final tripDetailProvider = StreamProvider.autoDispose.family<Trip?, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchTrip(tripId);
});

/// Streams all day blocks for a given [tripId].
final tripDaysProvider = StreamProvider.autoDispose.family<List<TripDay>, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchDaysForTrip(tripId);
});

/// Streams all stops added to a given [tripId].
final tripStopsProvider = StreamProvider.autoDispose.family<List<Stop>, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchStopsForTrip(tripId);
});

/// Streams all schedule items for a given [tripId].
final scheduleItemsForTripProvider = StreamProvider.autoDispose.family<List<ScheduleItem>, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchScheduleItemsForTrip(tripId);
});

/// Streams schedule items for a specific [dayId].
final scheduleItemsForDayProvider = StreamProvider.autoDispose.family<List<ScheduleItem>, String>((ref, dayId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchScheduleItemsForDay(dayId);
});

/// Streams labels attached to a specific [stopId].
final stopDetailProvider = StreamProvider.autoDispose.family<Stop?, String>((ref, stopId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchStop(stopId);
});

final stopLabelsProvider = StreamProvider.autoDispose.family<List<Label>, String>((ref, stopId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchLabelsForStop(stopId);
});

/// Streams reference images attached to a specific [stopId].
final stopReferenceImagesProvider = StreamProvider.autoDispose.family<List<NewReferenceImage>, String>((ref, stopId) {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.watchReferenceImagesForStop(stopId);
});

/// Computes resolved calendar dates for all day blocks in a trip.
final tripResolvedBlockDatesProvider = Provider.autoDispose.family<List<ResolvedBlockDate>, String>((ref, tripId) {
  final tripAsync = ref.watch(tripDetailProvider(tripId));
  final daysAsync = ref.watch(tripDaysProvider(tripId));

  final trip = tripAsync.valueOrNull;
  final days = daysAsync.valueOrNull ?? [];

  if (trip == null) return const [];

  final blockInfos = days.map((d) {
    return DayBlockInfo(
      id: d.id,
      sortKey: d.sortKey,
      title: d.title,
      pinnedDate: d.pinnedDate != null ? DateTime.tryParse(d.pinnedDate!) : null,
    );
  }).toList();

  final startDate = trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;

  return ScheduleLogicEngine.computeBlockDates(
    blocks: blockInfos,
    startDate: startDate,
    dayCount: trip.dayCount,
  );
});

/// Computes derived trip status (`planning`, `ongoing`, `finished`).
final tripStatusProvider = Provider.autoDispose.family<TripStatus, String>((ref, tripId) {
  final resolvedBlocks = ref.watch(tripResolvedBlockDatesProvider(tripId));
  return ScheduleLogicEngine.computeTripStatus(
    resolvedBlocks: resolvedBlocks,
    now: DateTime.now(),
  );
});

/// Computes the backlog of unscheduled stops for a trip.
final tripBacklogProvider = Provider.autoDispose.family<List<Stop>, String>((ref, tripId) {
  final stopsAsync = ref.watch(tripStopsProvider(tripId));
  final scheduleItemsAsync = ref.watch(scheduleItemsForTripProvider(tripId));

  final stops = stopsAsync.valueOrNull ?? [];
  final scheduleItems = scheduleItemsAsync.valueOrNull ?? [];

  final itemInfos = scheduleItems.map((item) {
    return ScheduleItemInfo(
      id: item.id,
      stopId: item.stopId,
      dayId: item.dayId,
      sortKey: item.sortKey,
      status: item.status,
    );
  }).toList();

  final backlogStopIds = ScheduleLogicEngine.computeBacklog(
    allTripStopIds: stops.map((s) => s.id).toList(),
    scheduleItems: itemInfos,
  ).toSet();

  return stops.where((s) => backlogStopIds.contains(s.id)).toList();
});

/// Computes continuous timeline items (with arrival/departure and conflict flags) for a day block.
final dayTimelineProvider = Provider.autoDispose.family<List<ComputedTimelineItem>, String>((ref, dayId) {
  final scheduleItemsAsync = ref.watch(scheduleItemsForDayProvider(dayId));
  final items = scheduleItemsAsync.valueOrNull ?? [];

  final itemInfos = items.map((item) {
    return ScheduleItemInfo(
      id: item.id,
      stopId: item.stopId,
      dayId: item.dayId,
      sortKey: item.sortKey,
      stayMinutes: item.stayMinutes,
      transitMinutes: item.transitMinutes,
      fixedTimeMinutes: item.fixedTime,
      status: item.status,
    );
  }).toList();

  return ScheduleLogicEngine.computeScheduleTimes(itemInfos);
});

/// Provides the singleton [TripViewStateService] for tracking in-app view timestamps and unread state.
final tripViewStateServiceProvider = Provider<TripViewStateService>((ref) {
  final service = TripViewStateService();
  ref.onDispose(service.dispose);
  return service;
});

/// Streams the latest update timestamp across this trip and its child entities
/// made by collaborators other than the current user.
final tripLatestCollaboratorUpdateProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return repo.watchLatestCollaboratorUpdate(tripId, currentUserId);
});

/// Streams the last viewed timestamp for [tripId] and current user.
final tripLastViewedAtProvider = StreamProvider.autoDispose.family<DateTime?, String>((ref, tripId) {
  final viewService = ref.watch(tripViewStateServiceProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return viewService.watchLastViewedAt(tripId, userId: currentUserId);
});

/// Provides whether [tripId] has unread updates made by collaborators.
///
/// Returns `false` for private trips or when the current user made the most recent change.
/// Returns `true` when a collaborator's update is newer than the user's `lastViewedAt`
/// (or when the trip has collaborator updates and has not yet been opened).
final hasUnreadTripUpdatesProvider = Provider.autoDispose.family<bool, String>((ref, tripId) {
  final trip = ref.watch(tripDetailProvider(tripId)).valueOrNull;
  if (trip == null || trip.sharing != 'group') {
    return false;
  }

  final latestUpdate = ref.watch(tripLatestCollaboratorUpdateProvider(tripId)).valueOrNull;
  if (latestUpdate == null) {
    return false;
  }

  final lastViewedAsync = ref.watch(tripLastViewedAtProvider(tripId));
  if (lastViewedAsync.isLoading) {
    return false; // Avoid unread flicker while local state file is loading
  }

  final lastViewed = lastViewedAsync.valueOrNull;
  if (lastViewed == null) {
    return true; // Unopened shared trip with collaborator changes
  }

  return latestUpdate.isAfter(lastViewed);
});

