import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/colocated_spot_models.dart';
import '../services/colocated_spot_linking_service.dart';

/// Provider for the singleton [ColocatedSpotLinkingService].
final colocatedSpotLinkingServiceProvider =
    Provider<ColocatedSpotLinkingService>((ref) {
  return const ColocatedSpotLinkingService();
});

/// FutureProvider discovering all multi-anime co-located hubs in the user's saved library.
final libraryColocatedHubsProvider =
    FutureProvider<CrossAnimeLinkResult>((ref) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(colocatedSpotLinkingServiceProvider);
  return service.findLibraryColocatedHubs(db);
});

/// FutureProvider discovering all multi-anime co-located hubs within a specific [tripId].
final tripColocatedHubsProvider =
    FutureProvider.family<CrossAnimeLinkResult, String>((ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(colocatedSpotLinkingServiceProvider);
  return service.findTripColocatedHubs(db, tripId);
});

/// FutureProvider discovering other cross-anime scenes adjacent to a specific trip stop.
final stopCrossAnimeScenesProvider = FutureProvider.family<
    List<ColocatedSpotItem>, ({String tripId, String stopId})>(
  (ref, params) async {
    final db = ref.watch(databaseProvider);
    final service = ref.watch(colocatedSpotLinkingServiceProvider);

    final tripHubs = await service.findTripColocatedHubs(db, params.tripId);
    return tripHubs.crossAnimeSpotsFor(params.stopId);
  },
);
