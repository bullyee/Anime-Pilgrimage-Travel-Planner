import 'dart:math' as math;
import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/walking_transit_models.dart';

/// Service calculating realistic walking transit durations and physical fatigue
/// using Tobler's Hiking Function and terrain elevation gradients.
///
/// Features:
/// - Tobler's Hiking Function: W = 6 * exp(-3.5 * |S + 0.05|) km/h.
/// - Geodesic Haversine distance with elevation-adjusted gradient calculation.
/// - Automatic calibration of ScheduleItem transit minutes in SQLite.
/// - Objective physical fatigue reporting (distance, elevation gain/loss, slope severity).
/// - Full compliance with Rule 2 (Entity Scope Isolation) and Rule 3 (Awaited mutations).
class WalkingTransitService {
  const WalkingTransitService();

  /// Computes human walking velocity (in km/h) based on slope gradient [S = elevationChange / distance].
  ///
  /// Tobler's empirical formula:
  /// W = 6 * exp(-3.5 * |S + 0.05|)
  ///
  /// - Flat ground (S = 0): ~5.04 km/h
  /// - Gentle downhill (S = -0.05): peak speed 6.00 km/h
  /// - Moderate uphill (S = +0.10, 10% slope): ~3.55 km/h
  /// - Steep mountain uphill (S = +0.25, 25% slope): ~2.10 km/h
  /// - Steep downhill (S = -0.20): ~3.55 km/h (braking)
  static double calculateToblerVelocity({
    required double distanceMeters,
    required double elevationChangeMeters,
  }) {
    if (distanceMeters <= 0.0) return 5.0;

    final slope = elevationChangeMeters / distanceMeters;
    final expArg = -3.5 * (slope + 0.05).abs();
    final velocity = 6.0 * math.exp(expArg);

    // Clamp between 0.5 km/h (minimum rock/stair scramble) and 6.0 km/h (maximum walking pace)
    return velocity.clamp(0.5, 6.0);
  }

  /// Calculates geodesic great-circle distance between two coordinates in meters.
  static double haversineDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Estimates the walking transit parameters for a single segment between two stops.
  WalkingSegmentEstimate estimateSegment({
    required String fromStopId,
    required String toStopId,
    required String fromName,
    required String toName,
    required double fromLat,
    required double fromLng,
    double? fromElevation,
    required double toLat,
    required double toLng,
    double? toElevation,
    int bufferMinutes = 1,
  }) {
    final distance = haversineDistanceMeters(fromLat, fromLng, toLat, toLng);
    final elevationChange = (fromElevation != null && toElevation != null)
        ? (toElevation - fromElevation)
        : 0.0;

    final slope = distance > 0 ? (elevationChange / distance) : 0.0;
    final velocityKmH = calculateToblerVelocity(
      distanceMeters: distance,
      elevationChangeMeters: elevationChange,
    );

    // Duration in minutes = (distance / 1000) / velocity * 60
    final rawMinutes = (distance / 1000.0) / velocityKmH * 60.0;

    // Apply buffer only if there's actual distance traversed (> 50m)
    final buffer = distance > 50 ? bufferMinutes : 0;
    final totalMinutes = (rawMinutes + buffer).ceil();
    final estimatedMinutes = distance > 0 ? math.max(1, totalMinutes) : 0;

    final isSteepUphill = slope >= 0.15;
    final isSteepDownhill = slope <= -0.15;

    return WalkingSegmentEstimate(
      fromStopId: fromStopId,
      toStopId: toStopId,
      fromStopName: fromName,
      toStopName: toName,
      distanceMeters: distance,
      elevationChangeMeters: elevationChange,
      slope: slope,
      calculatedVelocityKmH: velocityKmH,
      estimatedTransitMinutes: estimatedMinutes,
      isSteepUphill: isSteepUphill,
      isSteepDownhill: isSteepDownhill,
    );
  }

  /// Evaluates the physical fatigue and walking terrain metrics for a given day in a trip.
  Future<WalkingFatigueReport> calculateDayWalkingFatigue(
    AppDatabase db,
    String tripId,
    String dayId, {
    int bufferMinutes = 1,
    Map<String, double>? stopElevations,
  }) async {
    // Entity Scope Isolation: verify day belongs to trip
    final day = await (db.select(db.tripDays)
          ..where((d) => d.id.equals(dayId) & d.tripId.equals(tripId)))
        .getSingleOrNull();
    if (day == null) {
      throw ArgumentError('Day $dayId does not belong to trip $tripId');
    }

    final scheduleItems = await (db.select(db.scheduleItems)
          ..where((s) => s.dayId.equals(dayId) & s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
        .get();

    if (scheduleItems.length < 2) {
      return WalkingFatigueReport(
        tripId: tripId,
        dayId: dayId,
        segmentCount: 0,
        totalDistanceMeters: 0.0,
        totalElevationGainMeters: 0.0,
        totalElevationLossMeters: 0.0,
        totalWalkingMinutes: 0,
        maxSlope: 0.0,
        fatigueLevel: WalkingFatigueLevel.easy,
        segments: const [],
      );
    }

    final stops = await (db.select(db.stops)..where((s) => s.tripId.equals(tripId))).get();
    final stopMap = {for (final s in stops) s.id: s};

    final segments = <WalkingSegmentEstimate>[];
    double totalDistance = 0.0;
    double totalGain = 0.0;
    double totalLoss = 0.0;
    int totalMinutes = 0;
    double maxSlope = 0.0;

    for (int i = 0; i < scheduleItems.length - 1; i++) {
      final fromItem = scheduleItems[i];
      final toItem = scheduleItems[i + 1];

      final fromStop = stopMap[fromItem.stopId];
      final toStop = stopMap[toItem.stopId];
      if (fromStop == null || toStop == null) continue;

      final fromEle = stopElevations?[fromStop.id];
      final toEle = stopElevations?[toStop.id];

      final seg = estimateSegment(
        fromStopId: fromStop.id,
        toStopId: toStop.id,
        fromName: fromStop.name,
        toName: toStop.name,
        fromLat: fromStop.lat,
        fromLng: fromStop.lng,
        fromElevation: fromEle,
        toLat: toStop.lat,
        toLng: toStop.lng,
        toElevation: toEle,
        bufferMinutes: bufferMinutes,
      );

      segments.add(seg);
      totalDistance += seg.distanceMeters;
      if (seg.elevationChangeMeters > 0) {
        totalGain += seg.elevationChangeMeters;
      } else {
        totalLoss += seg.elevationChangeMeters.abs();
      }
      totalMinutes += seg.estimatedTransitMinutes;
      if (seg.slope.abs() > maxSlope) {
        maxSlope = seg.slope.abs();
      }
    }

    final fatigueLevel = _classifyFatigue(
      totalDistanceMeters: totalDistance,
      totalElevationGainMeters: totalGain,
      maxSlope: maxSlope,
    );

    return WalkingFatigueReport(
      tripId: tripId,
      dayId: dayId,
      segmentCount: segments.length,
      totalDistanceMeters: totalDistance,
      totalElevationGainMeters: totalGain,
      totalElevationLossMeters: totalLoss,
      totalWalkingMinutes: totalMinutes,
      maxSlope: maxSlope,
      fatigueLevel: fatigueLevel,
      segments: segments,
    );
  }

  /// Calculates and writes realistic Tobler walking transit minutes into SQLite schedule items.
  ///
  /// Guarantees:
  /// - Entity Scope Isolation: verified scoped to [tripId] and [dayId].
  /// - Partial Update Protection (Rule 2): updates only `transitMinutes` and `updatedAt`.
  /// - Awaited transaction (Rule 3: zero fire-and-forget mutations).
  Future<TransitUpdateSummary> applyDayWalkingTransits(
    AppDatabase db,
    String tripId,
    String dayId, {
    int bufferMinutes = 1,
    Map<String, double>? stopElevations,
  }) async {
    final report = await calculateDayWalkingFatigue(
      db,
      tripId,
      dayId,
      bufferMinutes: bufferMinutes,
      stopElevations: stopElevations,
    );

    return await db.transaction(() async {
      final scheduleItems = await (db.select(db.scheduleItems)
            ..where((s) => s.dayId.equals(dayId) & s.tripId.equals(tripId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
          .get();

      int updatedCount = 0;
      int totalMinutesAssigned = 0;

      for (int i = 0; i < scheduleItems.length; i++) {
        final item = scheduleItems[i];
        final int targetTransit;

        if (i < report.segments.length) {
          targetTransit = report.segments[i].estimatedTransitMinutes;
        } else {
          // Last stop of the day has no transit to subsequent stop
          targetTransit = 0;
        }

        await (db.update(db.scheduleItems)..where((s) => s.id.equals(item.id))).write(
          ScheduleItemsCompanion(
            transitMinutes: Value(targetTransit),
            updatedAt: Value(DateTime.now()),
          ),
        );

        updatedCount++;
        totalMinutesAssigned += targetTransit;
      }

      return TransitUpdateSummary(
        tripId: tripId,
        dayId: dayId,
        updatedScheduleItemCount: updatedCount,
        totalTransitMinutesAssigned: totalMinutesAssigned,
      );
    });
  }

  /// Calculates and writes realistic walking transits across all day blocks of a trip.
  Future<List<TransitUpdateSummary>> applyTripWalkingTransits(
    AppDatabase db,
    String tripId, {
    int bufferMinutes = 1,
    Map<String, double>? stopElevations,
  }) async {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) {
      throw ArgumentError('Trip with ID $tripId not found');
    }

    final days = await (db.select(db.tripDays)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
        .get();

    final summaries = <TransitUpdateSummary>[];
    for (final day in days) {
      final summary = await applyDayWalkingTransits(
        db,
        tripId,
        day.id,
        bufferMinutes: bufferMinutes,
        stopElevations: stopElevations,
      );
      summaries.add(summary);
    }
    return summaries;
  }

  static WalkingFatigueLevel _classifyFatigue({
    required double totalDistanceMeters,
    required double totalElevationGainMeters,
    required double maxSlope,
  }) {
    if (totalDistanceMeters >= 18000.0 || totalElevationGainMeters >= 600.0 || maxSlope >= 0.35) {
      return WalkingFatigueLevel.extreme;
    }
    if (totalDistanceMeters >= 10000.0 || totalElevationGainMeters >= 300.0 || maxSlope >= 0.20) {
      return WalkingFatigueLevel.strenuous;
    }
    if (totalDistanceMeters >= 4000.0 || totalElevationGainMeters >= 100.0 || maxSlope >= 0.10) {
      return WalkingFatigueLevel.moderate;
    }
    return WalkingFatigueLevel.easy;
  }
}
