import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/feasibility_models.dart';
import 'opening_hours_parser.dart';

/// Core diagnosis engine that evaluates itinerary timelines, opening hours conflicts,
/// transit gaps, and pacing feasibility across trips and individual day blocks.
class ItineraryFeasibilityService {
  const ItineraryFeasibilityService();

  /// Evaluates an in-memory day timeline against business hour rules and geographic constraints.
  DayFeasibilityReport evaluateDayTimeline({
    required String dayId,
    String? dayTitle,
    DateTime? date,
    required List<ScheduleItem> items,
    required Map<String, Stop> stopsMap,
    int defaultStartMinutes = 540, // 09:00 default start
  }) {
    if (items.isEmpty) {
      return DayFeasibilityReport(
        dayId: dayId,
        dayTitle: dayTitle,
        date: date,
        stops: const [],
        issues: const [],
        dayStartMinutes: defaultStartMinutes,
        dayEndMinutes: defaultStartMinutes,
      );
    }

    final dayIssues = <FeasibilityIssue>[];
    final timelineStops = <DayTimelineStop>[];

    // Determine initial departure time
    var currentMinutes = defaultStartMinutes;
    if (items.first.fixedTime != null && items.first.fixedTime! < defaultStartMinutes) {
      currentMinutes = items.first.fixedTime!;
    }
    final initialStartMinutes = currentMinutes;

    Stop? previousStop;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final stop = stopsMap[item.stopId];
      if (stop == null) continue;

      final stopIssues = <FeasibilityIssue>[];
      final transitMinutes = item.transitMinutes;

      // 1. Check geographic transit feasibility
      double? distanceMeters;
      if (previousStop != null) {
        distanceMeters = _haversineDistance(
          previousStop.lat,
          previousStop.lng,
          stop.lat,
          stop.lng,
        );

        if (distanceMeters > 500 && transitMinutes == 0) {
          final issue = FeasibilityIssue(
            id: 'missing-transit-${item.id}',
            type: FeasibilityIssueType.missingTransitTime,
            severity: FeasibilitySeverity.warning,
            dayId: dayId,
            scheduleItemId: item.id,
            stopId: stop.id,
            stopName: stop.name,
            message:
                'Stops are ${(distanceMeters / 1000).toStringAsFixed(1)}km apart, but transit time is set to 0m.',
            suggestedFix:
                'Allocate at least ${(distanceMeters / 80).ceil()}m transit time.',
          );
          stopIssues.add(issue);
          dayIssues.add(issue);
        }
      }

      // 2. Timeline and fixed-time alignment
      final projectedArrival = currentMinutes + transitMinutes;
      int actualArrival;

      if (item.fixedTime != null) {
        final fixedTime = item.fixedTime!;
        if (projectedArrival > fixedTime) {
          final delay = projectedArrival - fixedTime;
          final issue = FeasibilityIssue(
            id: 'overlap-${item.id}',
            type: FeasibilityIssueType.timelineOverlap,
            severity: FeasibilitySeverity.error,
            dayId: dayId,
            scheduleItemId: item.id,
            stopId: stop.id,
            stopName: stop.name,
            message:
                'Fixed arrival at ${TimeWindow.formatMinutes(fixedTime)} is missed by ${delay}m (arrives ${TimeWindow.formatMinutes(projectedArrival)}).',
            suggestedFix:
                'Shorten prior stop visits or advance day start time by at least ${delay}m.',
          );
          stopIssues.add(issue);
          dayIssues.add(issue);
          actualArrival = projectedArrival;
        } else {
          actualArrival = fixedTime;
        }
      } else {
        actualArrival = projectedArrival;
      }

      // 3. Opening hours and holiday conflict checks
      final rule = OpeningHoursParser.parse(stop.businessHours);
      if (rule != null && date != null && !rule.isAlwaysOpen) {
        // A. Is venue closed on this date (定休日)?
        if (!rule.isOpenOnDate(date)) {
          final weekdayName = _weekdayName(date.weekday);
          final issue = FeasibilityIssue(
            id: 'closed-day-${item.id}',
            type: FeasibilityIssueType.closedOnDay,
            severity: FeasibilitySeverity.error,
            dayId: dayId,
            scheduleItemId: item.id,
            stopId: stop.id,
            stopName: stop.name,
            message:
                '${stop.name} is closed on $weekdayName (${stop.businessHours ?? '定休日'}).',
            suggestedFix:
                'Reschedule this stop to a day when the venue is open.',
          );
          stopIssues.add(issue);
          dayIssues.add(issue);
        } else {
          // B. Opening hours windows checks
          final windows = rule.getWindowsForDate(date);
          if (windows.isNotEmpty) {
            final firstWin = windows.first;
            final lastWin = windows.last;

            if (actualArrival < firstWin.openMinutes) {
              final waitMinutes = firstWin.openMinutes - actualArrival;
              final issue = FeasibilityIssue(
                id: 'before-open-${item.id}',
                type: FeasibilityIssueType.arrivesBeforeOpen,
                severity: FeasibilitySeverity.warning,
                dayId: dayId,
                scheduleItemId: item.id,
                stopId: stop.id,
                stopName: stop.name,
                message:
                    'Arrives at ${TimeWindow.formatMinutes(actualArrival)}, but ${stop.name} does not open until ${TimeWindow.formatMinutes(firstWin.openMinutes)} (${waitMinutes}m wait).',
                suggestedFix:
                    'Adjust arrival to ${TimeWindow.formatMinutes(firstWin.openMinutes)} or later.',
              );
              stopIssues.add(issue);
              dayIssues.add(issue);
            } else if (actualArrival >= lastWin.closeMinutes) {
              final issue = FeasibilityIssue(
                id: 'after-close-${item.id}',
                type: FeasibilityIssueType.arrivesAfterClose,
                severity: FeasibilitySeverity.error,
                dayId: dayId,
                scheduleItemId: item.id,
                stopId: stop.id,
                stopName: stop.name,
                message:
                    'Arrives at ${TimeWindow.formatMinutes(actualArrival)}, but ${stop.name} closes at ${TimeWindow.formatMinutes(lastWin.closeMinutes)}.',
                suggestedFix:
                    'Schedule earlier to arrive before closing time.',
              );
              stopIssues.add(issue);
              dayIssues.add(issue);
            } else {
              // Inside an open window, check if visit is truncated by closing
              final activeWin = windows.firstWhere(
                (w) => w.contains(actualArrival),
                orElse: () => lastWin,
              );
              final plannedDeparture = actualArrival + item.stayMinutes;
              if (plannedDeparture > activeWin.closeMinutes) {
                final lostMinutes = plannedDeparture - activeWin.closeMinutes;
                final issue = FeasibilityIssue(
                  id: 'truncated-${item.id}',
                  type: FeasibilityIssueType.visitTruncatedByClose,
                  severity: FeasibilitySeverity.warning,
                  dayId: dayId,
                  scheduleItemId: item.id,
                  stopId: stop.id,
                  stopName: stop.name,
                  message:
                      '${stop.name} closes at ${TimeWindow.formatMinutes(activeWin.closeMinutes)}, cutting planned ${item.stayMinutes}m visit short by ${lostMinutes}m.',
                  suggestedFix:
                      'Arrive by ${TimeWindow.formatMinutes(activeWin.closeMinutes - item.stayMinutes)} for the full visit.',
                );
                stopIssues.add(issue);
                dayIssues.add(issue);
              }
            }
          }
        }
      }

      final departureMinutes = actualArrival + item.stayMinutes;
      currentMinutes = departureMinutes;
      previousStop = stop;

      timelineStops.add(
        DayTimelineStop(
          scheduleItem: item,
          stop: stop,
          arrivalMinutes: actualArrival,
          departureMinutes: departureMinutes,
          transitFromPreviousMinutes: transitMinutes,
          distanceMetersFromPrevious: distanceMeters,
          issues: stopIssues,
        ),
      );
    }

    // 4. Day-level overcapacity & pace checks
    if (items.length > 10) {
      final issue = FeasibilityIssue(
        id: 'stops-overcapacity-$dayId',
        type: FeasibilityIssueType.dayOvercapacity,
        severity: FeasibilitySeverity.warning,
        dayId: dayId,
        stopName: dayTitle ?? 'Day Schedule',
        message:
            'Day contains ${items.length} stops. High-density pilgrimage pace may be exhausting.',
        suggestedFix: 'Consider splitting stops across multiple days.',
      );
      dayIssues.add(issue);
    }

    final totalDuration = currentMinutes - initialStartMinutes;
    if (totalDuration > 840 || currentMinutes >= 1380) {
      // > 14 hours duration or ends at/after 23:00
      final issue = FeasibilityIssue(
        id: 'duration-overcapacity-$dayId',
        type: FeasibilityIssueType.dayOvercapacity,
        severity: FeasibilitySeverity.warning,
        dayId: dayId,
        stopName: dayTitle ?? 'Day Schedule',
        message:
            'Day spans ${(totalDuration / 60).toStringAsFixed(1)} hours (ends at ${TimeWindow.formatMinutes(currentMinutes)}).',
        suggestedFix:
            'Shorten stay durations or reduce stops to end at a reasonable time.',
      );
      dayIssues.add(issue);
    }

    return DayFeasibilityReport(
      dayId: dayId,
      dayTitle: dayTitle,
      date: date,
      stops: timelineStops,
      issues: dayIssues,
      dayStartMinutes: initialStartMinutes,
      dayEndMinutes: currentMinutes,
    );
  }

  /// Diagnoses an individual day in the database by [tripId] and [dayId].
  Future<DayFeasibilityReport> diagnoseDay(
    AppDatabase db,
    String tripId,
    String dayId,
  ) async {
    // 1. Fetch trip and day block (with Entity Scope Isolation)
    final trip = await (db.select(db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
    final day = await (db.select(db.tripDays)
          ..where((tbl) => tbl.id.equals(dayId) & tbl.tripId.equals(tripId)))
        .getSingleOrNull();

    if (day == null) {
      return DayFeasibilityReport(
        dayId: dayId,
        stops: const [],
        issues: const [],
        dayStartMinutes: 540,
        dayEndMinutes: 540,
      );
    }

    // Resolve date (pinnedDate on day or trip startDate + day offset)
    DateTime? resolvedDate;
    if (day.pinnedDate != null && day.pinnedDate!.isNotEmpty) {
      resolvedDate = DateTime.tryParse(day.pinnedDate!);
    } else if (trip?.startDate != null && trip!.startDate!.isNotEmpty) {
      final tripStart = DateTime.tryParse(trip.startDate!);
      if (tripStart != null) {
        // Query day index among days ordered by sortKey
        final allDays = await (db.select(db.tripDays)
              ..where((tbl) => tbl.tripId.equals(tripId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
            .get();
        final dayIndex = allDays.indexWhere((d) => d.id == dayId);
        if (dayIndex >= 0) {
          resolvedDate = tripStart.add(Duration(days: dayIndex));
        }
      }
    }

    // 2. Fetch scheduled items for this day
    final items = await (db.select(db.scheduleItems)
          ..where((tbl) => tbl.dayId.equals(dayId) & tbl.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
        .get();

    // 3. Fetch all stops for the trip
    final stopsList = await (db.select(db.stops)
          ..where((tbl) => tbl.tripId.equals(tripId)))
        .get();
    final stopsMap = {for (final s in stopsList) s.id: s};

    return evaluateDayTimeline(
      dayId: dayId,
      dayTitle: day.title,
      date: resolvedDate,
      items: items,
      stopsMap: stopsMap,
    );
  }

  /// Diagnoses all days in a trip and generates a consolidated [TripFeasibilityReport].
  Future<TripFeasibilityReport> diagnoseTrip(
    AppDatabase db,
    String tripId,
  ) async {
    final trip = await (db.select(db.trips)..where((tbl) => tbl.id.equals(tripId))).getSingleOrNull();
    if (trip == null) {
      return TripFeasibilityReport(
        tripId: tripId,
        days: const [],
        allIssues: const [],
      );
    }

    final days = await (db.select(db.tripDays)
          ..where((tbl) => tbl.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
        .get();

    final dayReports = <DayFeasibilityReport>[];
    final allIssues = <FeasibilityIssue>[];

    for (final day in days) {
      final dayReport = await diagnoseDay(db, tripId, day.id);
      dayReports.add(dayReport);
      allIssues.addAll(dayReport.issues);
    }

    return TripFeasibilityReport(
      tripId: tripId,
      days: dayReports,
      allIssues: allIssues,
    );
  }

  /// Calculates geodesic distance between two points in meters using the Haversine formula.
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth radius in meters
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

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
}
