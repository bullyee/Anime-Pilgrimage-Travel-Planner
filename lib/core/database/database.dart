import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'connection/connection.dart' as db_connection;
import 'tables.dart';
import 'tables_v10.dart';
import 'migrations/migration_v9_to_v10.dart';

part 'database.g.dart';


@DriftDatabase(tables: [
  Rois,
  Pois,
  Animes,
  Tags,
  PoiAnimes,
  PoiTags,
  TimeChunks,
  MediaAssets,
  ReferenceImages,
  Places,
  Labels,
  PlaceLabels,
  Photos,
  PlaceVisits,
  NewReferenceImages,
  Trips,
  TripDays,
  Stops,
  StopLabels,
  ScheduleItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(db_connection.openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(referenceImages);
          }
          if (from < 3) {
            await m.addColumn(mediaAssets, mediaAssets.referenceImageId);
          }
          if (from < 4) {
            await _migrateToEntityTables(m);
          }
          if (from < 5) {
            await _addCreatedAtColumns();
          }
          if (from < 6) {
            await _migrateToSyncSchema(m);
          }
          if (from < 7) {
            // Time-chunk sequencing columns (sortOrder/duration/transit/fixed).
            await m.addColumn(timeChunks, timeChunks.sortOrder);
            await m.addColumn(timeChunks, timeChunks.duration);
            await m.addColumn(timeChunks, timeChunks.transitDuration);
            await m.addColumn(timeChunks, timeChunks.isFixedTime);
          }
          if (from < 8) {
            await _migrateToAdvancedSyncSchema(m);
          }
          if (from < 9) {
            await m.addColumn(pois, pois.syncStatus);
            await m.addColumn(pois, pois.isDeleted);
            await m.addColumn(pois, pois.hasEverSynced);
            await m.addColumn(pois, pois.lastModifiedAt);

            // Backfill hasEverSynced for existing shared trips (#45)
            await customStatement('''
              UPDATE pois SET has_ever_synced = 1
              WHERE roi_id IN (SELECT id FROM rois WHERE is_shared = 1 AND cloud_version > 0);
            ''');
          }
          if (from < 10) {
            await m.createTable(places);
            await m.createTable(labels);
            await m.createTable(placeLabels);
            await m.createTable(photos);
            await m.createTable(placeVisits);
            await m.createTable(newReferenceImages);
            await m.createTable(trips);
            await m.createTable(tripDays);
            await m.createTable(stops);
            await m.createTable(stopLabels);
            await m.createTable(scheduleItems);

            // Migrate legacy data to v10 tables
            await MigrationV9ToV10(this).migrateData();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _migrateToAdvancedSyncSchema(Migrator m) async {
    await m.addColumn(rois, rois.cloudVersion);
    await m.addColumn(rois, rois.syncLockExpiresAt);

    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      timeChunks,
      newColumns: [
        timeChunks.syncStatus,
        timeChunks.isDeleted,
        timeChunks.hasEverSynced,
        timeChunks.originalStartTime,
        timeChunks.originalEndTime,
        timeChunks.lastModifiedAt,
      ],
      columnTransformer: {
        timeChunks.syncStatus: const CustomExpression<int>(
            'CASE WHEN is_shared = 1 THEN 0 ELSE 1 END'),
        timeChunks.hasEverSynced: const CustomExpression<bool>('is_shared'),
      },
    ));
    
  }

  Future<void> _migrateToEntityTables(Migrator m) async {
    // Step 1: create the four new tables.
    await m.createTable(animes);
    await m.createTable(tags);
    await m.createTable(poiAnimes);
    await m.createTable(poiTags);

    // Step 2: backfill from the legacy columns BEFORE they are dropped.
    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();
    final animeNameToId = <String, String>{};
    final tagNameToId = <String, String>{};

    final legacyRows = await customSelect(
      'SELECT id, anime_series_ref, tags FROM pois',
    ).get();

    for (final row in legacyRows) {
      final poiId = row.read<String>('id');

      final animeName = row.readNullable<String>('anime_series_ref')?.trim();
      if (animeName != null && animeName.isNotEmpty) {
        var animeId = animeNameToId[animeName];
        if (animeId == null) {
          animeId = uuid.v4();
          animeNameToId[animeName] = animeId;
          await customStatement(
            'INSERT INTO animes (id, name, created_at) VALUES (?, ?, ?)',
            [animeId, animeName, now],
          );
        }
        await customStatement(
          'INSERT OR IGNORE INTO poi_animes (poi_id, anime_id) VALUES (?, ?)',
          [poiId, animeId],
        );
      }

      final tagStr = row.readNullable<String>('tags')?.trim();
      if (tagStr != null && tagStr.isNotEmpty) {
        for (final raw in tagStr.split(',')) {
          final tagName = raw.trim();
          if (tagName.isEmpty) continue;
          var tagId = tagNameToId[tagName];
          if (tagId == null) {
            tagId = uuid.v4();
            tagNameToId[tagName] = tagId;
            await customStatement(
              'INSERT INTO tags (id, name, created_at) VALUES (?, ?, ?)',
              [tagId, tagName, now],
            );
          }
          await customStatement(
            'INSERT OR IGNORE INTO poi_tags (poi_id, tag_id) VALUES (?, ?)',
            [poiId, tagId],
          );
        }
      }
    }

    // Step 3: drop legacy columns and relax roi_id to nullable.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(pois));
  }

  /// v4 -> v5: add the non-nullable `created_at` column to pois,
  /// reference_images and media_assets.
  ///
  /// These columns are declared with a Dart-side `clientDefault` only, so the
  /// generated DDL carries no SQL default. A plain `addColumn` would emit
  /// `ADD COLUMN created_at INTEGER NOT NULL`, which SQLite rejects on tables
  /// that already contain rows. We add each column with an explicit SQL default
  /// equal to the migration timestamp so existing rows are backfilled.
  Future<void> _addCreatedAtColumns() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final table in const ['pois', 'reference_images', 'media_assets']) {
      await customStatement(
        'ALTER TABLE $table ADD COLUMN created_at INTEGER NOT NULL DEFAULT $now',
      );
    }
  }

  /// v5 -> v6: introduce the dual-track sync schema.
  ///
  /// This adds the per-row ownership / sync columns and splits the local-file
  /// columns into local/remote pairs:
  ///   * `author_id` (non-nullable) on rois, animes, tags, pois, time_chunks,
  ///     media_assets and reference_images;
  ///   * `is_shared` on rois, animes, tags, pois and time_chunks;
  ///   * `created_at` on time_chunks;
  ///   * `sort_order` and `remote_cover_image_url` on pois, with
  ///     `cover_image_uri` renamed to `local_cover_image_path`;
  ///   * `local_uri` renamed to `local_path` on media_assets and
  ///     reference_images.
  ///
  // ignore: experimental_member_use
  /// Each affected table is rebuilt with [TableMigration] so existing rows are
  /// preserved. New non-nullable columns are backfilled — `author_id` to the
  /// offline guest id (the same placeholder the running app uses before sign-in,
  /// see `currentUserIdProvider`), `created_at` to the migration timestamp — and
  /// the renamed file columns are relaxed to nullable to match the new schema.
  Future<void> _migrateToSyncSchema(Migrator m) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const guestAuthorId = 'guest_local_user';

    // pois: + author_id, is_shared, sort_order, remote_cover_image_url;
    //       cover_image_uri -> local_cover_image_path (kept nullable).
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      pois,
      newColumns: [
        pois.authorId,
        pois.isShared,
        pois.sortOrder,
        pois.remoteCoverImageUrl,
      ],
      columnTransformer: {
        pois.authorId: const Constant(guestAuthorId),
        pois.localCoverImagePath:
            const CustomExpression<String>('cover_image_uri'),
      },
    ));

    // rois: + author_id, is_shared.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      rois,
      newColumns: [rois.authorId, rois.isShared],
      columnTransformer: {rois.authorId: const Constant(guestAuthorId)},
    ));

    // animes: + author_id, is_shared.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      animes,
      newColumns: [animes.authorId, animes.isShared],
      columnTransformer: {animes.authorId: const Constant(guestAuthorId)},
    ));

    // tags: + author_id, is_shared.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      tags,
      newColumns: [tags.authorId, tags.isShared],
      columnTransformer: {tags.authorId: const Constant(guestAuthorId)},
    ));

    // time_chunks: + author_id, is_shared, created_at.
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      timeChunks,
      newColumns: [
        timeChunks.authorId,
        timeChunks.isShared,
        timeChunks.createdAt,
      ],
      columnTransformer: {
        timeChunks.authorId: const Constant(guestAuthorId),
        timeChunks.createdAt: Constant(now),
      },
    ));

    // media_assets: + author_id; local_uri -> local_path (kept nullable).
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      mediaAssets,
      newColumns: [mediaAssets.authorId],
      columnTransformer: {
        mediaAssets.authorId: const Constant(guestAuthorId),
        mediaAssets.localPath: const CustomExpression('local_uri'),
      },
    ));

    // reference_images: + author_id; local_uri -> local_path (kept nullable).
    // ignore: experimental_member_use
    await m.alterTable(TableMigration(
      referenceImages,
      newColumns: [referenceImages.authorId],
      columnTransformer: {
        referenceImages.authorId: const Constant(guestAuthorId),
        referenceImages.localPath: const CustomExpression('local_uri'),
      },
    ));
  }

  // --- ROI Queries ---
  Future<List<Roi>> getAllRois() => select(rois).get();

  Stream<List<Roi>> watchAllRois() => select(rois).watch();

  Future<Roi> getRoiById(String id) =>
      (select(rois)..where((r) => r.id.equals(id))).getSingle();

  Stream<Roi?> watchRoiById(String id) =>
      (select(rois)..where((r) => r.id.equals(id))).watchSingleOrNull();

  Future<int> insertRoi(RoisCompanion roi) => into(rois).insert(roi);

  Future<bool> updateRoi(RoisCompanion roi) => update(rois).replace(roi);

  Future<int> deleteRoi(String id) =>
      (delete(rois)..where((r) => r.id.equals(id))).go();

  // --- POI Queries ---
  /// Fetches the highest sortOrder currently assigned to a POI within a specific ROI.
  /// Returns 0 if the ROI is empty.
  Future<int> _getMaxSortOrderForRoi(String roiId) async {
    final query = select(pois)
      ..where((t) => t.roiId.equals(roiId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.desc)
      ])
      ..limit(1);

    final lastPoi = await query.getSingleOrNull();
    return lastPoi?.sortOrder ?? 0;
  }

  /// Inserts a new POI and automatically assigns a spaced sortOrder (default spacing 2048).
  /// Use this method instead of insertPoi when adding a POI to an ROI.
  Future<int> insertPoiWithSpacedOrder(PoisCompanion poi, String roiId) async {
    final currentMaxOrder = await _getMaxSortOrderForRoi(roiId);
    final nextOrder = currentMaxOrder + 2048;

    final updatedPoi = poi.copyWith(sortOrder: Value(nextOrder));
    
    return into(pois).insert(updatedPoi);
  }
  
  Future<List<Poi>> getPoisByRoi(String roiId) =>
      (select(pois)..where((p) => p.roiId.equals(roiId) & p.isDeleted.equals(false))).get();

  Future<List<Poi>> getPoisByDate(String date) {
    final query = select(pois).join([
      innerJoin(timeChunks, timeChunks.poiId.equalsExp(pois.id)),
    ])
      ..where(timeChunks.date.equals(date) &
          timeChunks.isDeleted.equals(false) &
          pois.isDeleted.equals(false))
      ..groupBy([pois.id])
      ..orderBy([
        OrderingTerm.asc(timeChunks.startTime),
        OrderingTerm.asc(pois.sortOrder),
        OrderingTerm.asc(pois.name),
      ]);
    return query.map((row) => row.readTable(pois)).get();
  }

  Stream<List<Poi>> watchPoisByRoi(String roiId) =>
      (select(pois)..where((p) => p.roiId.equals(roiId) & p.isDeleted.equals(false))).watch();

  Stream<List<Poi>> watchPoisWithoutRoi() =>
      (select(pois)..where((p) => p.roiId.isNull() & p.isDeleted.equals(false))).watch();

  Future<Poi> getPoiById(String id) =>
      (select(pois)..where((p) => p.id.equals(id))).getSingle();

  Stream<Poi?> watchPoiById(String id) =>
      (select(pois)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Stream<List<Poi>> watchAllPois() => (select(pois)..where((p) => p.isDeleted.equals(false))).watch();

  Future<int> insertPoi(PoisCompanion poi) => into(pois).insert(poi);

  Future<bool> updatePoi(PoisCompanion poi) => update(pois).replace(poi);

  Future<List<Poi>> getAllPois() => (select(pois)..where((p) => p.isDeleted.equals(false))).get();

  Future<int> hardDeletePoi(String id) {
    return transaction(() async {
      await (delete(mediaAssets)..where((m) => m.poiId.equals(id))).go();
      await (delete(referenceImages)..where((r) => r.poiId.equals(id))).go();
      await (delete(timeChunks)..where((t) => t.poiId.equals(id))).go();
      await (delete(poiAnimes)..where((pa) => pa.poiId.equals(id))).go();
      await (delete(poiTags)..where((pt) => pt.poiId.equals(id))).go();
      return (delete(pois)..where((p) => p.id.equals(id))).go();
    });
  }

  Future<int> deletePoi(String id) {
    return transaction(() async {
      final poi = await (select(pois)..where((p) => p.id.equals(id))).getSingleOrNull();
      if (poi != null && poi.hasEverSynced) {
        await (update(pois)..where((p) => p.id.equals(id))).write(
          PoisCompanion(
            isDeleted: const Value(true),
            syncStatus: Value(SyncStatus.dirty.index),
            lastModifiedAt: Value(DateTime.now()),
          ),
        );
        final chunks = await (select(timeChunks)..where((t) => t.poiId.equals(id))).get();
        for (final c in chunks) {
          if (c.hasEverSynced) {
            await (update(timeChunks)..where((t) => t.id.equals(c.id))).write(
              TimeChunksCompanion(
                isDeleted: const Value(true),
                syncStatus: Value(SyncStatus.dirty.index),
                lastModifiedAt: Value(DateTime.now()),
              ),
            );
          } else {
            await (delete(timeChunks)..where((t) => t.id.equals(c.id))).go();
          }
        }
        return 1;
      } else {
        await (delete(mediaAssets)..where((m) => m.poiId.equals(id))).go();
        await (delete(referenceImages)..where((r) => r.poiId.equals(id))).go();
        await (delete(timeChunks)..where((t) => t.poiId.equals(id))).go();
        await (delete(poiAnimes)..where((pa) => pa.poiId.equals(id))).go();
        await (delete(poiTags)..where((pt) => pt.poiId.equals(id))).go();
        return (delete(pois)..where((p) => p.id.equals(id))).go();
      }
    });
  }

  // --- Anime Queries ---
  Future<List<Anime>> getAllAnimes() => select(animes).get();

  Stream<List<Anime>> watchAllAnimes() =>
      (select(animes)..orderBy([(a) => OrderingTerm.asc(a.name)])).watch();

  Future<Anime?> getAnimeById(String id) =>
      (select(animes)..where((a) => a.id.equals(id))).getSingleOrNull();

  Stream<Anime?> watchAnimeById(String id) =>
      (select(animes)..where((a) => a.id.equals(id))).watchSingleOrNull();

  Future<Anime?> getAnimeByBangumiId(String bangumiId) =>
      (select(animes)..where((a) => a.bangumiId.equals(bangumiId)))
          .getSingleOrNull();

  Future<int> insertAnime(AnimesCompanion anime) =>
      into(animes).insert(anime);

  Future<bool> updateAnime(AnimesCompanion anime) async {
    final current = await getAnimeById(anime.id.value);
    if (current == null) return false;
    return update(animes).replace(
      Anime(
        id: anime.id.value,
        name: anime.name.present ? anime.name.value : current.name,
        description: anime.description.present
            ? anime.description.value
            : current.description,
        bangumiId: anime.bangumiId.present
            ? anime.bangumiId.value
            : current.bangumiId,
        createdAt:
            anime.createdAt.present ? anime.createdAt.value : current.createdAt,
        // ADDED: Preserve existing authorId and isShared during update if not provided
        authorId: anime.authorId.present ? anime.authorId.value : current.authorId,
        isShared: anime.isShared.present ? anime.isShared.value : current.isShared,
      ),
    );
  }

  Future<int> deleteAnime(String id) =>
      (delete(animes)..where((a) => a.id.equals(id))).go();

  /// Insert anime if bangumiId not present; otherwise return existing.
  /// Returns the anime id (existing or newly created).
  Future<String> upsertAnimeByBangumiId({
    required String bangumiId,
    required String name,
    required String authorId,
    String? description,
  }) async {
    final existing = await getAnimeByBangumiId(bangumiId);
    if (existing != null) return existing.id;
    final id = const Uuid().v4();
    await insertAnime(AnimesCompanion.insert(
      id: id,
      name: name,
      description: Value(description),
      bangumiId: Value(bangumiId),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      // ADDED: Required by the updated schema for new insertions
      authorId: authorId,
    ));
    return id;
  }

  // --- Tag Queries ---
  Future<List<Tag>> getAllTags() => select(tags).get();

  Stream<List<Tag>> watchAllTags() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<Tag?> getTagById(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Tag?> watchTagById(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> insertTag(TagsCompanion tag) => into(tags).insert(tag);

  Future<bool> updateTag(TagsCompanion tag) async {
    final current = await getTagById(tag.id.value);
    if (current == null) return false;
    return update(tags).replace(
      Tag(
        id: tag.id.value,
        name: tag.name.present ? tag.name.value : current.name,
        description: tag.description.present
            ? tag.description.value
            : current.description,
        createdAt:
            tag.createdAt.present ? tag.createdAt.value : current.createdAt,
        // ADDED: Preserve existing authorId and isShared during update if not provided
        authorId: tag.authorId.present ? tag.authorId.value : current.authorId,
        isShared: tag.isShared.present ? tag.isShared.value : current.isShared,
      ),
    );
  }

  Future<int> deleteTag(String id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  // --- POI ↔ Anime junction ---
  Future<void> addAnimeToPoi(String poiId, String animeId) =>
      into(poiAnimes).insert(
        PoiAnimesCompanion.insert(poiId: poiId, animeId: animeId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<int> removeAnimeFromPoi(String poiId, String animeId) =>
      (delete(poiAnimes)
            ..where((pa) =>
                pa.poiId.equals(poiId) & pa.animeId.equals(animeId)))
          .go();

  Future<void> setAnimesForPoi(String poiId, List<String> animeIds) async {
    await transaction(() async {
      await (delete(poiAnimes)..where((pa) => pa.poiId.equals(poiId))).go();
      for (final animeId in animeIds) {
        await into(poiAnimes).insert(
          PoiAnimesCompanion.insert(poiId: poiId, animeId: animeId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Stream<List<Anime>> watchAnimesForPoi(String poiId) {
    final query = select(animes).join([
      innerJoin(poiAnimes, poiAnimes.animeId.equalsExp(animes.id)),
    ])
      ..where(poiAnimes.poiId.equals(poiId))
      ..orderBy([OrderingTerm.asc(animes.name)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(animes)).toList(),
        );
  }

  Stream<List<Poi>> watchPoisByAnime(String animeId) {
    final query = select(pois).join([
      innerJoin(poiAnimes, poiAnimes.poiId.equalsExp(pois.id)),
    ])
      ..where(poiAnimes.animeId.equals(animeId) & pois.isDeleted.equals(false))
      ..orderBy([OrderingTerm.asc(pois.name)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(pois)).toList(),
        );
  }

  Stream<int> watchPoiCountForAnime(String animeId) {
    final count = poiAnimes.poiId.count();
    final query = selectOnly(poiAnimes)
      ..addColumns([count])
      ..where(poiAnimes.animeId.equals(animeId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // --- POI ↔ Tag junction ---
  Future<void> addTagToPoi(String poiId, String tagId) =>
      into(poiTags).insert(
        PoiTagsCompanion.insert(poiId: poiId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<int> removeTagFromPoi(String poiId, String tagId) =>
      (delete(poiTags)
            ..where((pt) => pt.poiId.equals(poiId) & pt.tagId.equals(tagId)))
          .go();

  Future<void> setTagsForPoi(String poiId, List<String> tagIds) async {
    await transaction(() async {
      await (delete(poiTags)..where((pt) => pt.poiId.equals(poiId))).go();
      for (final tagId in tagIds) {
        await into(poiTags).insert(
          PoiTagsCompanion.insert(poiId: poiId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Stream<List<Tag>> watchTagsForPoi(String poiId) {
    final query = select(tags).join([
      innerJoin(poiTags, poiTags.tagId.equalsExp(tags.id)),
    ])
      ..where(poiTags.poiId.equals(poiId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(tags)).toList(),
        );
  }

  Stream<List<Poi>> watchPoisByTag(String tagId) {
    final query = select(pois).join([
      innerJoin(poiTags, poiTags.poiId.equalsExp(pois.id)),
    ])
      ..where(poiTags.tagId.equals(tagId) & pois.isDeleted.equals(false))
      ..orderBy([OrderingTerm.asc(pois.name)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(pois)).toList(),
        );
  }

  Stream<int> watchPoiCountForTag(String tagId) {
    final count = poiTags.poiId.count();
    final query = selectOnly(poiTags)
      ..addColumns([count])
      ..where(poiTags.tagId.equals(tagId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // --- TimeChunk Queries ---
  Future<void> batchUpdateTimeChunks(List<TimeChunksCompanion> chunks) async {
    await batch((batch) {
      batch.replaceAll(timeChunks, chunks);
    });
  }
  
  Future<List<TimeChunk>> getTimeChunksByPoi(String poiId) =>
      (select(timeChunks)..where((t) => t.poiId.equals(poiId))).get();

  Stream<List<TimeChunk>> watchTimeChunksByDate(String date) =>
      (select(timeChunks)..where((t) => t.date.equals(date))).watch();

  Stream<List<TimeChunk>> watchBacklogChunks() => (select(timeChunks)
        ..where((t) => t.status.equals('backlog')))
      .watch();

  Future<int> insertTimeChunk(TimeChunksCompanion chunk) =>
      into(timeChunks).insert(chunk);

  Future<bool> updateTimeChunk(TimeChunksCompanion chunk) =>
      // CRITICAL FIX: Pass the companion directly to Drift.
      // Never manually unpack .value properties. Drift handles absent values automatically.
      update(timeChunks).replace(chunk);

  Stream<List<TimeChunk>> watchAllScheduledChunks() => (select(timeChunks)
        ..where((t) => t.status.equals('scheduled'))
        ..orderBy([(t) => OrderingTerm.asc(t.date)]))
      .watch();

  Future<void> executeLocalDelete(String chunkId) async {
    await transaction(() async {
      final node = await (select(timeChunks)..where((t) => t.id.equals(chunkId))).getSingleOrNull();
      if (node == null) return;

      if (node.hasEverSynced) {
        await (update(timeChunks)..where((t) => t.id.equals(chunkId))).write(
          TimeChunksCompanion(
            isDeleted: const Value(true),
            syncStatus: Value(SyncStatus.dirty.index), 
            lastModifiedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await (delete(timeChunks)..where((t) => t.id.equals(chunkId))).go();
      }
    });
  }

  // --- MediaAsset Queries ---
  Future<List<MediaAsset>> getMediaAssetsByPoi(String poiId) =>
      (select(mediaAssets)..where((m) => m.poiId.equals(poiId))).get();

  Stream<List<MediaAsset>> watchMediaAssetsByPoi(String poiId) =>
      (select(mediaAssets)..where((m) => m.poiId.equals(poiId))).watch();

  Future<int> insertMediaAsset(MediaAssetsCompanion asset) =>
      into(mediaAssets).insert(asset);

  Future<int> updateMediaAssetLocalPath(String id, String? localPath) =>
      (update(mediaAssets)..where((m) => m.id.equals(id))).write(
        MediaAssetsCompanion(localPath: Value(localPath)),
      );

  Future<int> deleteMediaAsset(String id) =>
      (delete(mediaAssets)..where((m) => m.id.equals(id))).go();

  // --- ReferenceImage Queries ---
  Future<List<ReferenceImage>> getReferenceImagesByPoi(String poiId) =>
      (select(referenceImages)..where((r) => r.poiId.equals(poiId))).get();

  Stream<List<ReferenceImage>> watchReferenceImagesByPoi(String poiId) =>
      (select(referenceImages)..where((r) => r.poiId.equals(poiId))).watch();

  Future<int> insertReferenceImage(ReferenceImagesCompanion image) =>
      into(referenceImages).insert(image);

  Future<int> updateReferenceImageLocalPath(String id, String? localPath) =>
      (update(referenceImages)..where((r) => r.id.equals(id))).write(
        ReferenceImagesCompanion(localPath: Value(localPath)),
      );

  Future<int> deleteReferenceImage(String id) =>
      (delete(referenceImages)..where((r) => r.id.equals(id))).go();

  /// Watches all POIs that have not been synced to the cloud yet
  Stream<List<Poi>> watchUnsyncedPois() {
    return (select(pois)..where((tbl) => tbl.isShared.equals(false))).watch();
  }

  /// Marks a specific POI as successfully synced to the cloud
  Future<void> markPoiAsShared(String id) async {
    await (update(pois)..where((tbl) => tbl.id.equals(id))).write(
      const PoisCompanion(
        isShared: Value(true),
      ),
    );
  }
}
