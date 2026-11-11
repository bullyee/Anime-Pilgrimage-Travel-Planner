import '../../../core/database/database.dart';
import '../models/shot_series.dart';
import 'pilgrimage_shooting_service.dart';
import 'shot_plan.dart';

/// What [saveKeptShots] managed: how many shots went to the place and to the
/// gallery, and why the gallery refused, if it did.
class KeptShotsResult {
  final int toPlace;
  final int toGallery;
  final Object? galleryError;

  const KeptShotsResult({required this.toPlace, required this.toGallery, this.galleryError});
}

/// Saves the shots the user kept from [series], as they were shot: no
/// editing on the spot (roadmap v0.3.0).
///
/// Each one goes to the phone's gallery through [toGallery], when given, and,
/// when the series is for a place, is recorded with
/// [PilgrimageShootingService.recordShot]: a copy in the app, a row in the
/// place's photos with the frame it was taken with, and the day's visit to the place, logged
/// once per place per day however many shots are kept. The photos are filed
/// under the series' trip, else the trip that has the place on the day they
/// were taken, else the trip on that day ([shotTrip]). Nothing in the plan
/// changes: the pick screen's ticks do that (`shot_plan.dart`). The shots'
/// files stay where they are; the caller discards the series afterwards.
Future<KeptShotsResult> saveKeptShots({
  required ShotSeries series,
  required List<SeriesShot> kept,
  required AppDatabase db,
  PilgrimageShootingService shooting = const PilgrimageShootingService(),
  Future<void> Function(String path)? toGallery,
}) async {
  var toPlace = 0;
  var galleryCount = 0;
  Object? galleryError;
  for (final shot in kept) {
    if (toGallery != null && galleryError == null) {
      try {
        await toGallery(shot.path);
        galleryCount++;
      } catch (e) {
        // One refusal (no access) refuses them all; the place still gets them.
        galleryError = e;
      }
    }
    final placeKey = series.placeKey;
    if (placeKey == null) continue;
    try {
      // Not knowing the trip shouldn't lose the photo.
      final tripId =
          series.tripId ??
          await shotTrip(
            db,
            placeKey: placeKey,
            takenAt: shot.takenAt,
          ).then<String?>((t) => t?.id, onError: (Object _) => null);
      await shooting.recordShot(
        db,
        sourceImagePath: shot.path,
        placeKey: placeKey,
        tripId: tripId,
        // The frame floating when this shot was taken.
        referenceImageId: series.frameOf(shot)?.imageId,
        takenAt: shot.takenAt,
      );
      toPlace++;
    } catch (_) {
      // Counted as not saved; the caller keeps the series so nothing is lost.
    }
  }
  return KeptShotsResult(toPlace: toPlace, toGallery: galleryCount, galleryError: galleryError);
}
