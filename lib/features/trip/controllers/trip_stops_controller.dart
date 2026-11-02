import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trip_providers.dart';

/// Adds stops to a trip, from the library or as new spots, and removes them.
final tripStopsControllerProvider =
    NotifierProvider<TripStopsController, AsyncValue<void>>(TripStopsController.new);

class TripStopsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Adds library places as stops and returns how many were added. Places
  /// that are already stops in the trip are skipped.
  Future<AppResult<int>> addFromLibrary({
    required String tripId,
    required List<String> placeKeys,
  }) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);
      final inTrip = (await repo.getStopsForTrip(tripId)).map((s) => s.placeKey).toSet();
      var added = 0;
      for (final key in placeKeys) {
        if (!inTrip.add(key)) continue;
        await repo.addPlaceToTrip(tripId: tripId, placeKey: key, addedBy: userId);
        added++;
      }
      return added;
    });
  }

  /// Creates a spot that exists only in this trip (a `trip_only` place) and
  /// adds it as a stop.
  Future<AppResult<Stop>> createSpot({
    required String tripId,
    required String name,
    required double lat,
    required double lng,
    String? address,
    String? description,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Failure('Give the spot a name.');
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    return _run(() => ref.read(tripRepositoryProvider).createTripOnlySpot(
          tripId: tripId,
          name: trimmed,
          lat: lat,
          lng: lng,
          addedBy: ref.read(currentUserIdProvider),
          address: clean(address),
          description: clean(description),
        ));
  }

  /// Removes the stop from the trip, together with its place in the schedule.
  Future<AppResult<void>> removeStop(String stopId) =>
      _run(() => ref.read(tripRepositoryProvider).deleteStop(stopId));

  Future<AppResult<T>> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final value = await action();
      state = const AsyncData(null);
      return Success(value);
    } catch (e, st) {
      state = AsyncError(e, st);
      return Failure(e.toString(), st);
    }
  }
}
