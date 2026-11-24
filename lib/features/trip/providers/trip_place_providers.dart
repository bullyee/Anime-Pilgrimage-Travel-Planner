import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../models/trip_places_view.dart' show TripLabel;
import '../services/place_fold_service.dart';
import 'trip_providers.dart';

// A trip's places see the whole trip's frames and photos at once: a place is
// one stop, but its frames may have come from stops folded into it, and the
// user's photos keep the place (`placeKey`) they were shot at.

/// The frames of [tripId]'s stops (stop-owned, live stops only), oldest
/// first.
final tripFramesProvider = StreamProvider.autoDispose.family<List<NewReferenceImage>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final liveStops = db.selectOnly(db.stops)
    ..addColumns([db.stops.id])
    ..where(db.stops.tripId.equals(tripId) & db.stops.deletedAt.isNull());
  return (db.select(db.newReferenceImages)
        ..where((f) => f.stopId.isInQuery(liveStops))
        ..orderBy([(f) => OrderingTerm(expression: f.createdAt), (f) => OrderingTerm(expression: f.id)]))
      .watch();
});

/// The library's frames of the places [tripId]'s stops came from, those of
/// stops since folded or deleted too, oldest first. They show for a stop that
/// has no copy of them, and a photo shot against one counts for its copies.
final tripLibraryFramesProvider = StreamProvider.autoDispose.family<List<NewReferenceImage>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final places = db.selectOnly(db.stops)
    ..addColumns([db.stops.placeKey])
    ..where(db.stops.tripId.equals(tripId));
  return (db.select(db.newReferenceImages)
        ..where((f) => f.stopId.isNull() & f.placeKey.isInQuery(places))
        ..orderBy([(f) => OrderingTerm(expression: f.createdAt), (f) => OrderingTerm(expression: f.id)]))
      .watch();
});

/// The user's photos of [tripId]: filed under the trip, or shot against one
/// of its frames (its stops', those of stops folded or deleted included, or
/// the library's of their places).
final tripPhotosProvider = StreamProvider.autoDispose.family<List<Photo>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        '''
        SELECT * FROM photos WHERE trip_id = ?1 OR reference_image_id IN (
          SELECT id FROM v10_reference_images
          WHERE stop_id IN (SELECT id FROM stops WHERE trip_id = ?1)
             OR (stop_id IS NULL AND place_key IN (SELECT place_key FROM stops WHERE trip_id = ?1))
        )
        ''',
        variables: [Variable.withString(tripId)],
        readsFrom: {db.photos, db.newReferenceImages, db.stops},
      )
      .watch()
      .map((rows) => [for (final row in rows) db.photos.map(row.data)]);
});

/// The labels of [tripId]'s stops (anime, tags and regions), by stop id,
/// sorted by name: the Places tab's line under each place (its anime) and
/// its tag filter, read for the whole trip at once.
final tripStopLabelsProvider = StreamProvider.autoDispose.family<Map<String, List<TripLabel>>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.stopLabels).join([
    innerJoin(db.labels, db.labels.id.equalsExp(db.stopLabels.labelId)),
    innerJoin(db.stops, db.stops.id.equalsExp(db.stopLabels.stopId)),
  ])
    ..where(db.stops.tripId.equals(tripId))
    ..orderBy([OrderingTerm(expression: db.labels.name)]);
  return query.watch().map((rows) {
    final out = <String, List<TripLabel>>{};
    for (final row in rows) {
      final label = row.readTable(db.labels);
      out.putIfAbsent(row.readTable(db.stopLabels).stopId, () => []).add((kind: label.kind, name: label.name));
    }
    return out;
  });
});

/// Which of a trip's days the Places tab has open, by section key; null
/// until the user opens or closes one, so the tab picks. Kept for the
/// session, so coming back to the trip finds them as they were left.
final placesOpenSectionsProvider = StateProvider.family<Set<String>?, String>((ref, tripId) => null);

final placeFoldServiceProvider = Provider<PlaceFoldService>(
  (ref) => PlaceFoldService(ref.watch(databaseProvider), ref.watch(tripRepositoryProvider)),
);

final placeFoldStoreProvider = Provider<PlaceFoldStore>(
  (ref) => kIsWeb ? InMemoryPlaceFoldStore() : FilePlaceFoldStore(),
);

/// Folds the groups of the private trips there were when this version first
/// ran, once ([PlaceFoldService.foldPrivateTripsOnce]). Not on the web, which
/// keeps no record of having done it; the trip's banner offers it there.
final placeFoldRunnerProvider = FutureProvider<int>((ref) async {
  if (kIsWeb) return 0;
  try {
    return await ref.read(placeFoldServiceProvider).foldPrivateTripsOnce(ref.read(placeFoldStoreProvider));
  } catch (e, stack) {
    debugPrint('[PlaceFold] $e\n$stack');
    return 0;
  }
});
