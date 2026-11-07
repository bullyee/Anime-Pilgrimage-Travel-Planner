import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/photo_exif_models.dart';
import '../services/photo_scene_matcher_service.dart';

/// Provider for the singleton [PhotoSceneMatcherService].
final photoSceneMatcherServiceProvider =
    Provider<PhotoSceneMatcherService>((ref) {
  return const PhotoSceneMatcherService();
});

/// FutureProvider that matches a list of candidate photos against a trip's itinerary.
final tripPhotoMatchesProvider = FutureProvider.family<
    List<PhotoMatchResult>, ({String tripId, List<PhotoInput> photos})>(
  (ref, params) async {
    final db = ref.watch(databaseProvider);
    final service = ref.watch(photoSceneMatcherServiceProvider);
    return service.matchPhotosForTrip(db, params.tripId, params.photos);
  },
);
