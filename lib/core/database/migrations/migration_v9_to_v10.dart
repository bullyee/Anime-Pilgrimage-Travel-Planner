import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';

/// Parsed episode and timestamp metadata from v8/v9 reference image metadata string.
class ParsedReferenceMetadata {
  final String? episode;
  final int? timestampS;
  final String? source;

  const ParsedReferenceMetadata({
    this.episode,
    this.timestampS,
    this.source,
  });
}

/// Parses legacy metadata from v8/v9 JSON or plain string into structured fields.
ParsedReferenceMetadata parseLegacyMetadata(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const ParsedReferenceMetadata();
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final ep = decoded['ep']?.toString();
      int? s;
      if (decoded['s'] is int) {
        s = decoded['s'];
      } else if (decoded['s'] != null) {
        s = int.tryParse(decoded['s'].toString());
      }
      final src = decoded['source']?.toString();
      return ParsedReferenceMetadata(episode: ep, timestampS: s, source: src);
    }
  } catch (_) {
    // Plain text string (e.g. "Episode 1")
    return ParsedReferenceMetadata(episode: raw.trim());
  }

  return ParsedReferenceMetadata(episode: raw.trim());
}

/// Implements the v9 -> v10 database migration described in `docs/data-model.md`:
/// - `rois` -> `labels` (kind = 'region')
/// - `animes` -> `labels` (kind = 'anime')
/// - `tags` -> `labels` (kind = 'tag')
/// - `pois` -> `places` (visibility = 'saved')
/// - `poi_animes`, `poi_tags`, `pois.roi_id` -> `place_labels`
/// - `reference_images` & `media_assets.reference_frame` -> `v10_reference_images`
/// - `media_assets.user_photo` -> `photos`
/// - Drops deprecated items (`ticket_qr`, `audio_bgm`, `time_chunks`)
class MigrationV9ToV10 {
  final AppDatabase db;

  MigrationV9ToV10(this.db);

  /// Executes the complete migration: transfers data and optionally drops legacy tables.
  Future<void> migrate({bool dropOldTables = true}) async {
    await db.transaction(() async {
      await migrateData();
      if (dropOldTables) {
        await dropLegacyTables();
      }
    });
  }

  /// Migrates all data from v9 tables into v10 tables.
  Future<void> migrateData() async {
    // 1. Migrate ROIs -> labels (kind: 'region')
    await db.customStatement('''
      INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
      SELECT id, 'region', name, NULL, (created_at / 1000)
      FROM rois;
    ''');

    // 2. Migrate Animes -> labels (kind: 'anime')
    await db.customStatement('''
      INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
      SELECT id, 'anime', name, bangumi_id, (created_at / 1000)
      FROM animes;
    ''');

    // 3. Migrate Tags -> labels (kind: 'tag')
    await db.customStatement('''
      INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
      SELECT id, 'tag', name, NULL, (created_at / 1000)
      FROM tags;
    ''');

    // 4. Migrate POIs -> places (visibility: 'saved')
    await db.customStatement('''
      INSERT OR IGNORE INTO places (
        place_key, name, lat, lng, description, address, business_hours,
        contact_info, access_tips, links, cover_local_path, cover_remote_url,
        source, source_url, private_note, visibility, created_at, updated_at
      )
      SELECT
        id, name, lat, lng, description, address, business_hours,
        contact_info, NULL, NULL, local_cover_image_path, remote_cover_image_url,
        CASE WHEN id LIKE 'anitabi:%' THEN 'Anitabi' ELSE NULL END, NULL, NULL,
        'saved', (created_at / 1000),
        CASE WHEN last_modified_at IS NOT NULL THEN last_modified_at ELSE (created_at / 1000) END
      FROM pois;
    ''');

    // 5. Migrate associations -> place_labels
    // 5a. ROI links
    await db.customStatement('''
      INSERT OR IGNORE INTO place_labels (place_key, label_id)
      SELECT id, roi_id FROM pois WHERE roi_id IS NOT NULL;
    ''');

    // 5b. Anime links
    await db.customStatement('''
      INSERT OR IGNORE INTO place_labels (place_key, label_id)
      SELECT poi_id, anime_id FROM poi_animes;
    ''');

    // 5c. Tag links
    await db.customStatement('''
      INSERT OR IGNORE INTO place_labels (place_key, label_id)
      SELECT poi_id, tag_id FROM poi_tags;
    ''');

    // 6. Migrate ReferenceImages -> v10_reference_images
    final legacyRefImages = await db.customSelect(
      'SELECT id, poi_id, local_path, remote_url, metadata, created_at FROM reference_images;',
    ).get();

    for (final row in legacyRefImages) {
      final parsed = parseLegacyMetadata(row.readNullable<String>('metadata'));
      final createdAtMs = row.read<int>('created_at');
      final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
      final poiId = row.read<String>('poi_id');

      await db.into(db.newReferenceImages).insertOnConflictUpdate(
        NewReferenceImagesCompanion.insert(
          id: row.read<String>('id'),
          placeKey: Value(poiId),
          localPath: Value(row.readNullable<String>('local_path')),
          remoteUrl: Value(row.readNullable<String>('remote_url')),
          episode: Value(parsed.episode),
          timestampS: Value(parsed.timestampS),
          source: Value(parsed.source ?? (poiId.startsWith('anitabi:') ? 'Anitabi' : null)),
          createdAt: Value(createdAt),
        ),
      );
    }

    // 7. Migrate MediaAssets
    final legacyMedia = await db.customSelect(
      'SELECT id, poi_id, type, local_path, remote_url, metadata, reference_image_id, created_at FROM media_assets;',
    ).get();

    for (final row in legacyMedia) {
      final type = row.read<String>('type');
      final id = row.read<String>('id');
      final poiId = row.read<String>('poi_id');
      final createdAtMs = row.read<int>('created_at');
      final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);

      if (type == 'user_photo') {
        await db.into(db.photos).insertOnConflictUpdate(
          PhotosCompanion.insert(
            id: id,
            placeKey: poiId,
            kind: const Value('original'),
            referenceImageId: Value(row.readNullable<String>('reference_image_id')),
            localPath: row.read<String>('local_path'),
            remoteUrl: Value(row.readNullable<String>('remote_url')),
            isShared: const Value(false),
            takenAt: Value(createdAt),
            createdAt: Value(createdAt),
          ),
        );
      } else if (type == 'reference_frame') {
        final parsed = parseLegacyMetadata(row.readNullable<String>('metadata'));
        await db.into(db.newReferenceImages).insertOnConflictUpdate(
          NewReferenceImagesCompanion.insert(
            id: id,
            placeKey: Value(poiId),
            localPath: Value(row.readNullable<String>('local_path')),
            remoteUrl: Value(row.readNullable<String>('remote_url')),
            episode: Value(parsed.episode),
            timestampS: Value(parsed.timestampS),
            source: Value(parsed.source),
            createdAt: Value(createdAt),
          ),
        );
      }
      // 'ticket_qr' and 'audio_bgm' are dropped
    }
  }

  /// Drops all legacy tables no longer needed in v10.
  Future<void> dropLegacyTables() async {
    final legacyTables = [
      'time_chunks',
      'media_assets',
      'reference_images',
      'poi_tags',
      'poi_animes',
      'tags',
      'animes',
      'pois',
      'rois',
    ];

    for (final table in legacyTables) {
      await db.customStatement('DROP TABLE IF EXISTS $table;');
    }
  }
}
