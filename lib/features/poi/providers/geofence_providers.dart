import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proximity_event.dart';
import '../services/pilgrimage_geofence_service.dart';

/// Provider for the [PilgrimageGeofenceService].
final pilgrimageGeofenceServiceProvider =
    Provider<PilgrimageGeofenceService>((ref) {
  final service = PilgrimageGeofenceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Reactive stream provider for real-time proximity events (enter/exit alerts).
final proximityEventStreamProvider = StreamProvider<ProximityEvent>((ref) {
  final service = ref.watch(pilgrimageGeofenceServiceProvider);
  return service.eventStream;
});

/// Returns the list of tracked stops the user is currently inside the geofence of.
final activeProximityStopsProvider =
    Provider<List<TrackedStopState>>((ref) {
  final service = ref.watch(pilgrimageGeofenceServiceProvider);
  return service.activeInsideStops;
});
