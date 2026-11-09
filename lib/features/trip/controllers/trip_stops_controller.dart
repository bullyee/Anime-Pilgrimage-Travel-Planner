import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/controllers/place_controller.dart' show PlaceFacts;
import '../providers/trip_providers.dart';

/// The longest trip note, in UTF-16 code units: Dart's `String.length`, and
/// what the Firestore rules' `size()` counts. The rules refuse a longer note,
/// and with it the rest of the trip's upload.
const maxTripNoteLength = 2000;

/// [base] numbered so it differs from [taken]: "Uji Bridge (2)", then "(3)".
String numberedName(String base, Set<String> taken) {
  var n = 2;
  while (taken.contains('$base ($n)')) {
    n++;
  }
  return '$base ($n)';
}

/// Adds stops to a trip, from the library or as new spots, and removes them.
final tripStopsControllerProvider =
    NotifierProvider<TripStopsController, AsyncValue<void>>(TripStopsController.new);

class TripStopsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Adds library places as stops and returns how many were added. Places
  /// that are already stops in the trip are skipped, unless [repeat] asks to
  /// add them again: a place can be two stops of one trip, each with its own
  /// plan, such as one shoot at dusk and another at night. A stop added again
  /// gets a name of its own so the two can be told apart: the one in [names]
  /// for its place, or the place's name numbered, "Uji Bridge (2)".
  Future<AppResult<int>> addFromLibrary({
    required String tripId,
    required List<String> placeKeys,
    bool repeat = false,
    Map<String, String> names = const {},
  }) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);
      final stops = await repo.getStopsForTrip(tripId);
      final inTrip = stops.map((s) => s.placeKey).toSet();
      final takenNames = stops.map((s) => s.name).toSet();
      var added = 0;
      for (final key in placeKeys) {
        final again = !inTrip.add(key);
        if (again && !repeat) continue;
        final stop = await repo.addPlaceToTrip(tripId: tripId, placeKey: key, addedBy: userId);
        final wanted = names[key]?.trim();
        final name = wanted != null && wanted.isNotEmpty
            ? wanted
            : again
                ? numberedName(stop.name, takenNames)
                : stop.name;
        if (name != stop.name) await repo.updateStop(StopsCompanion(id: Value(stop.id), name: Value(name)));
        takenNames.add(name);
        added++;
      }
      return added;
    });
  }

  /// Renames a stop in its trip. The library place keeps its name.
  Future<AppResult<void>> renameStop(String stopId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(const Failure('Give the stop a name.'));
    return _run(() => ref.read(tripRepositoryProvider).updateStop(StopsCompanion(id: Value(stopId), name: Value(trimmed))));
  }

  /// Sets the stop's trip note, which everyone in the trip sees. An empty
  /// note clears it.
  Future<AppResult<void>> setNote(String stopId, String note) {
    final trimmed = note.trim();
    if (trimmed.length > maxTripNoteLength) {
      return Future.value(const Failure('A trip note can be at most $maxTripNoteLength characters.'));
    }
    return _run(() => ref
        .read(tripRepositoryProvider)
        .updateStop(StopsCompanion(id: Value(stopId), note: Value(trimmed.isEmpty ? null : trimmed))));
  }

  /// Changes the stop's copy of the spot's facts, for everyone in the trip.
  /// The library place keeps its own.
  Future<AppResult<void>> updateFacts(String stopId, PlaceFacts facts) {
    final name = facts.name.trim();
    if (name.isEmpty) return Future.value(const Failure('Give the stop a name.'));
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    return _run(() => ref.read(tripRepositoryProvider).updateStop(StopsCompanion(
          id: Value(stopId),
          name: Value(name),
          address: Value(clean(facts.address)),
          description: Value(clean(facts.description)),
          accessTips: Value(clean(facts.accessTips)),
          businessHours: Value(clean(facts.businessHours)),
          contactInfo: Value(clean(facts.contactInfo)),
          links: Value(clean(facts.links)),
        )));
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

  /// Undoes [removeStop]: the stop comes back, on the days it was on. Like
  /// any change it syncs to a shared trip, so it comes back for everyone.
  Future<AppResult<void>> restoreStop(String stopId) =>
      _run(() => ref.read(tripRepositoryProvider).restoreStop(stopId));

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
