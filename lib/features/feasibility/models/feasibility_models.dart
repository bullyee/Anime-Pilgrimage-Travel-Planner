import '../../../core/database/database.dart';

/// A contiguous time window represented in minutes from midnight (0 = 00:00, 540 = 09:00).
class TimeWindow {
  final int openMinutes;
  final int closeMinutes;

  const TimeWindow({
    required this.openMinutes,
    required this.closeMinutes,
  });

  /// True if [minutes] falls within [[openMinutes], [closeMinutes]).
  bool contains(int minutes) => minutes >= openMinutes && minutes < closeMinutes;

  /// Formats minutes into "HH:mm".
  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formatted string representing the time window (e.g. "09:00 - 18:00").
  String format() => '${formatMinutes(openMinutes)} - ${formatMinutes(closeMinutes)}';

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeWindow &&
          runtimeType == other.runtimeType &&
          openMinutes == other.openMinutes &&
          closeMinutes == other.closeMinutes;

  @override
  int get hashCode => Object.hash(openMinutes, closeMinutes);
}

/// Parsed business / opening hours rule for a pilgrimage location or venue.
class OpeningHoursRule {
  /// Set of days of the week when the venue is open (1 = Monday ... 7 = Sunday).
  final Set<int> openDays;

  /// Set of days explicitly marked as closed / regular holidays (定休日).
  final Set<int> closedDays;

  /// Default time windows applicable to normal open days.
  final List<TimeWindow> defaultWindows;

  /// Day-specific time windows overriding or complementing default windows.
  final Map<int, List<TimeWindow>> daySpecificWindows;

  /// True if open 24 hours (e.g. convenience stores, outdoor public plazas).
  final bool is24Hours;

  /// True if unrestricted outdoor grounds (e.g. temple grounds, natural scenery).
  final bool isAlwaysOpen;

  /// Original raw string from source / user entry.
  final String? rawText;

  const OpeningHoursRule({
    this.openDays = const {1, 2, 3, 4, 5, 6, 7},
    this.closedDays = const {},
    this.defaultWindows = const [],
    this.daySpecificWindows = const {},
    this.is24Hours = false,
    this.isAlwaysOpen = false,
    this.rawText,
  });

  /// Factory for completely unrestricted sites.
  factory OpeningHoursRule.alwaysOpen([String? rawText]) {
    return OpeningHoursRule(
      openDays: const {1, 2, 3, 4, 5, 6, 7},
      isAlwaysOpen: true,
      rawText: rawText,
    );
  }

  /// True if the venue is operating on the specified [date].
  bool isOpenOnDate(DateTime date) {
    if (isAlwaysOpen || is24Hours) return true;
    final weekday = date.weekday;
    if (closedDays.contains(weekday)) return false;
    return openDays.contains(weekday);
  }

  /// Returns the valid [TimeWindow]s for the specified [date].
  List<TimeWindow> getWindowsForDate(DateTime date) {
    if (isAlwaysOpen || is24Hours) {
      return const [TimeWindow(openMinutes: 0, closeMinutes: 1440)];
    }
    if (!isOpenOnDate(date)) return const [];
    return daySpecificWindows[date.weekday] ?? defaultWindows;
  }

  /// Returns true if the venue is open at [timeMinutes] on [date].
  bool isOpenAt(DateTime date, int timeMinutes) {
    if (isAlwaysOpen || is24Hours) return true;
    final windows = getWindowsForDate(date);
    if (windows.isEmpty) return false;
    return windows.any((w) => w.contains(timeMinutes));
  }

  /// Finds the first window opening at or after [timeMinutes] on [date].
  TimeWindow? nextWindowOn(DateTime date, int timeMinutes) {
    final windows = getWindowsForDate(date);
    for (final w in windows) {
      if (w.closeMinutes > timeMinutes) return w;
    }
    return windows.isNotEmpty ? windows.first : null;
  }
}

/// Severity of an itinerary feasibility issue.
enum FeasibilitySeverity {
  /// Critical conflict (e.g. destination is closed, unrecoverable timeline clash).
  error,

  /// Potential issue or warning (e.g. visit shortened by closing, arrive before opening).
  warning,

  /// Informational advisory (e.g. tight transit buffer).
  info,
}

/// Specific type of feasibility issue detected.
enum FeasibilityIssueType {
  /// Closed on the chosen day (e.g. Tuesday 定休日).
  closedOnDay,

  /// Arriving before opening hours (must wait outside).
  arrivesBeforeOpen,

  /// Arriving after venue has already closed for the day.
  arrivesAfterClose,

  /// Planned stay time extends past closing time.
  visitTruncatedByClose,

  /// Travel & prior stop exceeds fixed arrival time.
  timelineOverlap,

  /// Stops are far apart (>500m) but transit time is 0m.
  missingTransitTime,

  /// Overloaded day (excessive stops or > 14 hours duration).
  dayOvercapacity,
}

/// An individual diagnosis issue found within a day or trip schedule.
class FeasibilityIssue {
  final String id;
  final FeasibilityIssueType type;
  final FeasibilitySeverity severity;
  final String dayId;
  final String? scheduleItemId;
  final String? stopId;
  final String stopName;
  final String message;
  final String suggestedFix;

  const FeasibilityIssue({
    required this.id,
    required this.type,
    required this.severity,
    required this.dayId,
    this.scheduleItemId,
    this.stopId,
    required this.stopName,
    required this.message,
    required this.suggestedFix,
  });

  @override
  String toString() => 'FeasibilityIssue($type, $severity): $message';
}

/// A stop on the projected timeline for a single day.
class DayTimelineStop {
  final ScheduleItem scheduleItem;
  final Stop stop;
  final int arrivalMinutes;
  final int departureMinutes;
  final int transitFromPreviousMinutes;
  final double? distanceMetersFromPrevious;
  final List<FeasibilityIssue> issues;

  const DayTimelineStop({
    required this.scheduleItem,
    required this.stop,
    required this.arrivalMinutes,
    required this.departureMinutes,
    required this.transitFromPreviousMinutes,
    this.distanceMetersFromPrevious,
    this.issues = const [],
  });

  bool get hasErrors => issues.any((i) => i.severity == FeasibilitySeverity.error);
  bool get hasWarnings => issues.any((i) => i.severity == FeasibilitySeverity.warning);
}

/// Full diagnosis report for one day block of a trip.
class DayFeasibilityReport {
  final String dayId;
  final String? dayTitle;
  final DateTime? date;
  final List<DayTimelineStop> stops;
  final List<FeasibilityIssue> issues;
  final int dayStartMinutes;
  final int dayEndMinutes;

  const DayFeasibilityReport({
    required this.dayId,
    this.dayTitle,
    this.date,
    required this.stops,
    required this.issues,
    required this.dayStartMinutes,
    required this.dayEndMinutes,
  });

  int get totalDurationMinutes => dayEndMinutes >= dayStartMinutes ? dayEndMinutes - dayStartMinutes : 0;
  bool get isFeasible => issues.every((i) => i.severity != FeasibilitySeverity.error);
  int get errorCount => issues.where((i) => i.severity == FeasibilitySeverity.error).length;
  int get warningCount => issues.where((i) => i.severity == FeasibilitySeverity.warning).length;
}

/// Overall feasibility report across all days of a trip.
class TripFeasibilityReport {
  final String tripId;
  final List<DayFeasibilityReport> days;
  final List<FeasibilityIssue> allIssues;

  const TripFeasibilityReport({
    required this.tripId,
    required this.days,
    required this.allIssues,
  });

  int get errorCount => allIssues.where((i) => i.severity == FeasibilitySeverity.error).length;
  int get warningCount => allIssues.where((i) => i.severity == FeasibilitySeverity.warning).length;
  bool get isFeasible => errorCount == 0;
}
