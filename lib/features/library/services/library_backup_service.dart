import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database.dart';

/// Summary report returned after importing a personal library backup archive.
class LibraryImportSummary {
  final int placesImported;
  final int labelsImported;
  final int placeLabelsImported;
  final int visitsImported;
  final int photosImported;
  final int referenceImagesImported;

  const LibraryImportSummary({
    required this.placesImported,
    required this.labelsImported,
    required this.placeLabelsImported,
    required this.visitsImported,
    required this.photosImported,
    required this.referenceImagesImported,
  });
}

/// Service for exporting and importing the user's personal library as a self-contained
/// portable `.pilgrimage` zip archive (Issue #78).
///
/// Designed per the 2026-11-08 roadmap decision:
/// - The library (places, notes, visits, photos, and frames) stays strictly on the device.
/// - Moving between phones or switching to the Google Play app uses an exported file.
/// - Requires zero accounts, zero cloud servers, and preserves 100% data ownership.
/// - Complies with Rule 2 (Zero Data Loss, Topological Ingestion Ordering).
class LibraryBackupService {
  const LibraryBackupService();

  /// Exports the entire personal library into a `.pilgrimage` (zip) file.
  Future<File> exportLibraryArchive(
    AppDatabase db, {
    String? targetZipPath,
  }) async {
    final places = await db.select(db.places).get();
    final labels = await db.select(db.labels).get();
    final placeLabels = await db.select(db.placeLabels).get();
    final visits = await db.select(db.placeVisits).get();
    final photos = await db.select(db.photos).get();
    final refImages = await db.select(db.newReferenceImages).get();

    final archive = Archive();

    // 1. Manifest
    final manifest = {
      'format': 'anime_pilgrimage_library',
      'version': 1,
      'schemaVersion': 14,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': {
        'places': places.length,
        'labels': labels.length,
        'placeLabels': placeLabels.length,
        'visits': visits.length,
        'photos': photos.length,
        'referenceImages': refImages.length,
      },
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 2. Database Payload
    final payload = {
      'places': places.map((p) => p.toJson()).toList(),
      'labels': labels.map((l) => l.toJson()).toList(),
      'placeLabels': placeLabels.map((pl) => pl.toJson()).toList(),
      'visits': visits.map((v) => v.toJson()).toList(),
      'photos': photos.map((ph) => ph.toJson()).toList(),
      'referenceImages': refImages.map((r) => r.toJson()).toList(),
    };
    final payloadBytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile('library.json', payloadBytes.length, payloadBytes));

    // 3. Physical Photo Files
    for (final photo in photos) {
      final file = File(photo.localPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final filename = p.basename(photo.localPath);
        archive.addFile(ArchiveFile('photos/$filename', bytes.length, bytes));
      }
    }

    // 4. Physical Reference Frame Files
    for (final ref in refImages) {
      if (ref.localPath != null) {
        final file = File(ref.localPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final filename = p.basename(ref.localPath!);
          archive.addFile(ArchiveFile('frames/$filename', bytes.length, bytes));
        }
      }
    }

    // 5. Encode and Save Zip
    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    if (encoded == null) {
      throw StateError('Failed to encode library zip archive');
    }

    String outPath;
    if (targetZipPath != null) {
      outPath = targetZipPath;
    } else {
      final docsDir = await _getDocsDir();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      outPath = p.join(docsDir.path, 'pilgrimage_library_backup_$timestamp.pilgrimage');
    }

    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(encoded);
    return outFile;
  }

  /// Imports a personal library backup archive into the local database and filesystem.
  ///
  /// Restores entities in strict topological ordering:
  /// Places & Labels -> PlaceLabels -> PlaceVisits -> Photos & ReferenceImages.
  Future<LibraryImportSummary> importLibraryArchive(
    AppDatabase db,
    File zipFile,
  ) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? manifestFile;
    ArchiveFile? payloadFile;
    final photoFiles = <String, List<int>>{};
    final frameFiles = <String, List<int>>{};

    for (final file in archive) {
      if (file.name == 'manifest.json') {
        manifestFile = file;
      } else if (file.name == 'library.json') {
        payloadFile = file;
      } else if (file.name.startsWith('photos/') && !file.isDirectory) {
        photoFiles[p.basename(file.name)] = file.content as List<int>;
      } else if (file.name.startsWith('frames/') && !file.isDirectory) {
        frameFiles[p.basename(file.name)] = file.content as List<int>;
      }
    }

    if (manifestFile == null || payloadFile == null) {
      throw const FormatException('Invalid backup archive: missing manifest.json or library.json');
    }

    final payloadStr = utf8.decode(payloadFile.content as List<int>);
    final payloadJson = jsonDecode(payloadStr) as Map<String, dynamic>;

    final docsDir = await _getDocsDir();
    final targetPhotosDir = Directory(p.join(docsDir.path, 'app_photos'));
    final targetFramesDir = Directory(p.join(docsDir.path, 'app_frames'));
    await targetPhotosDir.create(recursive: true);
    await targetFramesDir.create(recursive: true);

    // Write physical photo files
    final photoPathMap = <String, String>{};
    for (final entry in photoFiles.entries) {
      final targetPath = p.join(targetPhotosDir.path, entry.key);
      await File(targetPath).writeAsBytes(entry.value);
      photoPathMap[entry.key] = targetPath;
    }

    // Write physical frame files
    final framePathMap = <String, String>{};
    for (final entry in frameFiles.entries) {
      final targetPath = p.join(targetFramesDir.path, entry.key);
      await File(targetPath).writeAsBytes(entry.value);
      framePathMap[entry.key] = targetPath;
    }

    // Ingest into database in topological order
    return db.transaction(() async {
      int placesCount = 0;
      int labelsCount = 0;
      int placeLabelsCount = 0;
      int visitsCount = 0;
      int photosCount = 0;
      int refImagesCount = 0;

      // 1. Places (Parent)
      final rawPlaces = (payloadJson['places'] as List?) ?? const [];
      for (final raw in rawPlaces) {
        final place = Place.fromJson(raw as Map<String, dynamic>);
        await db.into(db.places).insertOnConflictUpdate(place.toCompanion(true));
        placesCount++;
      }

      // 2. Labels (Parent)
      final rawLabels = (payloadJson['labels'] as List?) ?? const [];
      for (final raw in rawLabels) {
        final label = Label.fromJson(raw as Map<String, dynamic>);
        await db.into(db.labels).insertOnConflictUpdate(label.toCompanion(true));
        labelsCount++;
      }

      // 3. PlaceLabels (Junction)
      final rawPlaceLabels = (payloadJson['placeLabels'] as List?) ?? const [];
      for (final raw in rawPlaceLabels) {
        final pl = PlaceLabel.fromJson(raw as Map<String, dynamic>);
        await db.into(db.placeLabels).insertOnConflictUpdate(pl.toCompanion(true));
        placeLabelsCount++;
      }

      // 4. PlaceVisits (Child)
      final rawVisits = (payloadJson['visits'] as List?) ?? const [];
      for (final raw in rawVisits) {
        final visit = PlaceVisit.fromJson(raw as Map<String, dynamic>);
        await db.into(db.placeVisits).insertOnConflictUpdate(visit.toCompanion(true));
        visitsCount++;
      }

      // 5. Photos (Child)
      final rawPhotos = (payloadJson['photos'] as List?) ?? const [];
      for (final raw in rawPhotos) {
        final photo = Photo.fromJson(raw as Map<String, dynamic>);
        final filename = p.basename(photo.localPath);
        final restoredLocalPath = photoPathMap[filename] ?? photo.localPath;

        final companion = photo.copyWith(localPath: restoredLocalPath).toCompanion(true);
        await db.into(db.photos).insertOnConflictUpdate(companion);
        photosCount++;
      }

      // 6. Reference Images (Child)
      final rawRefImages = (payloadJson['referenceImages'] as List?) ?? const [];
      for (final raw in rawRefImages) {
        final ref = NewReferenceImage.fromJson(raw as Map<String, dynamic>);
        String? restoredLocalPath;
        if (ref.localPath != null) {
          final filename = p.basename(ref.localPath!);
          restoredLocalPath = framePathMap[filename] ?? ref.localPath;
        }

        final companion = ref.copyWith(localPath: Value(restoredLocalPath)).toCompanion(true);
        await db.into(db.newReferenceImages).insertOnConflictUpdate(companion);
        refImagesCount++;
      }

      return LibraryImportSummary(
        placesImported: placesCount,
        labelsImported: labelsCount,
        placeLabelsImported: placeLabelsCount,
        visitsImported: visitsCount,
        photosImported: photosCount,
        referenceImagesImported: refImagesCount,
      );
    });
  }

  Future<Directory> _getDocsDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }
}

