import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/feasibility_models.dart';
import '../services/itinerary_feasibility_service.dart';

/// Provider for the singleton [ItineraryFeasibilityService].
final itineraryFeasibilityServiceProvider = Provider<ItineraryFeasibilityService>((ref) {
  return const ItineraryFeasibilityService();
});

/// FutureProvider evaluating the feasibility of a specific day in a trip.
final dayFeasibilityProvider =
    FutureProvider.family<DayFeasibilityReport, ({String tripId, String dayId})>(
  (ref, params) async {
    final db = ref.watch(databaseProvider);
    final service = ref.watch(itineraryFeasibilityServiceProvider);
    return service.diagnoseDay(db, params.tripId, params.dayId);
  },
);

/// FutureProvider evaluating the feasibility of an entire trip across all days.
final tripFeasibilityProvider =
    FutureProvider.family<TripFeasibilityReport, String>((ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(itineraryFeasibilityServiceProvider);
  return service.diagnoseTrip(db, tripId);
});
