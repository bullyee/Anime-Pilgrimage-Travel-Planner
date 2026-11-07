import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_snapshot_models.dart';
import '../services/itinerary_snapshot_service.dart';
import '../services/trip_snapshot_store.dart';

/// Provider for the snapshot storage implementation.
final tripSnapshotStoreProvider = Provider<TripSnapshotStore>((ref) {
  return LocalDiskTripSnapshotStore();
});

/// Provider for [ItinerarySnapshotService].
final itinerarySnapshotServiceProvider = Provider<ItinerarySnapshotService>((ref) {
  final store = ref.watch(tripSnapshotStoreProvider);
  return ItinerarySnapshotService(store: store);
});

/// Future provider listing all snapshots for a given [tripId].
final tripSnapshotsProvider = FutureProvider.family<List<TripSnapshotMetadata>, String>((ref, tripId) async {
  final service = ref.watch(itinerarySnapshotServiceProvider);
  return service.listSnapshots(tripId);
});
