import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/walking_transit_models.dart';
import '../services/walking_transit_service.dart';

/// Provider for [WalkingTransitService].
final walkingTransitServiceProvider = Provider<WalkingTransitService>((ref) {
  return const WalkingTransitService();
});

/// Future provider calculating physical fatigue and elevation metrics for a specific trip day.
final dayWalkingFatigueProvider =
    FutureProvider.family<WalkingFatigueReport, ({String tripId, String dayId})>(
  (ref, params) async {
    final db = ref.watch(databaseProvider);
    final service = ref.watch(walkingTransitServiceProvider);
    return service.calculateDayWalkingFatigue(db, params.tripId, params.dayId);
  },
);
