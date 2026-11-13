import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../trip/providers/trip_providers.dart';
import '../models/place_diff.dart';
import '../repositories/place_repository.dart';
import 'place_providers.dart';
import '../services/place_comparison_service.dart';

/// Provides the [PlaceComparisonService] instance backed by Drift.
final placeComparisonServiceProvider = Provider<PlaceComparisonService>((ref) {
  final db = ref.watch(databaseProvider);
  final placeRepo = ref.watch(placeRepositoryProvider);
  final tripRepo = ref.watch(tripRepositoryProvider);
  return PlaceComparisonService(
    db: db,
    placeRepo: placeRepo,
    tripRepo: tripRepo,
  );
});

/// Future provider that analyzes all stops in [tripId] and compares them against the local library.
final tripLibraryDiffProvider =
    FutureProvider.autoDispose.family<TripLibraryDiffSummary, String>((ref, tripId) async {
  final service = ref.watch(placeComparisonServiceProvider);
  return service.compareTripWithLibrary(tripId);
});

/// Future provider that compares a specific [Stop] against the corresponding personal [Place].
/// Returns null if the place does not exist in the personal library or has no differences.
final stopDiffWithLibraryProvider =
    FutureProvider.autoDispose.family<PlaceDiff?, Stop>((ref, stop) async {
  final service = ref.watch(placeComparisonServiceProvider);
  final placeRepo = ref.watch(placeRepositoryProvider);
  final place = await placeRepo.getPlace(stop.placeKey);
  if (place == null) return null;
  return service.comparePlaceWithStop(place, stop);
});
