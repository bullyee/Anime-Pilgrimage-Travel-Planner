import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/photo_exif_models.dart';
import 'photo_exif_extractor.dart';

/// Target destination used by the matcher to score against photo metadata.
class StopTarget {
  final String stopId;
  final String placeKey;
  final String name;
  final String? animeTitle;
  final String? referenceImageId;
  final double lat;
  final double lng;
  final DateTime? scheduledWindowStart;
  final DateTime? scheduledWindowEnd;

  const StopTarget({
    required this.stopId,
    required this.placeKey,
    required this.name,
    this.animeTitle,
    this.referenceImageId,
    required this.lat,
    required this.lng,
    this.scheduledWindowStart,
    this.scheduledWindowEnd,
  });
}

/// Service that automatically matches captured photos against planned pilgrimage stops
/// and anime reference scenes using spatial proximity and itinerary timeline correlation.
class PhotoSceneMatcherService {
  const PhotoSceneMatcherService();

  /// Matches a single [photo] against a set of [targets].
  Future<PhotoMatchResult> matchPhoto({
    required PhotoInput photo,
    required List<StopTarget> targets,
  }) async {
    // 1. Resolve EXIF
    PhotoExifData exif = photo.explicitExif ?? const PhotoExifData();
    if (photo.explicitExif == null) {
      if (photo.bytes != null) {
        exif = PhotoExifExtractor.extractFromBytes(photo.bytes!);
      } else if (photo.localPath != null) {
        exif = await PhotoExifExtractor.extractFromFile(File(photo.localPath!));
      }
    }

    final candidates = <PhotoMatchCandidate>[];

    for (final target in targets) {
      double? distanceMeters;
      double spatialScore = 0.0;

      // A. Spatial Proximity Scoring
      if (exif.hasGps) {
        distanceMeters = _haversineDistance(
          exif.lat!,
          exif.lng!,
          target.lat,
          target.lng,
        );

        if (distanceMeters <= 30.0) {
          spatialScore = 1.0;
        } else if (distanceMeters <= 200.0) {
          spatialScore = 1.0 - ((distanceMeters - 30.0) / 170.0) * 0.70;
        } else if (distanceMeters <= 1000.0) {
          spatialScore = 0.30 * (1.0 - ((distanceMeters - 200.0) / 800.0));
        } else {
          spatialScore = 0.0;
        }
      }

      // B. Temporal Schedule Alignment Scoring
      double temporalScore = 0.0;
      final photoTime = exif.capturedAt;
      final winStart = target.scheduledWindowStart;
      final winEnd = target.scheduledWindowEnd;

      if (photoTime != null && winStart != null && winEnd != null) {
        final bufferStart = winStart.subtract(const Duration(minutes: 15));
        final bufferEnd = winEnd.add(const Duration(minutes: 15));

        if (photoTime.isAfter(bufferStart) && photoTime.isBefore(bufferEnd)) {
          temporalScore = 1.0;
        } else {
          // Check difference in minutes from window bounds
          final diffBefore = bufferStart.difference(photoTime).inMinutes;
          final diffAfter = photoTime.difference(bufferEnd).inMinutes;
          final minDiff = math.max(diffBefore, diffAfter);

          if (minDiff <= 60) {
            temporalScore = 0.70 - (minDiff / 60.0) * 0.35;
          } else if (_isSameCalendarDay(photoTime, winStart)) {
            temporalScore = 0.30;
          } else {
            temporalScore = 0.0;
          }
        }
      } else if (photoTime != null && winStart != null) {
        if (_isSameCalendarDay(photoTime, winStart)) {
          temporalScore = 0.30;
        }
      }

      // C. Blended Confidence Calculation
      double confidence;
      String reason;

      if (exif.hasGps && photoTime != null && winStart != null) {
        confidence = 0.65 * spatialScore + 0.35 * temporalScore;
        reason =
            '${(distanceMeters!).toStringAsFixed(1)}m from spot; temporal score ${(temporalScore * 100).toInt()}%';
      } else if (exif.hasGps) {
        confidence = spatialScore;
        reason = '${(distanceMeters!).toStringAsFixed(1)}m from GPS coordinates';
      } else if (photoTime != null && winStart != null) {
        confidence = temporalScore * 0.65;
        reason = 'Matched by scheduled itinerary timeline';
      } else {
        confidence = 0.0;
        reason = 'No GPS or timestamp data available';
      }

      if (confidence >= 0.35) {
        candidates.add(
          PhotoMatchCandidate(
            stopId: target.stopId,
            placeKey: target.placeKey,
            stopName: target.name,
            animeTitle: target.animeTitle,
            referenceImageId: target.referenceImageId,
            distanceMeters: distanceMeters,
            confidence: double.parse(confidence.toStringAsFixed(3)),
            matchReason: reason,
          ),
        );
      }
    }

    // Sort descending by confidence
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    final bestMatch = candidates.isNotEmpty ? candidates.first : null;
    var isAmbiguous = false;
    if (candidates.length >= 2) {
      if ((candidates[0].confidence - candidates[1].confidence) < 0.06) {
        isAmbiguous = true;
      }
    }

    return PhotoMatchResult(
      photoId: photo.id,
      localPath: photo.localPath,
      exif: exif,
      bestMatch: bestMatch,
      allCandidates: candidates,
      isAmbiguous: isAmbiguous,
    );
  }

  /// Matches a batch of [photos] against [targets].
  Future<List<PhotoMatchResult>> matchPhotos({
    required List<PhotoInput> photos,
    required List<StopTarget> targets,
  }) async {
    final results = <PhotoMatchResult>[];
    for (final photo in photos) {
      results.add(await matchPhoto(photo: photo, targets: targets));
    }
    return results;
  }

  /// Queries SQLite for a trip's itinerary and matches [photos] against its stops.
  Future<List<PhotoMatchResult>> matchPhotosForTrip(
    AppDatabase db,
    String tripId,
    List<PhotoInput> photos,
  ) async {
    // 1. Fetch trip and days with Entity Scope Isolation
    final trip = await (db.select(db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return const [];

    final days = await (db.select(db.tripDays)
          ..where((tbl) => tbl.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
        .get();
    final dayIndexMap = {for (var i = 0; i < days.length; i++) days[i].id: i};

    DateTime? tripStartDate;
    if (trip.startDate != null && trip.startDate!.isNotEmpty) {
      tripStartDate = DateTime.tryParse(trip.startDate!);
    }

    // 2. Fetch stops and stop labels
    final stops = await (db.select(db.stops)..where((tbl) => tbl.tripId.equals(tripId))).get();

    final animeByStopId = <String, String>{};
    if (stops.isNotEmpty) {
      final labelsQuery = (db.select(db.stopLabels)
            ..where((tbl) => tbl.stopId.isIn(stops.map((s) => s.id))))
          .join([
        innerJoin(
          db.labels,
          db.labels.id.equalsExp(db.stopLabels.labelId) &
              db.labels.kind.equals('anime'),
        ),
      ]);
      final labelRows = await labelsQuery.get();
      for (final row in labelRows) {
        final stopLabel = row.readTable(db.stopLabels);
        final label = row.readTable(db.labels);
        animeByStopId[stopLabel.stopId] = label.name;
      }
    }

    // 3. Fetch reference images
    final refImages = stops.isNotEmpty
        ? await (db.select(db.newReferenceImages)
              ..where((tbl) => tbl.stopId.isIn(stops.map((s) => s.id))))
            .get()
        : <NewReferenceImage>[];
    final refByStopId = <String, String>{};
    for (final r in refImages) {
      if (r.stopId != null) {
        refByStopId[r.stopId!] = r.id;
      }
    }

    // 4. Fetch schedule items to build timeline windows
    final scheduleItems = await (db.select(db.scheduleItems)
          ..where((tbl) => tbl.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
        .get();

    // Map scheduled time windows per stopId
    final timeWindowMap = <String, ({DateTime start, DateTime end})>{};
    for (final day in days) {
      DateTime? dayDate;
      if (day.pinnedDate != null && day.pinnedDate!.isNotEmpty) {
        dayDate = DateTime.tryParse(day.pinnedDate!);
      } else if (tripStartDate != null) {
        final idx = dayIndexMap[day.id] ?? 0;
        dayDate = tripStartDate.add(Duration(days: idx));
      }

      if (dayDate == null) continue;

      final dayItems = scheduleItems.where((si) => si.dayId == day.id).toList();
      var currentMinutes = 540; // 09:00 default
      for (final item in dayItems) {
        final arrivalMin = item.fixedTime ?? (currentMinutes + item.transitMinutes);
        final departureMin = arrivalMin + item.stayMinutes;
        currentMinutes = departureMin;

        final start = DateTime(
          dayDate.year,
          dayDate.month,
          dayDate.day,
          arrivalMin ~/ 60,
          arrivalMin % 60,
        );
        final end = DateTime(
          dayDate.year,
          dayDate.month,
          dayDate.day,
          departureMin ~/ 60,
          departureMin % 60,
        );
        timeWindowMap[item.stopId] = (start: start, end: end);
      }
    }

    // Build StopTargets
    final targets = stops.map((stop) {
      final window = timeWindowMap[stop.id];
      return StopTarget(
        stopId: stop.id,
        placeKey: stop.placeKey,
        name: stop.name,
        animeTitle: animeByStopId[stop.id],
        referenceImageId: refByStopId[stop.id],
        lat: stop.lat,
        lng: stop.lng,
        scheduledWindowStart: window?.start,
        scheduledWindowEnd: window?.end,
      );
    }).toList();

    return matchPhotos(photos: photos, targets: targets);
  }

  /// Commits matched photos to the database [Photos] table.
  ///
  /// Only applies matches that meet the [minConfidence] threshold (default 0.50).
  /// Verifies foreign key parent existence before inserting to guarantee zero data loss.
  Future<int> applyPhotoMatches(
    AppDatabase db,
    String tripId,
    List<PhotoMatchResult> matches, {
    double minConfidence = 0.50,
  }) async {
    final candidatePlaceKeys = matches
        .map((m) => m.bestMatch?.placeKey)
        .whereType<String>()
        .toSet();

    if (candidatePlaceKeys.isEmpty) return 0;

    // Verify parent Place existence (Rule 2: Foreign Key / Parent Existence Validation)
    final existingPlaces = await (db.select(db.places)
          ..where((tbl) => tbl.placeKey.isIn(candidatePlaceKeys)))
        .get();
    final validPlaceKeys = {for (final p in existingPlaces) p.placeKey};

    var appliedCount = 0;
    await db.transaction(() async {
      for (final match in matches) {
        final best = match.bestMatch;
        if (best == null || best.confidence < minConfidence) continue;
        if (!validPlaceKeys.contains(best.placeKey)) continue;

        await db.into(db.photos).insert(
              PhotosCompanion.insert(
                id: match.photoId,
                placeKey: best.placeKey,
                tripId: Value(tripId),
                localPath: match.localPath ?? '',
                kind: const Value('original'),
                referenceImageId: Value(best.referenceImageId),
                takenAt: match.exif.capturedAt != null
                    ? Value(match.exif.capturedAt!)
                    : const Value.absent(),
              ),
            );
        appliedCount++;
      }
    });
    return appliedCount;
  }

  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
