import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/trip/models/trip_activity.dart';
import 'package:trip_planner/features/trip/models/trip_photo.dart';
import 'package:trip_planner/features/trip/services/trip_photo_upload_service.dart';

void main() {
  group('TripPhotoUploadService - Image Compression', () {
    test('downscales wide image to 2048px on long edge while preserving aspect ratio', () {
      // Create a 3000x1500 test image (2:1 aspect ratio)
      final rawImage = img.Image(width: 3000, height: 1500);
      img.fill(rawImage, color: img.ColorRgb8(255, 0, 0));
      final rawBytes = Uint8List.fromList(img.encodeJpg(rawImage));

      final compressed = TripPhotoUploadService.compressAndResizeImage(rawBytes);

      final decoded = img.decodeImage(compressed);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(2048));
      expect(decoded.height, equals(1024)); // Preserved 2:1 ratio
    });

    test('downscales tall image to 2048px on long edge while preserving aspect ratio', () {
      // Create a 1000x4000 test image (1:4 aspect ratio)
      final rawImage = img.Image(width: 1000, height: 4000);
      img.fill(rawImage, color: img.ColorRgb8(0, 255, 0));
      final rawBytes = Uint8List.fromList(img.encodeJpg(rawImage));

      final compressed = TripPhotoUploadService.compressAndResizeImage(rawBytes);

      final decoded = img.decodeImage(compressed);
      expect(decoded, isNotNull);
      expect(decoded!.height, equals(2048));
      expect(decoded.width, equals(512)); // Preserved 1:4 ratio
    });

    test('keeps small image at original dimensions without upscaling', () {
      // Create an 800x600 test image
      final rawImage = img.Image(width: 800, height: 600);
      img.fill(rawImage, color: img.ColorRgb8(0, 0, 255));
      final rawBytes = Uint8List.fromList(img.encodeJpg(rawImage));

      final compressed = TripPhotoUploadService.compressAndResizeImage(rawBytes);

      final decoded = img.decodeImage(compressed);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(800));
      expect(decoded.height, equals(600));
    });

    test('throws FormatException on corrupted image bytes', () {
      final corruptedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        () => TripPhotoUploadService.compressAndResizeImage(corruptedBytes),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TripPhotoUploadService - Upload Pipeline', () {
    late _FakeStorageUploader fakeUploader;
    late _FakeFirestoreSyncService fakeSync;
    late TripPhotoUploadService service;
    late Uint8List sampleImageBytes;

    setUp(() {
      fakeUploader = _FakeStorageUploader();
      fakeSync = _FakeFirestoreSyncService();
      service = TripPhotoUploadService(
        syncService: fakeSync,
        uploader: fakeUploader,
      );

      final imgObj = img.Image(width: 2500, height: 2000);
      sampleImageBytes = Uint8List.fromList(img.encodeJpg(imgObj));
    });

    test('uploads pilgrimage photo, records TripPhoto, and writes activity log', () async {
      final photo = await service.uploadTripPhoto(
        tripId: 'trip_uji',
        photoId: 'photo_flute_1',
        stopId: 'stop_daikokuten',
        caption: 'Kumiko and Reina bench scene',
        uploadedBy: 'user_reina',
        uploadedByName: 'Reina Kousaka',
        rawBytes: sampleImageBytes,
      );

      // 1. Verify storage upload call
      expect(fakeUploader.uploadedPath, equals('tripsV2/trip_uji/trip_photos/photo_flute_1.jpg'));
      expect(fakeUploader.uploadedContentType, equals('image/jpeg'));
      expect(fakeUploader.uploadedBytes, isNotNull);

      // Verify the uploaded bytes were compressed
      final uploadedDecoded = img.decodeImage(fakeUploader.uploadedBytes!);
      expect(uploadedDecoded!.width, equals(2048));

      // 2. Verify returned TripPhoto object
      expect(photo.id, equals('photo_flute_1'));
      expect(photo.tripId, equals('trip_uji'));
      expect(photo.stopId, equals('stop_daikokuten'));
      expect(photo.url, equals('https://storage.mock/tripsV2/trip_uji/trip_photos/photo_flute_1.jpg'));
      expect(photo.caption, equals('Kumiko and Reina bench scene'));
      expect(photo.uploadedBy, equals('user_reina'));
      expect(photo.uploadedByName, equals('Reina Kousaka'));

      // 3. Verify Firestore record
      expect(fakeSync.recordedPhotos.length, equals(1));
      expect(fakeSync.recordedPhotos.first.id, equals('photo_flute_1'));

      // 4. Verify Activity log audit record
      expect(fakeSync.recordedActivities.length, equals(1));
      final activity = fakeSync.recordedActivities.first;
      expect(activity.tripId, equals('trip_uji'));
      expect(activity.actorId, equals('user_reina'));
      expect(activity.entityType, equals('trip_photo'));
      expect(activity.entityId, equals('photo_flute_1'));
      expect(activity.summary, contains('Reina Kousaka shared a pilgrimage photo'));
    });

    test('uploads custom reference image frame and returns download URL', () async {
      final url = await service.uploadReferenceImage(
        tripId: 'trip_uji',
        refImageId: 'ref_frame_1',
        rawBytes: sampleImageBytes,
      );

      expect(url, equals('https://storage.mock/tripsV2/trip_uji/reference_images/ref_frame_1.jpg'));
      expect(fakeUploader.uploadedPath, equals('tripsV2/trip_uji/reference_images/ref_frame_1.jpg'));
    });

    test('throws ArgumentError when no image bytes or file provided', () async {
      expect(
        () => service.uploadTripPhoto(
          tripId: 't1',
          uploadedBy: 'u1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

class _FakeStorageUploader implements StorageUploader {
  String? uploadedPath;
  Uint8List? uploadedBytes;
  String? uploadedContentType;

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploadedPath = path;
    uploadedBytes = bytes;
    uploadedContentType = contentType;
    return 'https://storage.mock/$path';
  }
}

class _FakeFirestoreSyncService implements FirestoreSyncV2Service {
  final List<TripPhoto> recordedPhotos = [];
  final List<TripActivity> recordedActivities = [];

  @override
  Future<void> recordTripPhoto(TripPhoto photo) async {
    recordedPhotos.add(photo);
  }

  @override
  Future<void> recordActivity(TripActivity activity) async {
    recordedActivities.add(activity);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
