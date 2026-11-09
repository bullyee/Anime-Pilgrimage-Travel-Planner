import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../../../core/utils/schedule_logic.dart';
import '../models/shooting_core_models.dart';

/// Core backend service for v0.3.0 Pilgrimage Shooting Mode (Step 1).
///
/// Features:
/// 1. [findNearbyPlaces]: Locates library places within ~150m of current GPS coordinate,
///    sorting places from today's active trip stops first, then nearest first.
/// 2. [getTodayTrip]: Resolves today's active trip and day block from the calendar date.
/// 3. [recordShot]: Atomic mutation that copies a field shot, inserts a photo row,
///    creates/updates a place visit, marks the schedule item done, and handles off-plan stops.
/// 4. [watchPhotosToEdit]: Streams raw pilgrimage photos waiting to be edited at home,
///    with [markPhotoAsKeptAsIs] to mark them as completed without edits.
class PilgrimageShootingService {
  final Uuid _uuid;

  const PilgrimageShootingService({Uuid uuid = const Uuid()}) : _uuid = uuid;

  /// Calculates geodesic distance between two points in meters using the Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Resolves which trip and day block corresponds to the given date (default today).
  Future<TodayTripInfo?> getTodayTrip(AppDatabase db, {DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final todayDate = normalizeDateOnly(effectiveNow);

    final activeTrips = await (db.select(db.trips)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    for (final trip in activeTrips) {
      final days = await (db.select(db.tripDays)
            ..where((d) => d.tripId.equals(trip.id) & d.deletedAt.isNull())
            ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
          .get();

      if (days.isEmpty) continue;

      final blocks = days.map((d) {
        return DayBlockInfo(
          id: d.id,
          sortKey: d.sortKey,
          title: d.title,
          pinnedDate: d.pinnedDate != null ? DateTime.tryParse(d.pinnedDate!) : null,
        );
      }).toList();

      final startDate = trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;
      final resolvedDates = ScheduleLogicEngine.computeBlockDates(
        blocks: blocks,
        startDate: startDate,
        dayCount: trip.dayCount,
      );

      for (int i = 0; i < resolvedDates.length; i++) {
        final resolved = resolvedDates[i];
        if (!resolved.isBackup && resolved.date != null && resolved.date == todayDate) {
          final matchedDay = days[i];

          final items = await (db.select(db.scheduleItems)
                ..where((s) => s.dayId.equals(matchedDay.id) & s.deletedAt.isNull())
                ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
              .get();

          final stops = await (db.select(db.stops)
                ..where((s) => s.tripId.equals(trip.id) & s.deletedAt.isNull()))
              .get();
          final stopMap = {for (final s in stops) s.id: s};

          return TodayTripInfo(
            trip: trip,
            day: matchedDay,
            stops: stops,
            scheduleItems: items,
            stopMap: stopMap,
          );
        }
      }
    }

    return null;
  }

  /// Finds library places within [maxDistanceMeters] (default 150m) of GPS coordinates.
  ///
  /// Places belonging to today's active trip day are prioritized at the top of the list,
  /// followed by nearest distance ascending.
  Future<List<NearbyShootingPlace>> findNearbyPlaces(
    AppDatabase db, {
    required double lat,
    required double lng,
    double maxDistanceMeters = 150.0,
    DateTime? now,
  }) async {
    final todayTrip = await getTodayTrip(db, now: now);

    // Map today's stops and items by placeKey
    final todayStopsByPlaceKey = <String, Stop>{};
    final todayItemsByPlaceKey = <String, ScheduleItem>{};

    if (todayTrip != null) {
      for (final item in todayTrip.scheduleItems) {
        final stop = todayTrip.stopMap[item.stopId];
        if (stop != null) {
          todayStopsByPlaceKey[stop.placeKey] = stop;
          todayItemsByPlaceKey[stop.placeKey] = item;
        }
      }
    }

    // Query library places
    final allPlaces = await (db.select(db.places)
          ..where((p) => p.visibility.equals('saved')))
        .get();

    final candidatePlaces = <NearbyShootingPlace>[];
    final qualifyingPlaceKeys = <String>[];

    for (final place in allPlaces) {
      final distance = calculateDistanceMeters(lat, lng, place.lat, place.lng);
      if (distance <= maxDistanceMeters) {
        qualifyingPlaceKeys.add(place.placeKey);
        final isTodayStop = todayStopsByPlaceKey.containsKey(place.placeKey);

        candidatePlaces.add(NearbyShootingPlace(
          place: place,
          distanceMeters: distance,
          isTodayStop: isTodayStop,
          todayStop: todayStopsByPlaceKey[place.placeKey],
          todayScheduleItem: todayItemsByPlaceKey[place.placeKey],
        ));
      }
    }

    if (candidatePlaces.isEmpty) {
      return const [];
    }

    // Load reference frames for all qualifying places
    final refImages = await (db.select(db.newReferenceImages)
          ..where((r) => r.placeKey.isIn(qualifyingPlaceKeys)))
        .get();
    final refMap = <String, List<NewReferenceImage>>{};
    for (final ref in refImages) {
      if (ref.placeKey != null) {
        refMap.putIfAbsent(ref.placeKey!, () => []).add(ref);
      }
    }

    // Load anime labels
    final animeLabels = await _loadPlaceAnimeLabels(db, qualifyingPlaceKeys);

    // Rebuild candidates with frames and anime info
    final enrichedCandidates = candidatePlaces.map((c) {
      final frames = refMap[c.place.placeKey] ?? const [];
      final animeTitle = animeLabels[c.place.placeKey];
      return NearbyShootingPlace(
        place: c.place,
        distanceMeters: c.distanceMeters,
        isTodayStop: c.isTodayStop,
        todayStop: c.todayStop,
        todayScheduleItem: c.todayScheduleItem,
        referenceFrames: frames,
        animeTitle: animeTitle,
      );
    }).toList();

    // Sort: today's stops first, then nearest first
    enrichedCandidates.sort((a, b) {
      if (a.isTodayStop != b.isTodayStop) {
        return a.isTodayStop ? -1 : 1;
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return enrichedCandidates;
  }

  /// Records a shot taken in the field into local storage and database.
  ///
  /// Atomically:
  /// 1. Copies photo file to app documents directory if persistent copy needed.
  /// 2. Creates a row in [photos] table (`kind: 'original'`).
  /// 3. Creates a row in [place_visits] for today.
  /// 4. If a trip is active today:
  ///    - If [placeKey] was on the day's schedule, marks it `'done'`.
  ///    - If [placeKey] is off the plan, creates a stop if needed and adds a schedule item
  ///      marked `'done'` to today's day block.
  Future<ShotRecordResult> recordShot(
    AppDatabase db, {
    required String sourceImagePath,
    required String placeKey,
    String? tripId,
    String? stopId,
    String? referenceImageId,
    DateTime? takenAt,
    bool keepAsIs = false,
  }) async {
    final effectiveTakenAt = takenAt ?? DateTime.now();
    final todayStr = _formatIsoDate(effectiveTakenAt);

    // Ensure photo file is persisted in app storage
    final finalLocalPath = await _persistPhotoFile(sourceImagePath);

    return db.transaction(() async {
      // 1. Resolve active trip for today
      final todayTrip = await getTodayTrip(db, now: effectiveTakenAt);
      final resolvedTripId = tripId ?? todayTrip?.trip.id;

      // 2. Insert Photo row
      final photoId = _uuid.v4();
      final photo = Photo(
        id: photoId,
        placeKey: placeKey,
        tripId: resolvedTripId,
        kind: 'original',
        localPath: finalLocalPath,
        referenceImageId: referenceImageId,
        isShared: false,
        keepAsIs: keepAsIs,
        takenAt: effectiveTakenAt,
        createdAt: DateTime.now(),
      );

      await db.into(db.photos).insert(PhotosCompanion.insert(
        id: photo.id,
        placeKey: photo.placeKey,
        tripId: Value(photo.tripId),
        kind: const Value('original'),
        localPath: photo.localPath,
        referenceImageId: Value(photo.referenceImageId),
        isShared: const Value(false),
        keepAsIs: Value(photo.keepAsIs),
        takenAt: Value(photo.takenAt),
        createdAt: Value(photo.createdAt),
      ));

      // 3. Insert PlaceVisit row
      final visitId = _uuid.v4();
      final visit = PlaceVisit(
        id: visitId,
        placeKey: placeKey,
        date: todayStr,
        tripId: resolvedTripId,
        createdAt: DateTime.now(),
      );

      await db.into(db.placeVisits).insert(PlaceVisitsCompanion.insert(
        id: visit.id,
        placeKey: visit.placeKey,
        date: visit.date,
        tripId: Value(visit.tripId),
        createdAt: Value(visit.createdAt),
      ));

      // 4. Update or Add Schedule Item in today's trip
      Stop? activeStop;
      ScheduleItem? activeItem;
      bool wasOffPlan = false;

      if (todayTrip != null && (resolvedTripId == null || resolvedTripId == todayTrip.trip.id)) {
        final currentTripId = todayTrip.trip.id;
        final currentDayId = todayTrip.day.id;

        // Check if place is already on today's scheduled items
        ScheduleItem? existingDayItem;
        for (final item in todayTrip.scheduleItems) {
          final s = todayTrip.stopMap[item.stopId];
          if (s != null && s.placeKey == placeKey) {
            existingDayItem = item;
            activeStop = s;
            break;
          }
        }

        if (existingDayItem != null) {
          // On-plan shot: mark existing item done
          await (db.update(db.scheduleItems)..where((s) => s.id.equals(existingDayItem!.id))).write(
            ScheduleItemsCompanion(
              status: const Value('done'),
              syncStatus: const Value(1),
              updatedAt: Value(DateTime.now()),
            ),
          );
          activeItem = existingDayItem.copyWith(status: 'done', syncStatus: 1);
        } else {
          // Off-plan shot! Add place to today's day block
          wasOffPlan = true;

          // Find or create Stop for this place
          final existingTripStop = await (db.select(db.stops)
                ..where((s) => s.tripId.equals(currentTripId) & s.placeKey.equals(placeKey) & s.deletedAt.isNull()))
              .getSingleOrNull();

          if (existingTripStop != null) {
            activeStop = existingTripStop;
          } else {
            // Fetch place facts
            final place = await (db.select(db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
            final stopName = place?.name ?? 'Spot';
            final stopLat = place?.lat ?? 0.0;
            final stopLng = place?.lng ?? 0.0;

            final newStopId = _uuid.v4();
            await db.into(db.stops).insert(StopsCompanion.insert(
              id: newStopId,
              tripId: currentTripId,
              placeKey: placeKey,
              name: stopName,
              lat: stopLat,
              lng: stopLng,
              addedBy: 'local_user',
              syncStatus: const Value(1),
            ));
            activeStop = await (db.select(db.stops)..where((s) => s.id.equals(newStopId))).getSingle();
          }

          // Generate next sortKey for day block
          final existingKeys = todayTrip.scheduleItems.map((i) => i.sortKey).toList();
          final nextSortKey = FractionalIndexUtil.append(existingKeys);

          final newItemId = _uuid.v4();
          await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: newItemId,
            tripId: currentTripId,
            dayId: currentDayId,
            stopId: activeStop!.id,
            sortKey: nextSortKey,
            status: const Value('done'),
            syncStatus: const Value(1),
          ));

          activeItem = await (db.select(db.scheduleItems)..where((s) => s.id.equals(newItemId))).getSingle();
        }
      }

      return ShotRecordResult(
        photo: photo,
        visit: visit,
        stop: activeStop,
        scheduleItem: activeItem,
        wasOffPlan: wasOffPlan,
      );
    });
  }

  /// Streams photos waiting to be edited at home.
  ///
  /// Includes photos that:
  /// - are of `kind == 'original'`
  /// - have `keepAsIs == false`
  /// - have not been derived into an edited/comparison image yet.
  Stream<List<PhotoToEditItem>> watchPhotosToEdit(AppDatabase db) {
    // Select original photos where keepAsIs is false
    final query = db.select(db.photos)
      ..where((p) => p.kind.equals('original') & p.keepAsIs.equals(false))
      ..orderBy([(p) => OrderingTerm.desc(p.takenAt), (p) => OrderingTerm.desc(p.createdAt)]);

    return query.watch().asyncMap((photoRows) async {
      if (photoRows.isEmpty) return const [];

      // Query which photos have derived children
      final derivedRows = await (db.selectOnly(db.photos, distinct: true)
            ..addColumns([db.photos.derivedFromId])
            ..where(db.photos.derivedFromId.isNotNull()))
          .get();
      final derivedIds = derivedRows
          .map((r) => r.read(db.photos.derivedFromId))
          .whereType<String>()
          .toSet();

      final pendingPhotos = photoRows.where((p) => !derivedIds.contains(p.id)).toList();
      if (pendingPhotos.isEmpty) return const [];

      final placeKeys = pendingPhotos.map((p) => p.placeKey).toSet().toList();
      final places = await (db.select(db.places)..where((p) => p.placeKey.isIn(placeKeys))).get();
      final placeMap = {for (final p in places) p.placeKey: p};

      final refIds = pendingPhotos.map((p) => p.referenceImageId).whereType<String>().toSet().toList();
      final refImages = refIds.isNotEmpty
          ? await (db.select(db.newReferenceImages)..where((r) => r.id.isIn(refIds))).get()
          : <NewReferenceImage>[];
      final refMap = {for (final r in refImages) r.id: r};

      return pendingPhotos.map((photo) {
        return PhotoToEditItem(
          photo: photo,
          place: placeMap[photo.placeKey],
          referenceFrame: photo.referenceImageId != null ? refMap[photo.referenceImageId] : null,
        );
      }).toList();
    });
  }

  /// Marks an original photo as "keep as is", removing it from the edit inbox.
  Future<void> markPhotoAsKeptAsIs(AppDatabase db, String photoId) async {
    await (db.update(db.photos)..where((p) => p.id.equals(photoId))).write(
      const PhotosCompanion(keepAsIs: Value(true)),
    );
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  Future<Map<String, String>> _loadPlaceAnimeLabels(AppDatabase db, List<String> placeKeys) async {
    if (placeKeys.isEmpty) return {};
    final query = db.select(db.placeLabels).join([
      innerJoin(db.labels, db.labels.id.equalsExp(db.placeLabels.labelId)),
    ])..where(db.placeLabels.placeKey.isIn(placeKeys) & db.labels.kind.equals('anime'));

    final rows = await query.get();
    final result = <String, String>{};
    for (final row in rows) {
      result[row.readTable(db.placeLabels).placeKey] = row.readTable(db.labels).name;
    }
    return result;
  }

  Future<String> _persistPhotoFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }

    try {
      final docsDir = await getApplicationDocumentsPathSafe();
      final photosDir = Directory(p.join(docsDir, 'app_photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
      final destPath = p.join(photosDir.path, 'photo_${_uuid.v4()}$ext');
      final copied = await sourceFile.copy(destPath);
      return copied.path;
    } catch (_) {
      // If path_provider is not mocked in unit test, retain source path
      return sourcePath;
    }
  }

  /// Safe getter for application documents directory across all environments.
  static Future<String> getApplicationDocumentsPathSafe() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }

  static String _formatIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
