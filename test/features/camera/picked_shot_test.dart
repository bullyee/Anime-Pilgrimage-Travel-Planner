import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/camera/services/picked_shot.dart';
import 'package:trip_planner/features/trip/models/place_spots.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

/// A photo picked from the gallery for a frame counts as that frame's shot.
void main() {
  group('isReadableImage', () {
    testWidgets('opens a real image and refuses empty or broken bytes', (tester) async {
      await tester.runAsync(() async {
        final png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 3)));
        expect(await isReadableImage(png), isTrue);
        expect(await isReadableImage(Uint8List(0)), isFalse);
        expect(await isReadableImage(Uint8List.fromList(List.filled(64, 7))), isFalse);
      });
    });
  });

  Uint8List jpeg({String? taken}) {
    final image = img.Image(width: 8, height: 8);
    if (taken != null) image.exif.exifIfd['DateTimeOriginal'] = taken;
    return img.encodeJpg(image);
  }

  group('exifTakenAt', () {
    test('reads DateTimeOriginal', () {
      expect(exifTakenAt(jpeg(taken: '2026:06:19 10:30:05')), DateTime(2026, 6, 19, 10, 30, 5));
    });
    test('null without it, or for something that is not a JPEG', () {
      expect(exifTakenAt(jpeg()), isNull);
      expect(exifTakenAt(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  test('recordPickedShot files the photo with the frame, so the frame counts as shot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftTripRepository(db, null, 'u1');
    final trip = await repo.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
    final stop = await repo.createTripOnlySpot(tripId: trip.id, name: '宇治橋', lat: 34.89, lng: 135.80, addedBy: 'u1');
    for (final id in ['f1', 'f2']) {
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(stop.id),
            localPath: Value('$id.png'),
          ));
    }
    final frames = await db.select(db.newReferenceImages).get();
    expect(TripFrameIndex(own: frames, library: const [], photos: const []).place([stop]).shotCount, 0);

    final result = await recordPickedShot(
      db,
      path: 'missing-picked.jpg',
      bytes: jpeg(taken: '2026:06:19 10:30:00'),
      placeKey: stop.placeKey,
      tripId: trip.id,
      frameId: 'f2',
    );
    expect(result.photo.referenceImageId, 'f2');
    expect(result.photo.tripId, trip.id);
    expect(result.photo.takenAt, DateTime(2026, 6, 19, 10, 30), reason: 'when the photo says it was taken');
    expect(result.visit.date, '2026-06-19');

    final photos = await db.select(db.photos).get();
    final place = TripFrameIndex(own: frames, library: const [], photos: photos).place([stop]);
    expect(place.shotCount, 1);
    expect(place.shot.keys, ['f2']);
    expect(place.shot['f2']!.id, result.photo.id);
  });
}
