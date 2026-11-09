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
/// 1. [findNearbyPlaces]: Locates places within ~150m of current GPS coordinate,
///    sorting target day trip stops first, other trip stops second, and library places third.
/// 2. [getTodayTrip]: Resolves today's active trip and day block from the calendar date.
/// 3. [recordShot]: Atomic mutation that persists photo file, inserts photo row,
///    creates/updates a place visit, and links to trip stops without mutating the plan.
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

  /// Calculates the initial forward bearing angle from point 1 to point 2 in degrees (0.0 to 359.9).
  static double calculateBearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    if ((lat1 - lat2).abs() < 1e-9 && (lng1 - lng2).abs() < 1e-9) {
      return 0.0;
    }
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaLambda = (lng2 - lng1) * math.pi / 180.0;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Converts a bearing degree into 8-point cardinal abbreviation and localized Chinese name.
  static (String cardinal, String cardinalZh) getCardinalDirection(double bearingDegrees) {
    final normalized = (bearingDegrees % 360.0 + 360.0) % 360.0;
    const directions = [
      ('N', '北'),
      ('NE', '東北'),
      ('E', '東'),
      ('SE', '東南'),
      ('S', '南'),
      ('SW', '西南'),
      ('W', '西'),
      ('NW', '西北'),
    ];
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return directions[index];
  }

  /// Calculates the relative clock position (1 to 12) from current device heading.
  ///
  /// For example, 12 o'clock means straight ahead, 3 o'clock means right, 6 o'clock means behind.
  static int calculateClockHour(double bearingDegrees, double deviceHeadingDegrees) {
    final normBearing = (bearingDegrees % 360.0 + 360.0) % 360.0;
    final normHeading = (deviceHeadingDegrees % 360.0 + 360.0) % 360.0;
    final relativeAngle = (normBearing - normHeading + 360.0) % 360.0;
    final hour = (((relativeAngle + 15.0) % 360.0) ~/ 30.0);
    return hour == 0 ? 12 : hour;
  }

  /// Calculates complete orientation and directional guidance toward a spot.
  static SpotBearingInfo calculateBearingInfo({
    required double userLat,
    required double userLng,
    required double spotLat,
    required double spotLng,
    double? deviceHeading,
    double arrivalThresholdMeters = 15.0,
  }) {
    final distance = calculateDistanceMeters(userLat, userLng, spotLat, spotLng);
    final bearing = calculateBearingDegrees(userLat, userLng, spotLat, spotLng);
    final (cardinal, cardinalZh) = getCardinalDirection(bearing);

    int? clockHour;
    double? relativeAngle;
    if (deviceHeading != null) {
      final normHeading = (deviceHeading % 360.0 + 360.0) % 360.0;
      relativeAngle = (bearing - normHeading + 360.0) % 360.0;
      clockHour = calculateClockHour(bearing, normHeading);
    }

    return SpotBearingInfo(
      distanceMeters: distance,
      bearingDegrees: bearing,
      cardinal: cardinal,
      cardinalZh: cardinalZh,
      clockHour: clockHour,
      relativeAngleDegrees: relativeAngle,
      isArrived: distance <= arrivalThresholdMeters,
    );
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
          final matchedDay = days.firstWhere((d) => d.id == resolved.block.id);

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

  /// Finds candidate pilgrimage places nearby the given GPS coordinates within [maxDistanceMeters] (default 150m).
  ///
  /// On a trip day, returns:
  /// 1. Stops on the target day within range (first, ordered by distance ascending).
  /// 2. Other stops in the trip within range, tagged with their scheduled day (second, ordered by distance ascending).
  /// 3. Remaining saved library places within range (third, ordered by distance ascending).
  ///
  /// When no trip is active, returns library places within range.
  Future<List<NearbyShootingPlace>> findNearbyPlaces(
    AppDatabase db, {
    required double lat,
    required double lng,
    String? tripId,
    String? dayId,
    double? deviceHeading,
    double maxDistanceMeters = 150.0,
    DateTime? now,
  }) async {
    // 1. Resolve active trip and target day
    final todayTrip = await getTodayTrip(db, now: now);
    String? resolvedTripId = tripId;
    if (resolvedTripId == null && dayId != null) {
      final dayRow = await (db.select(db.tripDays)
            ..where((d) => d.id.equals(dayId) & d.deletedAt.isNull()))
          .getSingleOrNull();
      resolvedTripId = dayRow?.tripId;
    }
    resolvedTripId ??= todayTrip?.trip.id;
    final targetDayId = dayId ?? (resolvedTripId == todayTrip?.trip.id ? todayTrip?.day.id : null);

    final candidateStops = <({Stop stop, ScheduleItem? item, String? dayId, int? dayNumber, bool isTargetDay, double distanceMeters})>[];
    final qualifyingPlaceKeys = <String>{};
    final qualifyingStopIds = <String>{};
    final seenStopIds = <String>{};
    final seenPlaceKeys = <String>{};

    if (resolvedTripId != null) {
      // Load all non-deleted stops in the trip
      final allTripStops = await (db.select(db.stops)
            ..where((s) => s.tripId.equals(resolvedTripId!) & s.deletedAt.isNull()))
          .get();

      // Load trip for startDate and dayCount
      final trip = await (db.select(db.trips)
            ..where((t) => t.id.equals(resolvedTripId!) & t.deletedAt.isNull()))
          .getSingleOrNull();

      // Load days excluding deleted ones
      final days = await (db.select(db.tripDays)
            ..where((d) => d.tripId.equals(resolvedTripId!) & d.deletedAt.isNull())
            ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
          .get();

      final dayNumberMap = <String, int>{};
      if (trip != null && days.isNotEmpty) {
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

        int nonBackupCounter = 1;
        for (int i = 0; i < resolvedDates.length; i++) {
          final res = resolvedDates[i];
          if (!res.isBackup) {
            dayNumberMap[res.block.id] = nonBackupCounter++;
          }
        }
      }

      // Load non-deleted schedule items for this trip
      final items = await (db.select(db.scheduleItems)
            ..where((s) => s.tripId.equals(resolvedTripId!) & s.deletedAt.isNull()))
          .get();
      // A stop can be on several days: prefer its item on the target day,
      // else the one on the earliest numbered day.
      final itemsByStopId = <String, List<ScheduleItem>>{};
      for (final it in items) {
        itemsByStopId.putIfAbsent(it.stopId, () => []).add(it);
      }
      ScheduleItem? itemFor(String stopId) {
        final stopItems = itemsByStopId[stopId];
        if (stopItems == null || stopItems.isEmpty) return null;
        final onTarget = stopItems.where((it) => targetDayId != null && it.dayId == targetDayId).firstOrNull;
        if (onTarget != null) return onTarget;
        return (List.of(stopItems)
              ..sort((a, b) => (dayNumberMap[a.dayId] ?? 1 << 30).compareTo(dayNumberMap[b.dayId] ?? 1 << 30)))
            .first;
      }

      for (final stop in allTripStops) {
        if (seenStopIds.contains(stop.id)) continue;

        final dist = calculateDistanceMeters(lat, lng, stop.lat, stop.lng);
        if (dist <= maxDistanceMeters) {
          seenStopIds.add(stop.id);
          final schedItem = itemFor(stop.id);
          final stopDayId = schedItem?.dayId;
          final dayNum = stopDayId != null ? dayNumberMap[stopDayId] : null;
          final isTargetDay = targetDayId != null && stopDayId == targetDayId;

          candidateStops.add((
            stop: stop,
            item: schedItem,
            dayId: stopDayId,
            dayNumber: dayNum,
            isTargetDay: isTargetDay,
            distanceMeters: dist,
          ));
          qualifyingStopIds.add(stop.id);
          if (stop.placeKey.isNotEmpty) {
            qualifyingPlaceKeys.add(stop.placeKey);
            seenPlaceKeys.add(stop.placeKey);
          }
        }
      }
    }

    // Query library places (saved visibility only)
    final savedPlaces = await (db.select(db.places)
          ..where((p) => p.visibility.equals('saved')))
        .get();

    final candidatePlaces = <({Place place, double distanceMeters})>[];
    for (final place in savedPlaces) {
      if (seenPlaceKeys.contains(place.placeKey)) continue;

      final dist = calculateDistanceMeters(lat, lng, place.lat, place.lng);
      if (dist <= maxDistanceMeters) {
        candidatePlaces.add((
          place: place,
          distanceMeters: dist,
        ));
        qualifyingPlaceKeys.add(place.placeKey);
      }
    }

    if (candidateStops.isEmpty && candidatePlaces.isEmpty) {
      return const [];
    }

    // Load places for stops if they exist in the places table
    final stopPlaceKeys = candidateStops
        .map((c) => c.stop.placeKey)
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    final placesForStops = stopPlaceKeys.isNotEmpty
        ? await (db.select(db.places)..where((p) => p.placeKey.isIn(stopPlaceKeys))).get()
        : <Place>[];
    final placeMapForStops = {for (final p in placesForStops) p.placeKey: p};

    // Load reference frames by placeKey or stopId
    final refImages = await (db.select(db.newReferenceImages)
          ..where((r) {
            final hasPlaceKeys = qualifyingPlaceKeys.isNotEmpty;
            final hasStopIds = qualifyingStopIds.isNotEmpty;
            if (hasPlaceKeys && hasStopIds) {
              return (r.placeKey.isNotNull() & r.placeKey.isIn(qualifyingPlaceKeys)) |
                     (r.stopId.isNotNull() & r.stopId.isIn(qualifyingStopIds));
            } else if (hasPlaceKeys) {
              return r.placeKey.isNotNull() & r.placeKey.isIn(qualifyingPlaceKeys);
            } else if (hasStopIds) {
              return r.stopId.isNotNull() & r.stopId.isIn(qualifyingStopIds);
            }
            return const Constant(false);
          }))
        .get();

    final refMapByPlaceKey = <String, List<NewReferenceImage>>{};
    final refMapByStopId = <String, List<NewReferenceImage>>{};
    for (final ref in refImages) {
      if (ref.placeKey != null && ref.placeKey!.isNotEmpty) {
        refMapByPlaceKey.putIfAbsent(ref.placeKey!, () => []).add(ref);
      }
      if (ref.stopId != null && ref.stopId!.isNotEmpty) {
        refMapByStopId.putIfAbsent(ref.stopId!, () => []).add(ref);
      }
    }

    // Load anime labels for all place keys
    final animeLabels = await _loadPlaceAnimeLabels(db, qualifyingPlaceKeys.toList());

    final results = <NearbyShootingPlace>[];

    // Build stop candidates
    for (final candidate in candidateStops) {
      final stop = candidate.stop;
      final place = placeMapForStops[stop.placeKey];
      final framesByStop = refMapByStopId[stop.id] ?? const [];
      final framesByPlace = (stop.placeKey.isNotEmpty ? refMapByPlaceKey[stop.placeKey] : null) ?? const [];

      // Combine frames, avoiding duplicates by id
      final frameMap = <String, NewReferenceImage>{};
      for (final f in framesByStop) {
        frameMap[f.id] = f;
      }
      for (final f in framesByPlace) {
        frameMap.putIfAbsent(f.id, () => f);
      }

      final animeTitle = stop.placeKey.isNotEmpty ? animeLabels[stop.placeKey] : null;
      final bearing = deviceHeading != null
          ? calculateBearingInfo(
              userLat: lat,
              userLng: lng,
              spotLat: stop.lat,
              spotLng: stop.lng,
              deviceHeading: deviceHeading,
            )
          : null;

      results.add(NearbyShootingPlace(
        place: place,
        name: stop.name,
        lat: stop.lat,
        lng: stop.lng,
        placeKey: stop.placeKey,
        distanceMeters: candidate.distanceMeters,
        isTargetDayStop: candidate.isTargetDay,
        todayStop: stop,
        todayScheduleItem: candidate.item,
        dayId: candidate.dayId,
        dayNumber: candidate.dayNumber,
        referenceFrames: frameMap.values.toList(),
        animeTitle: animeTitle,
        bearingInfo: bearing,
      ));
    }

    // Build library place candidates
    for (final candidate in candidatePlaces) {
      final place = candidate.place;
      final frames = refMapByPlaceKey[place.placeKey] ?? const [];
      final animeTitle = animeLabels[place.placeKey];
      final bearing = deviceHeading != null
          ? calculateBearingInfo(
              userLat: lat,
              userLng: lng,
              spotLat: place.lat,
              spotLng: place.lng,
              deviceHeading: deviceHeading,
            )
          : null;

      results.add(NearbyShootingPlace(
        place: place,
        name: place.name,
        lat: place.lat,
        lng: place.lng,
        placeKey: place.placeKey,
        distanceMeters: candidate.distanceMeters,
        isTargetDayStop: false,
        referenceFrames: frames,
        animeTitle: animeTitle,
        bearingInfo: bearing,
      ));
    }

    // Sort:
    // 1. Target day stops first, nearest first
    // 2. Other trip stops second, nearest first
    // 3. Saved library places third, nearest first
    results.sort((a, b) {
      final aPriority = a.isTargetDayStop ? 0 : (a.todayStop != null ? 1 : 2);
      final bPriority = b.isTargetDayStop ? 0 : (b.todayStop != null ? 1 : 2);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return results;
  }

  /// Records a shot taken in the field into local storage and database.
  ///
  /// Atomically:
  /// 1. Copies photo file to app documents directory if persistent copy needed.
  /// 2. Ensures place row exists in [places] (creating a `trip_only` stub if missing to satisfy FKs).
  /// 3. Creates a row in [photos] table (`kind: 'original'`).
  /// 4. Creates or reuses a row in [place_visits] for today (one visit per place per day).
  /// 5. Associates photo with trip and resolves active stop/item without mutating the plan.
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

    try {
      return await db.transaction(() async {
        // 1. Resolve active trip
        final todayTrip = await getTodayTrip(db, now: effectiveTakenAt);
        final resolvedTripId = tripId ?? todayTrip?.trip.id;

        // 1.5 Ensure place row exists in places table to satisfy foreign key constraints
        final existingPlace = await (db.select(db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
        if (existingPlace == null) {
          Stop? matchingStop;
          if (stopId != null) {
            matchingStop = await (db.select(db.stops)
                  ..where((s) => s.id.equals(stopId) & s.deletedAt.isNull()))
                .getSingleOrNull();
          }
          if (matchingStop == null && resolvedTripId != null) {
            matchingStop = (await (db.select(db.stops)
                  ..where((s) =>
                      s.tripId.equals(resolvedTripId) &
                      s.placeKey.equals(placeKey) &
                      s.deletedAt.isNull()))
                .get())
                .firstOrNull;
          }

          if (matchingStop == null) {
            throw ArgumentError('Place not found for placeKey: $placeKey');
          }

          await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: placeKey,
            name: matchingStop.name,
            lat: matchingStop.lat,
            lng: matchingStop.lng,
            address: Value(matchingStop.address),
            visibility: const Value('trip_only'),
          ));
        }

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

        // 3. Insert or reuse PlaceVisit row (one per place per day)
        final existingVisit = (await (db.select(db.placeVisits)
              ..where((v) => v.placeKey.equals(placeKey) & v.date.equals(todayStr))
              ..limit(1))
            .get())
            .firstOrNull;

        final PlaceVisit visit;
        if (existingVisit != null) {
          visit = existingVisit;
        } else {
          final visitId = _uuid.v4();
          visit = PlaceVisit(
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
        }

        // 4. Resolve stop in trip if present (without altering schedule items or creating unwanted stops)
        Stop? activeStop;
        ScheduleItem? activeItem;

        if (resolvedTripId != null) {
          if (stopId != null) {
            activeStop = await (db.select(db.stops)
                  ..where((s) => s.id.equals(stopId) & s.deletedAt.isNull()))
                .getSingleOrNull();
          }
          if (activeStop == null) {
            activeStop = (await (db.select(db.stops)
                  ..where((s) =>
                      s.tripId.equals(resolvedTripId) &
                      s.placeKey.equals(placeKey) &
                      s.deletedAt.isNull()))
                .get())
                .firstOrNull;
          }

          if (activeStop != null) {
            final items = await (db.select(db.scheduleItems)
                  ..where((s) =>
                      s.stopId.equals(activeStop!.id) &
                      s.tripId.equals(resolvedTripId) &
                      s.deletedAt.isNull()))
                .get();
            activeItem = (todayTrip != null
                    ? items.where((i) => i.dayId == todayTrip.day.id).firstOrNull
                    : null) ??
                items.firstOrNull;
          }
        }

        return ShotRecordResult(
          photo: photo,
          visit: visit,
          stop: activeStop,
          scheduleItem: activeItem,
          wasOffPlan: resolvedTripId != null && activeStop == null,
        );
      });
    } catch (e) {
      // Clean up orphaned physical file on transaction failure
      if (finalLocalPath != sourceImagePath) {
        try {
          final f = File(finalLocalPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      rethrow;
    }
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

  /// Records a check-in visit at a pilgrimage place without taking a camera photo.
  ///
  /// - Automatically ensures a place row exists in [places] to satisfy FK constraints.
  /// - Inserts or reuses a [place_visits] row (one per place per day).
  /// - When [markDone] is `true` (default), marks the matching schedule item as `'done'`
  ///   if the stop is part of the itinerary. Viewers can pass [markDone] = `false`
  ///   to record their visit personally without modifying the shared trip itinerary.
  /// - Respects "the plan follows the user": off-plan check-ins log the visit without
  ///   adding unwanted stops or phantom schedule items.
  Future<CheckInResult> checkInWithoutPhoto(
    AppDatabase db, {
    required String placeKey,
    String? stopId,
    String? tripId,
    String? dayId,
    String? scheduleItemId,
    DateTime? visitedAt,
    bool markDone = true,
  }) async {
    final effectiveVisitedAt = visitedAt ?? DateTime.now();
    final todayStr = _formatIsoDate(effectiveVisitedAt);

    return db.transaction(() async {
      // 1. Resolve tripId
      String? resolvedTripId = tripId;
      if (resolvedTripId == null && dayId != null) {
        final dayRow = await (db.select(db.tripDays)
              ..where((d) => d.id.equals(dayId) & d.deletedAt.isNull()))
            .getSingleOrNull();
        resolvedTripId = dayRow?.tripId;
      }
      if (resolvedTripId == null) {
        final todayTrip = await getTodayTrip(db, now: effectiveVisitedAt);
        resolvedTripId = todayTrip?.trip.id;
      }

      // 1.5 Ensure place row exists in places table to satisfy foreign key constraints
      final existingPlace = await (db.select(db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
      if (existingPlace == null) {
        Stop? matchingStop;
        if (stopId != null) {
          matchingStop = await (db.select(db.stops)
                ..where((s) => s.id.equals(stopId) & s.deletedAt.isNull()))
              .getSingleOrNull();
        }
        if (matchingStop == null && resolvedTripId != null) {
          matchingStop = (await (db.select(db.stops)
                ..where((s) =>
                    s.tripId.equals(resolvedTripId!) &
                    s.placeKey.equals(placeKey) &
                    s.deletedAt.isNull()))
              .get())
              .firstOrNull;
        }

        if (matchingStop == null) {
          throw ArgumentError('Place not found for placeKey: $placeKey');
        }

        await db.into(db.places).insert(PlacesCompanion.insert(
          placeKey: placeKey,
          name: matchingStop.name,
          lat: matchingStop.lat,
          lng: matchingStop.lng,
          address: Value(matchingStop.address),
          visibility: const Value('trip_only'),
        ));
      }

      // 2. Insert or reuse PlaceVisit row (one per place per day)
      final existingVisit = (await (db.select(db.placeVisits)
            ..where((v) => v.placeKey.equals(placeKey) & v.date.equals(todayStr))
            ..limit(1))
          .get())
          .firstOrNull;

      final PlaceVisit visit;
      if (existingVisit != null) {
        visit = existingVisit;
      } else {
        final visitId = _uuid.v4();
        visit = PlaceVisit(
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
      }

      // 3. Resolve activeStop and activeItem across the trip
      Stop? activeStop;
      ScheduleItem? activeItem;

      if (scheduleItemId != null) {
        activeItem = await (db.select(db.scheduleItems)
              ..where((s) => s.id.equals(scheduleItemId) & s.deletedAt.isNull()))
            .getSingleOrNull();
        if (activeItem != null) {
          activeStop = await (db.select(db.stops)
                ..where((s) => s.id.equals(activeItem!.stopId) & s.deletedAt.isNull()))
              .getSingleOrNull();
          resolvedTripId ??= activeItem.tripId;
        }
      }

      if (activeStop == null && resolvedTripId != null) {
        if (stopId != null) {
          activeStop = await (db.select(db.stops)
                ..where((s) => s.id.equals(stopId) & s.deletedAt.isNull()))
              .getSingleOrNull();
        }
        if (activeStop == null) {
          activeStop = (await (db.select(db.stops)
                ..where((s) =>
                    s.tripId.equals(resolvedTripId!) &
                    s.placeKey.equals(placeKey) &
                    s.deletedAt.isNull()))
              .get())
              .firstOrNull;
        }

        if (activeStop != null && activeItem == null) {
          final items = await (db.select(db.scheduleItems)
                ..where((s) =>
                    s.stopId.equals(activeStop!.id) &
                    s.tripId.equals(resolvedTripId!) &
                    s.deletedAt.isNull()))
              .get();
          if (dayId != null) {
            activeItem = items.where((i) => i.dayId == dayId).firstOrNull ?? items.firstOrNull;
          } else {
            activeItem = items.firstOrNull;
          }
        }
      }

      // 4. If markDone is true and activeItem exists, mark it done
      if (activeItem != null && markDone && activeItem.status != 'done') {
        final now = DateTime.now();
        await (db.update(db.scheduleItems)
              ..where((s) => s.id.equals(activeItem!.id) & s.tripId.equals(activeItem.tripId)))
            .write(
          ScheduleItemsCompanion(
            status: const Value('done'),
            syncStatus: const Value(1),
            updatedAt: Value(now),
          ),
        );
        activeItem = activeItem.copyWith(status: 'done', syncStatus: 1, updatedAt: now);
      }

      return CheckInResult(
        visit: visit,
        stop: activeStop,
        scheduleItem: activeItem,
        wasOffPlan: resolvedTripId != null && activeStop == null,
      );
    });
  }

  /// Fetches a hydrated [TodayPilgrimageFeed] for the specified [tripId] and [dayId]
  /// (defaulting to today's active trip and day block if omitted).
  Future<TodayPilgrimageFeed?> getPilgrimageFeed(
    AppDatabase db, {
    String? tripId,
    String? dayId,
    double? userLat,
    double? userLng,
    double? deviceHeading,
    DateTime? now,
  }) async {
    final Trip? trip;
    final TripDay? day;
    final List<ScheduleItem> scheduleItems;
    final Map<String, Stop> stopMap;

    if (tripId != null || dayId != null) {
      String? targetTripId = tripId;
      if (targetTripId == null && dayId != null) {
        final d = await (db.select(db.tripDays)
              ..where((tbl) => tbl.id.equals(dayId) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
        targetTripId = d?.tripId;
      }
      if (targetTripId == null) return null;

      trip = await (db.select(db.trips)
            ..where((t) => t.id.equals(targetTripId!) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (trip == null) return null;

      if (dayId != null) {
        day = await (db.select(db.tripDays)
              ..where((d) => d.id.equals(dayId) & d.deletedAt.isNull()))
            .getSingleOrNull();
      } else {
        day = (await (db.select(db.tripDays)
              ..where((d) => d.tripId.equals(targetTripId!) & d.deletedAt.isNull())
              ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
            .get())
            .firstOrNull;
      }
      if (day == null) return null;

      scheduleItems = await (db.select(db.scheduleItems)
            ..where((s) => s.dayId.equals(day!.id) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
          .get();

      final stops = await (db.select(db.stops)
            ..where((s) => s.tripId.equals(targetTripId!) & s.deletedAt.isNull()))
          .get();
      stopMap = {for (final s in stops) s.id: s};
    } else {
      final todayTrip = await getTodayTrip(db, now: now);
      if (todayTrip == null) return null;
      trip = todayTrip.trip;
      day = todayTrip.day;
      scheduleItems = todayTrip.scheduleItems;
      stopMap = todayTrip.stopMap;
    }

    if (scheduleItems.isEmpty) {
      return TodayPilgrimageFeed(
        trip: trip,
        day: day,
        stops: const [],
      );
    }

    // Collect all placeKeys and stopIds
    final placeKeys = <String>{};
    final stopIds = <String>{};
    for (final item in scheduleItems) {
      stopIds.add(item.stopId);
      final s = stopMap[item.stopId];
      if (s != null && s.placeKey.isNotEmpty) {
        placeKeys.add(s.placeKey);
      }
    }

    // 1. Batch load Places
    final places = placeKeys.isNotEmpty
        ? await (db.select(db.places)..where((p) => p.placeKey.isIn(placeKeys))).get()
        : <Place>[];
    final placeMap = {for (final p in places) p.placeKey: p};

    // 2. Batch load Reference Frames (by placeKey or stopId)
    final refImages = await (db.select(db.newReferenceImages)
          ..where((r) =>
              (r.placeKey.isNotNull() & r.placeKey.isIn(placeKeys)) |
              (r.stopId.isNotNull() & r.stopId.isIn(stopIds))))
        .get();
    final refMapByPlaceKey = <String, List<NewReferenceImage>>{};
    final refMapByStopId = <String, List<NewReferenceImage>>{};
    for (final ref in refImages) {
      if (ref.placeKey != null) {
        refMapByPlaceKey.putIfAbsent(ref.placeKey!, () => []).add(ref);
      }
      if (ref.stopId != null) {
        refMapByStopId.putIfAbsent(ref.stopId!, () => []).add(ref);
      }
    }

    // 3. Batch load Anime Labels
    final animeLabels = await _loadPlaceAnimeLabels(db, placeKeys.toList());

    // 4. Determine nearest stop if GPS available
    String? nearestStopId;
    double minDistance = double.infinity;
    final bearingsByStopId = <String, SpotBearingInfo>{};

    if (userLat != null && userLng != null) {
      for (final item in scheduleItems) {
        final stop = stopMap[item.stopId];
        if (stop == null) continue;
        final targetLat = stop.lat != 0.0 ? stop.lat : (placeMap[stop.placeKey]?.lat ?? 0.0);
        final targetLng = stop.lng != 0.0 ? stop.lng : (placeMap[stop.placeKey]?.lng ?? 0.0);

        if (targetLat != 0.0 || targetLng != 0.0) {
          final bearing = calculateBearingInfo(
            userLat: userLat,
            userLng: userLng,
            spotLat: targetLat,
            spotLng: targetLng,
            deviceHeading: deviceHeading,
          );
          bearingsByStopId[stop.id] = bearing;
          if (bearing.distanceMeters < minDistance) {
            minDistance = bearing.distanceMeters;
            nearestStopId = stop.id;
          }
        }
      }
    }

    // 5. Build live stops list
    bool nextTargetFound = false;
    final liveStops = <LivePilgrimageStop>[];

    for (final item in scheduleItems) {
      final stop = stopMap[item.stopId];
      if (stop == null) continue;

      final place = placeMap[stop.placeKey];
      final frames = [
        ...?refMapByStopId[stop.id],
        if (refMapByStopId[stop.id] == null && stop.placeKey.isNotEmpty)
          ...?refMapByPlaceKey[stop.placeKey],
      ];
      final animeTitle = animeLabels[stop.placeKey];
      final bearing = bearingsByStopId[stop.id];

      final isNearest = stop.id == nearestStopId;
      final isNext = !nextTargetFound && item.status == 'planned';
      if (isNext) {
        nextTargetFound = true;
      }

      liveStops.add(LivePilgrimageStop(
        scheduleItem: item,
        stop: stop,
        place: place,
        referenceFrames: frames,
        animeTitle: animeTitle,
        bearingInfo: bearing,
        isNextTarget: isNext,
        isNearest: isNearest,
      ));
    }

    return TodayPilgrimageFeed(
      trip: trip,
      day: day,
      stops: liveStops,
    );
  }

  /// Streams the live pilgrimage route reactively whenever schedule items change.
  Stream<TodayPilgrimageFeed?> watchPilgrimageFeed(
    AppDatabase db, {
    String? tripId,
    String? dayId,
    double? userLat,
    double? userLng,
    double? deviceHeading,
    DateTime? now,
  }) {
    return (db.select(db.scheduleItems)).watch().asyncMap((_) async {
      return getPilgrimageFeed(
        db,
        tripId: tripId,
        dayId: dayId,
        userLat: userLat,
        userLng: userLng,
        deviceHeading: deviceHeading,
        now: now,
      );
    });
  }

  /// Convenience method for today's live feed.
  Future<TodayPilgrimageFeed?> getTodayPilgrimageFeed(
    AppDatabase db, {
    double? userLat,
    double? userLng,
    double? deviceHeading,
    DateTime? now,
  }) =>
      getPilgrimageFeed(
        db,
        userLat: userLat,
        userLng: userLng,
        deviceHeading: deviceHeading,
        now: now,
      );

  /// Convenience stream for today's live feed.
  Stream<TodayPilgrimageFeed?> watchTodayPilgrimageFeed(
    AppDatabase db, {
    double? userLat,
    double? userLng,
    double? deviceHeading,
    DateTime? now,
  }) =>
      watchPilgrimageFeed(
        db,
        userLat: userLat,
        userLng: userLng,
        deviceHeading: deviceHeading,
        now: now,
      );

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
