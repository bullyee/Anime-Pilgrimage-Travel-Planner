import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

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
