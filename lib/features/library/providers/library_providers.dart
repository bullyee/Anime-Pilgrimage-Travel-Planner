import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../models/library_entry.dart';
import 'place_providers.dart';

/// Every place–label link. The repository answers per place, which would
/// take one stream per row of the library.
final placeLabelLinksProvider = StreamProvider.autoDispose<List<PlaceLabel>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.placeLabels).watch();
});

/// Which places are stops in which live trips, as (placeKey, tripId) pairs.
final placeTripLinksProvider = StreamProvider.autoDispose<List<(String, String)>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.stops).join([innerJoin(db.trips, db.trips.id.equalsExp(db.stops.tripId))])
    ..where(db.stops.deletedAt.isNull() & db.trips.deletedAt.isNull());
  return query.watch().map((rows) => [
        for (final row in rows) (row.readTable(db.stops).placeKey, row.readTable(db.stops).tripId),
      ]);
});

/// The whole library, saved and trip-only places alike; [filterLibrary]
/// narrows it down for the screen.
final libraryEntriesProvider = Provider.autoDispose<AsyncValue<List<LibraryEntry>>>((ref) {
  final places = ref.watch(placesListProvider(null));
  final labels = ref.watch(labelsListProvider(null));
  final links = ref.watch(placeLabelLinksProvider);
  final stops = ref.watch(placeTripLinksProvider);
  for (final value in [places, labels, links, stops]) {
    if (value case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (!places.hasValue || !labels.hasValue || !links.hasValue || !stops.hasValue) return const AsyncLoading();
  return AsyncData(buildLibraryEntries(
    places: places.requireValue,
    labels: labels.requireValue,
    links: links.requireValue,
    stops: stops.requireValue,
  ));
});

/// Each place's cover file, by place key, for the places that have one.
final placeCoversProvider = StreamProvider.autoDispose<Map<String, String>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.places)..where((p) => p.coverLocalPath.isNotNull());
  return query.watch().map((places) => {
        for (final p in places)
          if (p.coverLocalPath!.isNotEmpty) p.placeKey: p.coverLocalPath!,
      });
});

/// The files of each place's anime frames, oldest first, by place key: the
/// camera's place picker shows the first as a thumbnail. Frames that only
/// have a remote copy are left out.
final placeFramePathsProvider = StreamProvider.autoDispose<Map<String, List<String>>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.newReferenceImages)
    ..where((f) => f.placeKey.isNotNull() & f.localPath.isNotNull())
    ..orderBy([(f) => OrderingTerm.asc(f.createdAt)]);
  return query.watch().map((frames) {
    final byPlace = <String, List<String>>{};
    for (final f in frames) {
      byPlace.putIfAbsent(f.placeKey!, () => []).add(f.localPath!);
    }
    return byPlace;
  });
});

/// How many places carry each label, by label id.
final labelPlaceCountsProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final links = ref.watch(placeLabelLinksProvider).valueOrNull ?? const <PlaceLabel>[];
  final counts = <String, int>{};
  for (final link in links) {
    counts[link.labelId] = (counts[link.labelId] ?? 0) + 1;
  }
  return counts;
});
