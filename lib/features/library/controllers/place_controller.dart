import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/app_result.dart';
import '../../poi/services/background_photo_save.dart' show galleryAlbum;
import '../../trip/controllers/trips_controller.dart' show isoDate;
import '../providers/place_providers.dart';
import '../services/photo_trip.dart';

/// The facts of a place that the user edits by hand.
class PlaceFacts {
  final String name;
  final String? address;
  final String? description;
  final String? accessTips;
  final String? businessHours;
  final String? contactInfo;
  final String? links;

  const PlaceFacts({
    required this.name,
    this.address,
    this.description,
    this.accessTips,
    this.businessHours,
    this.contactInfo,
    this.links,
  });
}

/// Changes made on a place's page: its facts and note, visits, anime frames
/// and photos.
final placeControllerProvider = NotifierProvider<PlaceController, AsyncValue<void>>(PlaceController.new);

class PlaceController extends Notifier<AsyncValue<void>> {
  static const _uuid = Uuid();

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<AppResult<void>> updateFacts(String placeKey, PlaceFacts facts) {
    final name = facts.name.trim();
    if (name.isEmpty) return Future.value(const Failure('Give the place a name.'));
    return _run(() => ref.read(placeRepositoryProvider).updatePlace(PlacesCompanion(
          placeKey: Value(placeKey),
          name: Value(name),
          address: Value(_clean(facts.address)),
          description: Value(_clean(facts.description)),
          accessTips: Value(_clean(facts.accessTips)),
          businessHours: Value(_clean(facts.businessHours)),
          contactInfo: Value(_clean(facts.contactInfo)),
          links: Value(_clean(facts.links)),
        )));
  }

  Future<AppResult<void>> setNote(String placeKey, String note) => _run(() => ref
      .read(placeRepositoryProvider)
      .updatePlace(PlacesCompanion(placeKey: Value(placeKey), privateNote: Value(_clean(note)))));

  Future<AppResult<void>> moveTo(String placeKey, double lat, double lng) => _run(() => ref
      .read(placeRepositoryProvider)
      .updatePlace(PlacesCompanion(placeKey: Value(placeKey), lat: Value(lat), lng: Value(lng))));

  /// Uses an anime frame (or any image on the device) as the place's cover.
  Future<AppResult<void>> setCover(String placeKey, String localPath) => _run(() => ref
      .read(placeRepositoryProvider)
      .updatePlace(PlacesCompanion(placeKey: Value(placeKey), coverLocalPath: Value(localPath))));

  /// Records that the user is at the place today, unless that's on record already.
  Future<AppResult<bool>> addVisitToday(String placeKey, {String? tripId}) {
    return _run(() async {
      final repo = ref.read(placeRepositoryProvider);
      final today = isoDate(DateTime.now());
      final visits = await repo.getVisitsForPlace(placeKey);
      if (visits.any((v) => v.date == today)) return false;
      await repo.addVisit(placeKey: placeKey, date: today, tripId: tripId);
      return true;
    });
  }

  Future<AppResult<void>> deleteVisit(String visitId) => _run(() => ref.read(placeRepositoryProvider).deleteVisit(visitId));

  /// Lets the user pick anime frames (screenshots) from the gallery and adds
  /// copies of them to the place. Returns how many were added.
  Future<AppResult<int>> addFramesFromGallery(String placeKey) {
    return _run(() async {
      final picked = await ImagePicker().pickMultiImage();
      final repo = ref.read(placeRepositoryProvider);
      for (final file in picked) {
        final path = await _copyIntoApp(file.path, 'reference_images', 'ref');
        await repo.addReferenceImage(placeKey: placeKey, localPath: path, source: 'You');
      }
      return picked.length;
    });
  }

  Future<AppResult<void>> deleteFrame(NewReferenceImage frame) {
    return _run(() async {
      await ref.read(placeRepositoryProvider).deleteReferenceImage(frame.id);
      await _deleteFile(frame.localPath);
    });
  }

  /// Lets the user pick photos from the gallery and adds copies of them to
  /// the place, each filed under the trip that had the place on the day it
  /// was taken. Returns how many were added.
  Future<AppResult<int>> addPhotosFromGallery(String placeKey) {
    return _run(() async {
      final picked = await ImagePicker().pickMultiImage();
      final repo = ref.read(placeRepositoryProvider);
      final db = ref.read(databaseProvider);
      for (final file in picked) {
        final takenAt = await File(file.path).lastModified();
        final path = await _copyIntoApp(file.path, 'camera_photos', 'photo');
        await repo.addPhoto(
          placeKey: placeKey,
          localPath: path,
          takenAt: takenAt,
          tripId: await tripForPhoto(db, placeKey, takenAt),
        );
      }
      return picked.length;
    });
  }

  Future<AppResult<void>> deletePhoto(Photo photo) {
    return _run(() async {
      await ref.read(placeRepositoryProvider).deletePhoto(photo.id);
      await _deleteFile(photo.localPath);
    });
  }

  /// Saves a copy of a photo to the phone's gallery, in the app's album.
  Future<AppResult<void>> saveToGallery(String localPath) {
    return _run(() async {
      if (!await Gal.requestAccess(toAlbum: true)) throw StateError('Allow access to your photos to save it.');
      await Gal.putImage(localPath, album: galleryAlbum);
    });
  }

  static String? _clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  /// Copies [source] into the app's own [folder], so the copy outlives the
  /// picker's temporary file.
  static Future<String> _copyIntoApp(String source, String folder, String prefix) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = p.extension(source).isEmpty ? '.jpg' : p.extension(source);
    final target = p.join(dir.path, '${prefix}_${_uuid.v4()}$ext');
    await File(source).copy(target);
    return target;
  }

  static Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A file that can't be deleted only costs space; the row is gone.
    }
  }

  Future<AppResult<T>> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final value = await action();
      state = const AsyncData(null);
      return Success(value);
    } catch (e, st) {
      state = AsyncError(e, st);
      return Failure(e.toString(), st);
    }
  }
}
