import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../sync/services/firestore_sync_v2_service.dart';
import '../models/trip_activity.dart';
import '../models/trip_photo.dart';

/// Abstract storage uploader to allow mocking in tests without native Firebase binaries.
abstract class StorageUploader {
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });
}

/// Firebase Storage implementation of [StorageUploader].
class FirebaseStorageUploader implements StorageUploader {
  final FirebaseStorage _storage;

  FirebaseStorageUploader([FirebaseStorage? storage])
      : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public, max-age=31536000',
    );
    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }
}

/// Service responsible for compressing, resizing, and uploading anime pilgrimage photos
/// and custom reference frame overlays to Firebase Storage & Firestore (Phase 3).
///
/// Follows specifications:
/// - Downscales long edge to a maximum of 2048px with EXIF orientation baked in.
/// - Encodes to JPEG at 85% quality to keep file sizes well below the 10MB limit.
/// - Uploads to `/tripsV2/{tripId}/trip_photos/{photoId}.jpg` under `storage.rules` RBAC.
/// - Saves metadata in `tripsV2/{tripId}/trip_photos/{photoId}`.
/// - Writes an audit entry into `tripsV2/{tripId}/activity` for collaborative visibility.
class TripPhotoUploadService {
  final FirestoreSyncV2Service _syncService;
  final StorageUploader _uploader;
  final Uuid _uuid;

  static const int maxDimension = 2048;
  static const int jpegQuality = 85;

  TripPhotoUploadService({
    required FirestoreSyncV2Service syncService,
    StorageUploader? uploader,
    Uuid? uuid,
  })  : _syncService = syncService,
        _uploader = uploader ?? FirebaseStorageUploader(),
        _uuid = uuid ?? const Uuid();

  /// Compresses [rawBytes] so the longest edge is at most [maxDim] pixels at [quality] JPEG.
  /// Bakes EXIF orientation into the pixel buffer so orientation is upright across all devices.
  static Uint8List compressAndResizeImage(
    Uint8List rawBytes, {
    int maxDim = maxDimension,
    int quality = jpegQuality,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(rawBytes);
    } catch (_) {
      throw const FormatException('Unable to decode image bytes');
    }
    if (decoded == null) {
      throw const FormatException('Unable to decode image bytes');
    }

    final image = img.bakeOrientation(decoded);
    final longEdge = math.max(image.width, image.height);

    final prepared = longEdge <= maxDim
        ? image
        : img.copyResize(
            image,
            width: (image.width * (maxDim / longEdge)).round(),
            height: (image.height * (maxDim / longEdge)).round(),
            interpolation: img.Interpolation.linear,
          );

    return Uint8List.fromList(img.encodeJpg(prepared, quality: quality));
  }

  /// Uploads a pilgrimage photo to the shared trip.
  Future<TripPhoto> uploadTripPhoto({
    required String tripId,
    String? photoId,
    String? stopId,
    String? placeKey,
    String? caption,
    required String uploadedBy,
    String? uploadedByName,
    DateTime? takenAt,
    Uint8List? rawBytes,
    File? file,
  }) async {
    final bytes = rawBytes ?? (file != null ? await file.readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) {
      throw ArgumentError('Either rawBytes or file with non-empty contents must be provided');
    }

    final id = photoId ?? _uuid.v4();
    final storagePath = 'tripsV2/$tripId/trip_photos/$id.jpg';

    // 1. Compress image to max 2048px @ 85% JPEG
    final compressedBytes = compressAndResizeImage(bytes);

    // 2. Upload to Firebase Storage
    final downloadUrl = await _uploader.uploadBytes(
      path: storagePath,
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );

    // 3. Create TripPhoto record
    final photo = TripPhoto.create(
      id: id,
      tripId: tripId,
      stopId: stopId,
      placeKey: placeKey,
      storagePath: storagePath,
      url: downloadUrl,
      caption: caption,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      takenAt: takenAt,
    );

    // 4. Save metadata in Firestore
    await _syncService.recordTripPhoto(photo);

    // 5. Record activity in audit trail
    final activity = TripActivity.create(
      id: _uuid.v4(),
      tripId: tripId,
      actorId: uploadedBy,
      actorName: uploadedByName,
      action: TripActivityAction.updateTrip,
      entityType: 'trip_photo',
      entityId: id,
      summary: '${uploadedByName ?? 'A member'} shared a pilgrimage photo',
      details: {
        'photoId': id,
        if (stopId != null) 'stopId': stopId,
        'url': downloadUrl,
      },
    );
    await _syncService.recordActivity(activity);

    return photo;
  }

  /// Uploads a custom reference screenshot frame overlay to Firebase Storage.
  Future<String> uploadReferenceImage({
    required String tripId,
    String? refImageId,
    Uint8List? rawBytes,
    File? file,
  }) async {
    final bytes = rawBytes ?? (file != null ? await file.readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) {
      throw ArgumentError('Either rawBytes or file with non-empty contents must be provided');
    }

    final id = refImageId ?? _uuid.v4();
    final storagePath = 'tripsV2/$tripId/reference_images/$id.jpg';

    final compressedBytes = compressAndResizeImage(bytes);

    return await _uploader.uploadBytes(
      path: storagePath,
      bytes: compressedBytes,
      contentType: 'image/jpeg',
    );
  }
}
