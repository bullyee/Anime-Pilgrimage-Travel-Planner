import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/shooting_core_models.dart';
import '../services/pilgrimage_shooting_service.dart';

/// Provider for the singleton [PilgrimageShootingService].
final pilgrimageShootingServiceProvider = Provider<PilgrimageShootingService>((ref) {
  return const PilgrimageShootingService();
});

/// Streams or provides [TodayTripInfo] for the current calendar date.
final todayTripProvider = FutureProvider.autoDispose<TodayTripInfo?>((ref) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageShootingServiceProvider);
  return service.getTodayTrip(db);
});

/// Parameters for querying nearby shooting places.
class NearbyPlacesQuery {
  final double lat;
  final double lng;
  final double maxDistanceMeters;

  const NearbyPlacesQuery({
    required this.lat,
    required this.lng,
    this.maxDistanceMeters = 150.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyPlacesQuery &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          maxDistanceMeters == other.maxDistanceMeters;

  @override
  int get hashCode => Object.hash(lat, lng, maxDistanceMeters);
}

/// Provides list of [NearbyShootingPlace] candidates within range of the given coordinate.
final nearbyShootingPlacesProvider =
    FutureProvider.autoDispose.family<List<NearbyShootingPlace>, NearbyPlacesQuery>((ref, query) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageShootingServiceProvider);
  return service.findNearbyPlaces(
    db,
    lat: query.lat,
    lng: query.lng,
    maxDistanceMeters: query.maxDistanceMeters,
  );
});

/// Streams the list of [PhotoToEditItem]s waiting to be edited at home.
final photosToEditStreamProvider = StreamProvider.autoDispose<List<PhotoToEditItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageShootingServiceProvider);
  return service.watchPhotosToEdit(db);
});
