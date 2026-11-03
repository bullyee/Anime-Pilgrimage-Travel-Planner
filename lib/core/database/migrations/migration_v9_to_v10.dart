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
  ///
  /// This operation is idempotent (`INSERT OR IGNORE` / `insertOnConflictUpdate`)
  /// and keeps legacy tables intact until [dropLegacyTables] is called at Stage 2
  /// cutover. Re-run [migrateData] right before dropping the legacy tables so
  /// any writes made through legacy screens during the transition are migrated.
  Future<void> migrateData() async {
    // Ensure unique partial indexes on labels exist before inserting so
    // INSERT OR IGNORE naturally deduplicates against both legacy and v10 rows.
    await db.customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_labels_kind_name
      ON labels(kind, name)
      WHERE kind IN ('tag', 'region');
    ''');
    await db.customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_labels_bangumi_id
      ON labels(bangumi_id)
      WHERE bangumi_id IS NOT NULL;
    ''');

    // Discover which legacy tables exist in the database before querying.
    final existingTables = (await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((r) => r.read<String>('name')).toSet();

    final hasRois = existingTables.contains('rois');
    final hasAnimes = existingTables.contains('animes');
    final hasTags = existingTables.contains('tags');
    final hasPois = existingTables.contains('pois');
    final hasPoiAnimes = existingTables.contains('poi_animes');
    final hasPoiTags = existingTables.contains('poi_tags');
    final hasRefImages = existingTables.contains('reference_images');
    final hasMediaAssets = existingTables.contains('media_assets');

    // Discover column availability in legacy tables to support upgrades from
    // older schemas (v0.1.0 was schema 5, v0.1.1-v0.1.2 were schema 8).
    Set<String> poiColumns = const {};
    if (hasPois) {
      poiColumns = (await db.customSelect(
        "PRAGMA table_info(pois)",
      ).get()).map((r) => r.read<String>('name')).toSet();
    }
    final hasPoiIsDeleted = poiColumns.contains('is_deleted');
    final poiWhereClause = hasPoiIsDeleted ? 'WHERE COALESCE(p.is_deleted, 0) = 0' : '';

    // 1. Migrate ROIs -> labels (kind: 'region'), deduplicating by name
    if (hasRois) {
      await db.customStatement('''
        INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
        SELECT MIN(id), 'region', name, NULL, (MIN(created_at) / 1000)
        FROM rois
        GROUP BY name;
      ''');
    }

    // 2. Migrate Animes -> labels (kind: 'anime')
    if (hasAnimes) {
      // 2a. Animes with a bangumi_id (deduplicated by bangumi_id)
      await db.customStatement('''
        INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
        SELECT MIN(id), 'anime', name, bangumi_id, (MIN(created_at) / 1000)
        FROM animes
        WHERE bangumi_id IS NOT NULL
        GROUP BY bangumi_id;
      ''');
      // 2b. Animes without a bangumi_id (deduplicated by name, skipped if an anime label with the same name already exists)
      await db.customStatement('''
        INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
        SELECT MIN(a.id), 'anime', a.name, NULL, (MIN(a.created_at) / 1000)
        FROM animes a
        WHERE a.bangumi_id IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM labels l WHERE l.kind = 'anime' AND l.name = a.name
          )
        GROUP BY a.name;
      ''');
    }

    // 3. Migrate Tags -> labels (kind: 'tag'), deduplicating by name
    if (hasTags) {
      await db.customStatement('''
        INSERT OR IGNORE INTO labels (id, kind, name, bangumi_id, created_at)
        SELECT MIN(id), 'tag', name, NULL, (MIN(created_at) / 1000)
        FROM tags
        GROUP BY name;
      ''');
    }

    // 4. Migrate POIs -> places (visibility: 'saved'), skipping deleted spots (tombstones)
    if (hasPois) {
      final coverLocalExpr = poiColumns.contains('local_cover_image_path')
          ? 'local_cover_image_path'
          : (poiColumns.contains('cover_image_uri') ? 'cover_image_uri' : 'NULL');

      final coverRemoteExpr = poiColumns.contains('remote_cover_image_url')
          ? 'remote_cover_image_url'
          : 'NULL';

      final whereClause = hasPoiIsDeleted ? 'WHERE COALESCE(is_deleted, 0) = 0' : '';

      final updatedAtExpr = poiColumns.contains('last_modified_at')
          ? 'CASE WHEN last_modified_at IS NOT NULL THEN (last_modified_at * 1000) ELSE created_at END'
          : 'created_at';

      await db.customStatement('''
        INSERT OR IGNORE INTO places (
          place_key, name, lat, lng, description, address, business_hours,
          contact_info, access_tips, links, cover_local_path, cover_remote_url,
          source, source_url, private_note, visibility, created_at, updated_at
        )
        SELECT
          id, name, lat, lng, description, address, business_hours,
          contact_info, NULL, NULL, $coverLocalExpr, $coverRemoteExpr,
          CASE WHEN id LIKE 'anitabi:%' THEN 'Anitabi' ELSE NULL END, NULL, NULL,
          'saved', (created_at / 1000),
          $updatedAtExpr
        FROM pois
        $whereClause;
      ''');
    }

    // 5. Migrate associations -> place_labels by joining canonical rows in `labels`
    // 5a. ROI links
    if (hasPois && hasRois) {
      await db.customStatement('''
        INSERT OR IGNORE INTO place_labels (place_key, label_id)
        SELECT p.id, l.id
        FROM pois p
        JOIN rois r ON p.roi_id = r.id
        JOIN labels l ON l.kind = 'region' AND l.name = r.name
        $poiWhereClause;
      ''');
    }

    // 5b. Anime links
    if (hasPois && hasAnimes && hasPoiAnimes) {
      await db.customStatement('''
        INSERT OR IGNORE INTO place_labels (place_key, label_id)
        SELECT pa.poi_id, l.id
        FROM poi_animes pa
        JOIN animes a ON pa.anime_id = a.id
        JOIN labels l ON l.kind = 'anime' AND (
          (a.bangumi_id IS NOT NULL AND l.bangumi_id = a.bangumi_id)
          OR (a.bangumi_id IS NULL AND l.name = a.name)
        )
        JOIN pois p ON pa.poi_id = p.id
        $poiWhereClause;
      ''');
    }

    // 5c. Tag links
    if (hasPois && hasTags && hasPoiTags) {
      await db.customStatement('''
        INSERT OR IGNORE INTO place_labels (place_key, label_id)
        SELECT pt.poi_id, l.id
        FROM poi_tags pt
        JOIN tags t ON pt.tag_id = t.id
        JOIN labels l ON l.kind = 'tag' AND l.name = t.name
        JOIN pois p ON pt.poi_id = p.id
        $poiWhereClause;
      ''');
    }

    // 6. Migrate ReferenceImages -> v10_reference_images (only for active places)
    if (hasRefImages) {
      final refColumns = (await db.customSelect(
        "PRAGMA table_info(reference_images)",
      ).get()).map((r) => r.read<String>('name')).toSet();

      final localCol = refColumns.contains('local_path')
          ? 'local_path'
          : (refColumns.contains('local_uri') ? 'local_uri AS local_path' : 'NULL AS local_path');
      final remoteCol = refColumns.contains('remote_url') ? 'remote_url' : 'NULL AS remote_url';

      final legacyRefImages = await db.customSelect(
        'SELECT id, poi_id, $localCol, $remoteCol, metadata, created_at FROM reference_images WHERE poi_id IN (SELECT place_key FROM places);',
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
    }

    // 7. Migrate MediaAssets (only for active places)
    if (hasMediaAssets) {
      final mediaColumns = (await db.customSelect(
        "PRAGMA table_info(media_assets)",
      ).get()).map((r) => r.read<String>('name')).toSet();

      final localCol = mediaColumns.contains('local_path')
          ? 'local_path'
          : (mediaColumns.contains('local_uri') ? 'local_uri AS local_path' : 'NULL AS local_path');
      final remoteCol = mediaColumns.contains('remote_url') ? 'remote_url' : 'NULL AS remote_url';
      final refImgCol = mediaColumns.contains('reference_image_id')
          ? 'reference_image_id'
          : 'NULL AS reference_image_id';

      final legacyMedia = await db.customSelect(
        'SELECT id, poi_id, type, $localCol, $remoteCol, metadata, $refImgCol, created_at FROM media_assets WHERE poi_id IN (SELECT place_key FROM places);',
      ).get();

      for (final row in legacyMedia) {
        final type = row.read<String>('type');
        final id = row.read<String>('id');
        final poiId = row.read<String>('poi_id');
        final createdAtMs = row.read<int>('created_at');
        final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
        final localPath = row.readNullable<String>('local_path');

        if (type == 'user_photo' || type == 'uploaded_image' || type == 'comparison_image') {
          if (localPath == null || localPath.isEmpty) {
            continue;
          }
          final kind = type == 'comparison_image' ? 'comparison' : 'original';
          await db.into(db.photos).insertOnConflictUpdate(
            PhotosCompanion.insert(
              id: id,
              placeKey: poiId,
              kind: Value(kind),
              referenceImageId: Value(row.readNullable<String>('reference_image_id')),
              localPath: localPath,
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
              localPath: Value(localPath),
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
  }

  /// Drops all legacy tables no longer needed in v10+.
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
