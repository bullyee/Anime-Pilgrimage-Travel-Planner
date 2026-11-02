import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../trip/providers/trip_providers.dart';
import '../models/planner_view.dart';

/// The day planner's view of a trip. It stays loading until the trip itself
/// has loaded; days, stops and schedule items fill in as they arrive.
final plannerViewProvider = Provider.autoDispose.family<AsyncValue<PlannerView?>, String>((ref, tripId) {
  final days = ref.watch(tripDaysProvider(tripId)).valueOrNull ?? const <TripDay>[];
  final stops = ref.watch(tripStopsProvider(tripId)).valueOrNull ?? const <Stop>[];
  final items = ref.watch(scheduleItemsForTripProvider(tripId)).valueOrNull ?? const <ScheduleItem>[];
  return ref.watch(tripDetailProvider(tripId)).whenData((trip) {
    if (trip == null || trip.deletedAt != null) return null;
    return buildPlannerView(trip: trip, days: days, stops: stops, items: items);
  });
});
