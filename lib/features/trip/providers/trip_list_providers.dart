import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_result.dart';
import '../controllers/trips_controller.dart';
import '../models/trip_summary.dart';
import 'trip_providers.dart';

/// The trip list, sorted for display. Each trip's days and stops are watched
/// too, so dates, pins and stop counts stay current. Trips waiting to be
/// deleted ([pendingTripDeletesProvider]) are left out.
final tripSummariesProvider = Provider.autoDispose<AsyncValue<List<TripSummary>>>((ref) {
  final now = DateTime.now();
  final hidden = ref.watch(pendingTripDeletesProvider);
  return ref.watch(tripsListProvider).whenData((trips) {
    return sortTripSummaries([
      for (final trip in trips)
        if (!hidden.contains(trip.id))
          TripSummary.from(
            trip: trip,
            days: ref.watch(tripDaysProvider(trip.id)).valueOrNull,
            stopCount: ref.watch(tripStopsProvider(trip.id)).valueOrNull?.length ?? 0,
            now: now,
          ),
    ]);
  });
});

/// Trips deleted in the last few seconds, while their Undo is on screen.
/// They're hidden from every list straight away, but only really deleted
/// ([commit]) once the Undo goes away unused. A deleted shared trip turns
/// into a private copy on every other member's phone as soon as it reaches
/// the cloud, which no restore can take back, so it must not get there
/// before Undo is out of reach. If the app closes meanwhile, the trip is
/// simply still there.
final pendingTripDeletesProvider = NotifierProvider<PendingTripDeletes, Set<String>>(PendingTripDeletes.new);

class PendingTripDeletes extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void hide(String tripId) => state = {...state, tripId};

  void undo(String tripId) => state = {...state}..remove(tripId);

  /// Deletes the trip for real. It stays hidden until it's gone, and comes
  /// back if the delete fails.
  Future<AppResult<void>> commit(String tripId) async {
    final result = await ref.read(tripsControllerProvider.notifier).deleteTrip(tripId);
    state = {...state}..remove(tripId);
    return result;
  }
}
