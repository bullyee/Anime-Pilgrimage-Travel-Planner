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
  final String? tripId;
  final String? dayId;
  final double? deviceHeading;
  final double maxDistanceMeters;

  const NearbyPlacesQuery({
    required this.lat,
    required this.lng,
    this.tripId,
    this.dayId,
    this.deviceHeading,
    this.maxDistanceMeters = 150.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyPlacesQuery &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          tripId == other.tripId &&
          dayId == other.dayId &&
          deviceHeading == other.deviceHeading &&
          maxDistanceMeters == other.maxDistanceMeters;

  @override
  int get hashCode => Object.hash(lat, lng, tripId, dayId, deviceHeading, maxDistanceMeters);
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
    tripId: query.tripId,
    dayId: query.dayId,
    deviceHeading: query.deviceHeading,
    maxDistanceMeters: query.maxDistanceMeters,
  );
});

/// Streams the list of [PhotoToEditItem]s waiting to be edited at home.
final photosToEditStreamProvider = StreamProvider.autoDispose<List<PhotoToEditItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageShootingServiceProvider);
  return service.watchPhotosToEdit(db);
});

/// Query parameters for watching or fetching a pilgrimage route feed.
///
/// Riverpod equality is keyed on [tripId] and [dayId] so that stream subscriptions
/// are not unnecessarily torn down and recreated on every GPS coordinate update
/// or compass heading tick.
class LiveFeedQuery {
  final String? tripId;
  final String? dayId;
  final double? userLat;
  final double? userLng;
  final double? deviceHeading;

  const LiveFeedQuery({
    this.tripId,
    this.dayId,
    this.userLat,
    this.userLng,
    this.deviceHeading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveFeedQuery &&
          runtimeType == other.runtimeType &&
          tripId == other.tripId &&
          dayId == other.dayId;

  @override
  int get hashCode => Object.hash(tripId, dayId);
}

/// Streams real-time [TodayPilgrimageFeed] for the pilgrimage route.
final pilgrimageFeedStreamProvider =
    StreamProvider.autoDispose.family<TodayPilgrimageFeed?, LiveFeedQuery>((ref, query) {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageShootingServiceProvider);
  return service.watchPilgrimageFeed(
    db,
    tripId: query.tripId,
    dayId: query.dayId,
    userLat: query.userLat,
    userLng: query.userLng,
    deviceHeading: query.deviceHeading,
  );
});

/// Legacy alias for [pilgrimageFeedStreamProvider].
final todayPilgrimageFeedStreamProvider = pilgrimageFeedStreamProvider;

/// Fetches one-shot [TodayPilgrimageFeed] snapshot for the pilgrimage route.
final pilgrimageFeedProvider =
    FutureProvider.autoDispose.family<TodayPilgrimageFeed?, LiveFeedQuery>((ref, query) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageShootingServiceProvider);
  return service.getPilgrimageFeed(
    db,
    tripId: query.tripId,
    dayId: query.dayId,
    userLat: query.userLat,
    userLng: query.userLng,
    deviceHeading: query.deviceHeading,
  );
});

/// Legacy alias for [pilgrimageFeedProvider].
final todayPilgrimageFeedProvider = pilgrimageFeedProvider;
