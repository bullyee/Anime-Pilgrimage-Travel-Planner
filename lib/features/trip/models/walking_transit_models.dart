import 'package:flutter/foundation.dart';

/// Geographic coordinate with optional elevation.
@immutable
class ElevationCoordinate {
  final double lat;
  final double lng;
  final double? elevation;

  const ElevationCoordinate({
    required this.lat,
    required this.lng,
    this.elevation,
  });

  bool get isValid => lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
}

/// Estimated walking transit parameters for a single segment between two consecutive stops.
@immutable
class WalkingSegmentEstimate {
  final String fromStopId;
  final String toStopId;
  final String fromStopName;
  final String toStopName;
  final double distanceMeters;
  final double elevationChangeMeters;
  final double slope;
  final double calculatedVelocityKmH;
  final int estimatedTransitMinutes;
  final bool isSteepUphill;
  final bool isSteepDownhill;

  const WalkingSegmentEstimate({
    required this.fromStopId,
    required this.toStopId,
    required this.fromStopName,
    required this.toStopName,
    required this.distanceMeters,
    required this.elevationChangeMeters,
    required this.slope,
    required this.calculatedVelocityKmH,
    required this.estimatedTransitMinutes,
    required this.isSteepUphill,
    required this.isSteepDownhill,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalkingSegmentEstimate &&
          runtimeType == other.runtimeType &&
          fromStopId == other.fromStopId &&
          toStopId == other.toStopId &&
          distanceMeters == other.distanceMeters &&
          elevationChangeMeters == other.elevationChangeMeters &&
          estimatedTransitMinutes == other.estimatedTransitMinutes;

  @override
  int get hashCode => Object.hash(
        fromStopId,
        toStopId,
        distanceMeters,
        elevationChangeMeters,
        estimatedTransitMinutes,
      );

  @override
  String toString() =>
      'WalkingSegmentEstimate($fromStopName -> $toStopName: ${distanceMeters.toStringAsFixed(0)}m, '
      'ele: ${elevationChangeMeters.toStringAsFixed(1)}m, $estimatedTransitMinutes min)';
}

/// Objective physical strain fatigue level for a day's walking.
enum WalkingFatigueLevel {
  easy,
  moderate,
  strenuous,
  extreme,
}

/// Comprehensive physical fatigue and terrain elevation report for a day block.
@immutable
class WalkingFatigueReport {
  final String tripId;
  final String dayId;
  final int segmentCount;
  final double totalDistanceMeters;
  final double totalElevationGainMeters;
  final double totalElevationLossMeters;
  final int totalWalkingMinutes;
  final double maxSlope;
  final WalkingFatigueLevel fatigueLevel;
  final List<WalkingSegmentEstimate> segments;

  const WalkingFatigueReport({
    required this.tripId,
    required this.dayId,
    required this.segmentCount,
    required this.totalDistanceMeters,
    required this.totalElevationGainMeters,
    required this.totalElevationLossMeters,
    required this.totalWalkingMinutes,
    required this.maxSlope,
    required this.fatigueLevel,
    required this.segments,
  });

  @override
  String toString() =>
      'WalkingFatigueReport(dayId: $dayId, dist: ${(totalDistanceMeters / 1000).toStringAsFixed(2)}km, '
      'gain: +${totalElevationGainMeters.toStringAsFixed(0)}m, '
      'loss: -${totalElevationLossMeters.toStringAsFixed(0)}m, '
      'time: $totalWalkingMinutes min, fatigue: ${fatigueLevel.name})';
}

/// Summary of updated transit minutes on schedule items.
@immutable
class TransitUpdateSummary {
  final String tripId;
  final String dayId;
  final int updatedScheduleItemCount;
  final int totalTransitMinutesAssigned;

  const TransitUpdateSummary({
    required this.tripId,
    required this.dayId,
    required this.updatedScheduleItemCount,
    required this.totalTransitMinutesAssigned,
  });
}
