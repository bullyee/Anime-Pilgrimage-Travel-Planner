import 'dart:io';

import '../../../core/database/database.dart';
import '../../library/repositories/place_repository.dart';
import '../../library/services/photo_trip.dart';
import '../../poi/services/media_asset_service.dart';
import '../models/shot_series.dart';

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
/// when the series is for a place, to that place's photos with its frame,
/// filed under the series' trip or else the trip that has the place on the
/// day it was taken. The shots' files stay where they are; the caller
/// discards the series afterwards.
///
/// The roadmap's "Record a shot" (backend item 3) takes over the place part
/// and also marks the place visited and the stop done.
Future<KeptShotsResult> saveKeptShots({
  required ShotSeries series,
  required List<SeriesShot> kept,
  required PlaceRepository places,
  required AppDatabase db,
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
    final tripId = series.tripId ??
        await tripForPhoto(db, placeKey, shot.takenAt).catchError((Object _) => null);
    final saved = await persistPlacePhoto(
      places: places,
      source: File(shot.path),
      placeKey: placeKey,
      referenceImageId: series.referenceImageId,
      tripId: tripId,
      takenAt: shot.takenAt,
    );
    if (saved) toPlace++;
  }
  return KeptShotsResult(toPlace: toPlace, toGallery: galleryCount, galleryError: galleryError);
}
