import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_summary.dart';
import 'trip_providers.dart';

/// The trip list, sorted for display. Each trip's days and stops are watched
/// too, so dates, pins and stop counts stay current.
final tripSummariesProvider = Provider.autoDispose<AsyncValue<List<TripSummary>>>((ref) {
  final now = DateTime.now();
  return ref.watch(tripsListProvider).whenData((trips) {
    return sortTripSummaries([
      for (final trip in trips)
        TripSummary.from(
          trip: trip,
          days: ref.watch(tripDaysProvider(trip.id)).valueOrNull,
          stopCount: ref.watch(tripStopsProvider(trip.id)).valueOrNull?.length ?? 0,
          now: now,
        ),
    ]);
  });
});
