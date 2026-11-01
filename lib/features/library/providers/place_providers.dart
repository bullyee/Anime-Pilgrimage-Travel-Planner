import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../repositories/place_repository.dart';

/// Provides the [PlaceRepository] instance backed by Drift.
final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftPlaceRepository(db);
});

/// Streams places, optionally filtered by visibility ('saved' | 'trip_only').
final placesListProvider = StreamProvider.autoDispose.family<List<Place>, String?>((ref, visibility) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchPlaces(visibility: visibility);
});

/// Streams a single place by its [placeKey].
final placeDetailProvider = StreamProvider.autoDispose.family<Place?, String>((ref, placeKey) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchPlace(placeKey);
});

/// Streams places tagged with a specific [labelId].
final placesByLabelProvider = StreamProvider.autoDispose.family<List<Place>, String>((ref, labelId) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchPlacesByLabel(labelId);
});

/// Streams all labels, optionally filtered by [kind] ('anime' | 'tag' | 'region').
final labelsListProvider = StreamProvider.autoDispose.family<List<Label>, String?>((ref, kind) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchLabels(kind: kind);
});

/// Streams labels attached to a specific place.
final placeLabelsProvider = StreamProvider.autoDispose.family<List<Label>, String>((ref, placeKey) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchLabelsForPlace(placeKey);
});

/// Streams photos taken at a specific place.
final placePhotosProvider = StreamProvider.autoDispose.family<List<Photo>, String>((ref, placeKey) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchPhotosForPlace(placeKey);
});

/// Streams photos taken during a specific trip.
final tripPhotosProvider = StreamProvider.autoDispose.family<List<Photo>, String>((ref, tripId) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchPhotosForTrip(tripId);
});

/// Streams reference images for a specific place.
final placeReferenceImagesProvider = StreamProvider.autoDispose.family<List<NewReferenceImage>, String>((ref, placeKey) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchReferenceImagesForPlace(placeKey);
});

/// Streams visit history for a specific place.
final placeVisitsProvider = StreamProvider.autoDispose.family<List<PlaceVisit>, String>((ref, placeKey) {
  final repo = ref.watch(placeRepositoryProvider);
  return repo.watchVisitsForPlace(placeKey);
});

