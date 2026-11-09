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

    // 3. Physical Place Cover Files
    for (final place in places) {
      if (place.coverLocalPath != null && place.coverLocalPath!.isNotEmpty) {
        final file = File(place.coverLocalPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final safeKey = place.placeKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final filename = '${safeKey}_${p.basename(place.coverLocalPath!)}';
          archive.addFile(ArchiveFile('covers/$filename', bytes.length, bytes));
        }
      }
    }

    // 4. Physical Photo Files (prefixed with photo.id to prevent filename collisions)
    for (final photo in photos) {
      final file = File(photo.localPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final safeId = photo.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final filename = '${safeId}_${p.basename(photo.localPath)}';
        archive.addFile(ArchiveFile('photos/$filename', bytes.length, bytes));
      }
    }

    // 5. Physical Reference Frame Files (prefixed with ref.id to prevent filename collisions)
    for (final ref in refImages) {
      if (ref.localPath != null && ref.localPath!.isNotEmpty) {
        final file = File(ref.localPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final safeId = ref.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final filename = '${safeId}_${p.basename(ref.localPath!)}';
          archive.addFile(ArchiveFile('frames/$filename', bytes.length, bytes));
        }
      }
    }

    // 6. Encode and Save Zip
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
    File zipFile, {
    Directory? baseStorageDir,
  }) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? manifestFile;
    ArchiveFile? payloadFile;
    final coverFiles = <String, List<int>>{};
    final photoFiles = <String, List<int>>{};
    final frameFiles = <String, List<int>>{};

    for (final file in archive) {
      if (file.name == 'manifest.json') {
        manifestFile = file;
      } else if (file.name == 'library.json') {
        payloadFile = file;
      } else if (file.name.startsWith('covers/') && !file.isDirectory) {
        coverFiles[p.basename(file.name)] = file.content as List<int>;
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

    final docsDir = baseStorageDir ?? await _getDocsDir();
    final targetCoversDir = Directory(p.join(docsDir.path, 'app_covers'));
    final targetPhotosDir = Directory(p.join(docsDir.path, 'app_photos'));
    final targetFramesDir = Directory(p.join(docsDir.path, 'app_frames'));
    await targetCoversDir.create(recursive: true);
    await targetPhotosDir.create(recursive: true);
    await targetFramesDir.create(recursive: true);

    // Write physical cover files
    final coverPathMap = <String, String>{};
    for (final entry in coverFiles.entries) {
      final targetPath = p.join(targetCoversDir.path, entry.key);
      await File(targetPath).writeAsBytes(entry.value);
      coverPathMap[entry.key] = targetPath;
    }

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
        final map = Map<String, dynamic>.from(raw as Map);
        map['visibility'] ??= 'saved';
        map['createdAt'] ??= DateTime.now().toIso8601String();
        map['updatedAt'] ??= DateTime.now().toIso8601String();
        final place = Place.fromJson(map);
        String? restoredCoverPath = place.coverLocalPath;
        if (place.coverLocalPath != null && place.coverLocalPath!.isNotEmpty) {
          final safeKey = place.placeKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final base = p.basename(place.coverLocalPath!);
          final prefixedName = '${safeKey}_$base';
          restoredCoverPath = coverPathMap[prefixedName] ?? coverPathMap[base] ?? place.coverLocalPath;
        }
        final companion = place.copyWith(coverLocalPath: Value(restoredCoverPath)).toCompanion(true);
        await db.into(db.places).insertOnConflictUpdate(companion);
        placesCount++;
      }

      // 2. Labels (Parent) — deduplicate against secondary unique indexes
      //    (idx_labels_bangumi_id and idx_labels_kind_name) and build ID remap table.
      final existingLabels = await db.select(db.labels).get();
      final byBangumiId = <String, Label>{
        for (final l in existingLabels)
          if (l.bangumiId != null && l.bangumiId!.isNotEmpty) l.bangumiId!: l,
      };
      final byKindAndName = <(String, String), Label>{
        for (final l in existingLabels)
          if (l.kind == 'tag' || l.kind == 'region') (l.kind, l.name): l,
      };
      final labelIdMap = <String, String>{};

      final rawLabels = (payloadJson['labels'] as List?) ?? const [];
      for (final raw in rawLabels) {
        final map = Map<String, dynamic>.from(raw as Map);
        map['createdAt'] ??= DateTime.now().toIso8601String();
        final label = Label.fromJson(map);

        Label? matchedExisting;
        if (label.bangumiId != null && label.bangumiId!.isNotEmpty) {
          matchedExisting = byBangumiId[label.bangumiId!];
        }
        if (matchedExisting == null && (label.kind == 'tag' || label.kind == 'region')) {
          matchedExisting = byKindAndName[(label.kind, label.name)];
        }

        if (matchedExisting != null && matchedExisting.id != label.id) {
          // Remap imported label ID to existing local label ID to avoid UNIQUE constraint crash
          // and preserve existing local associations.
          labelIdMap[label.id] = matchedExisting.id;
          await (db.update(db.labels)..where((l) => l.id.equals(matchedExisting!.id))).write(
            LabelsCompanion(
              name: Value(label.name),
              bangumiId: Value(label.bangumiId ?? matchedExisting.bangumiId),
            ),
          );
        } else {
          labelIdMap[label.id] = label.id;
          await db.into(db.labels).insertOnConflictUpdate(label.toCompanion(true));
          if (label.bangumiId != null && label.bangumiId!.isNotEmpty) {
            byBangumiId[label.bangumiId!] = label;
          }
          if (label.kind == 'tag' || label.kind == 'region') {
            byKindAndName[(label.kind, label.name)] = label;
          }
        }
        labelsCount++;
      }

      // 3. PlaceLabels (Junction)
      final rawPlaceLabels = (payloadJson['placeLabels'] as List?) ?? const [];
      for (final raw in rawPlaceLabels) {
        final pl = PlaceLabel.fromJson(raw as Map<String, dynamic>);
        final mappedLabelId = labelIdMap[pl.labelId] ?? pl.labelId;
        final remapped = pl.copyWith(labelId: mappedLabelId);
        await db.into(db.placeLabels).insertOnConflictUpdate(remapped.toCompanion(true));
        placeLabelsCount++;
      }

      // 4. PlaceVisits (Child)
      final rawVisits = (payloadJson['visits'] as List?) ?? const [];
      for (final raw in rawVisits) {
        final map = Map<String, dynamic>.from(raw as Map);
        map['createdAt'] ??= DateTime.now().toIso8601String();
        final visit = PlaceVisit.fromJson(map);
        await db.into(db.placeVisits).insertOnConflictUpdate(visit.toCompanion(true));
        visitsCount++;
      }

      // 5. Photos (Child)
      final rawPhotos = (payloadJson['photos'] as List?) ?? const [];
      for (final raw in rawPhotos) {
        final map = Map<String, dynamic>.from(raw as Map);
        map['kind'] ??= 'original';
        map['isShared'] ??= false;
        map['keepAsIs'] ??= false;
        map['createdAt'] ??= DateTime.now().toIso8601String();
        final photo = Photo.fromJson(map);
        final safeId = photo.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final base = p.basename(photo.localPath);
        final prefixedName = '${safeId}_$base';
        final restoredLocalPath = photoPathMap[prefixedName] ?? photoPathMap[base] ?? photo.localPath;

        final companion = photo.copyWith(localPath: restoredLocalPath).toCompanion(true);
        await db.into(db.photos).insertOnConflictUpdate(companion);
        photosCount++;
      }

      // 6. Reference Images (Child)
      final rawRefImages = (payloadJson['referenceImages'] as List?) ?? const [];
      for (final raw in rawRefImages) {
        final map = Map<String, dynamic>.from(raw as Map);
        map['createdAt'] ??= DateTime.now().toIso8601String();
        final ref = NewReferenceImage.fromJson(map);
        String? restoredLocalPath;
        if (ref.localPath != null && ref.localPath!.isNotEmpty) {
          final safeId = ref.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final base = p.basename(ref.localPath!);
          final prefixedName = '${safeId}_$base';
          restoredLocalPath = framePathMap[prefixedName] ?? framePathMap[base] ?? ref.localPath;
        }
        final mappedAnimeLabelId = ref.animeLabelId != null
            ? (labelIdMap[ref.animeLabelId!] ?? ref.animeLabelId)
            : null;

        final companion = ref
            .copyWith(
              localPath: Value(restoredLocalPath),
              animeLabelId: Value(mappedAnimeLabelId),
            )
            .toCompanion(true);
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

