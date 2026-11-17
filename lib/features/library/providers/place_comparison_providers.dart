import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../poi/services/anitabi_api_service.dart';
import '../../poi/services/anitabi_static_data.dart';
import '../../trip/providers/trip_providers.dart';
import '../models/place_diff.dart';
import '../services/anitabi_import.dart';
import '../services/place_compare_kept.dart';
import '../services/place_comparison_service.dart';
import 'place_providers.dart';

/// The [PlaceComparisonService], on the app's database and repositories.
final placeComparisonServiceProvider = Provider<PlaceComparisonService>((ref) {
  return PlaceComparisonService(
    db: ref.watch(databaseProvider),
    placeRepo: ref.watch(placeRepositoryProvider),
    tripRepo: ref.watch(tripRepositoryProvider),
  );
});

/// A trip's stops sorted against the library: not in it, different, same.
final tripLibraryDiffProvider = FutureProvider.autoDispose.family<TripLibraryDiffSummary, String>((ref, tripId) async {
  // Recount when a stop changes (a joined trip's stops arrive over sync), or
  // a place in the library does.
  await ref.watch(tripStopsProvider(tripId).future);
  await ref.watch(placesListProvider(null).future);
  return ref.watch(placeComparisonServiceProvider).compareTripWithLibrary(tripId);
});

final placeCompareKeptStoreProvider = Provider<PlaceCompareKeptStore>(
  (ref) => kIsWeb ? InMemoryPlaceCompareKeptStore() : FilePlaceCompareKeptStore(),
);

/// The differences answered with Keep mine (see [PlaceCompareKept]).
final placeCompareKeptProvider =
    AsyncNotifierProvider<PlaceCompareKeptNotifier, Map<String, String>>(PlaceCompareKeptNotifier.new);

class PlaceCompareKeptNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() => ref.watch(placeCompareKeptStoreProvider).read();

  /// Keeps the user's value of [field], until the other side's value
  /// changes from [otherValue].
  Future<void> keep(String kind, String entityId, PlaceFieldType field, String? otherValue) async {
    final next = {...await future, PlaceCompareKept.key(kind, entityId, field): otherValue ?? ''};
    state = AsyncData(next);
    try {
      await ref.read(placeCompareKeptStoreProvider).write(next);
    } catch (e) {
      debugPrint('[PlaceCompare] could not save a kept difference: $e');
    }
  }
}

/// Anitabi's current spot for an imported place (`anitabi:<id>`), read only
/// from the static data already cached on this device; null when there is
/// none, so the hint never costs Anitabi a request.
final cachedAnitabiSpotProvider = FutureProvider.autoDispose.family<AnitabiSpot?, String>((ref, placeKey) async {
  const prefix = 'anitabi:';
  if (!placeKey.startsWith(prefix)) return null;
  final spotId = placeKey.substring(prefix.length);
  final labels = await ref.watch(placeRepositoryProvider).getLabelsForPlace(placeKey);
  final bangumiIds = {
    for (final l in labels)
      if (l.kind == 'anime' && (l.bangumiId?.isNotEmpty ?? false)) l.bangumiId!,
  };
  if (bangumiIds.isEmpty) return null;
  // The client is never used: cachedWork only reads files.
  final client = http.Client();
  try {
    final data = AnitabiStaticData(client: client, cacheDir: AnitabiApiService.staticDataCacheDir);
    for (final id in bangumiIds) {
      final work = await data.cachedWork(id);
      for (final raw in work?.spots ?? const <Map<String, dynamic>>[]) {
        if (raw['id']?.toString() == spotId) return AnitabiSpot.fromJson(raw);
      }
    }
    return null;
  } finally {
    client.close();
  }
});

/// What Anitabi now says differently about a library place, without the
/// differences the user kept; null when nothing is left to show.
final anitabiPlaceDiffProvider = FutureProvider.autoDispose.family<PlaceDiff?, String>((ref, placeKey) async {
  final place = await ref.watch(placeDetailProvider(placeKey).future);
  if (place == null) return null;
  final spot = await ref.watch(cachedAnitabiSpotProvider(placeKey).future);
  if (spot == null) return null;
  final kept = await ref.watch(placeCompareKeptProvider.future);
  return PlaceCompareKept.withoutKept(
    ref.watch(placeComparisonServiceProvider).comparePlaceWithAnitabi(place, spot),
    kept,
    kind: PlaceCompareKept.anitabi,
    entityId: placeKey,
    otherValue: (d) => d.remoteValue,
  );
});

/// What the user's library place says differently from a trip's stop of it,
/// without the differences kept; null when the place isn't saved in the
/// library or nothing is left to show.
final stopLibraryDiffProvider = FutureProvider.autoDispose.family<PlaceDiff?, String>((ref, stopId) async {
  final stop = await ref.watch(stopDetailProvider(stopId).future);
  if (stop == null || stop.deletedAt != null) return null;
  final Place? place = await ref.watch(placeDetailProvider(stop.placeKey).future);
  if (place == null || place.visibility != 'saved') return null;
  final kept = await ref.watch(placeCompareKeptProvider.future);
  return PlaceCompareKept.withoutKept(
    ref.watch(placeComparisonServiceProvider).comparePlaceWithStop(place, stop),
    kept,
    kind: PlaceCompareKept.library,
    entityId: stopId,
    otherValue: (d) => d.localValue,
  );
});
