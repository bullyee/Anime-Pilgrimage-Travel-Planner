import '../models/feasibility_models.dart';

/// Robust parser for diverse business and opening hours strings found in
/// anime pilgrimage spots, Japanese tourist destinations, and OpenStreetMap data.
class OpeningHoursParser {
  const OpeningHoursParser._();

  static final RegExp _alwaysOpenRegex = RegExp(
    r'(年中無休|24時間|24 hours|24/7|境内自由|見学自由|参拝自由|散策自由|終日|終日開放)',
    caseSensitive: false,
  );

  static final RegExp _closedDayJpRegex = RegExp(
    r'定休(?:日)?[:：\s]*([月火水木金土日,、\s・/及]+)(?:曜日)?',
  );

  static final RegExp _closedDayEnRegex = RegExp(
    r'(?:closed|off)[:：\s]*([a-z,\s/]+)',
    caseSensitive: false,
  );

  static final RegExp _timeRangeRegex = RegExp(
    r'(\d{1,2}):(\d{2})\s*[-~～〜至到–—]\s*(\d{1,2}):(\d{2})',
  );

  static const Map<String, int> _jpWeekdayMap = {
    '月': 1,
    '火': 2,
    '水': 3,
    '木': 4,
    '金': 5,
    '土': 6,
    '日': 7,
  };

  static const Map<String, int> _enWeekdayMap = {
    'mon': 1,
    'monday': 1,
    'mo': 1,
    'tue': 2,
    'tuesday': 2,
    'tu': 2,
    'wed': 3,
    'wednesday': 3,
    'we': 3,
    'thu': 4,
    'thursday': 4,
    'th': 4,
    'fri': 5,
    'friday': 5,
    'fr': 5,
    'sat': 6,
    'saturday': 6,
    'sa': 6,
    'sun': 7,
    'sunday': 7,
    'su': 7,
  };

  /// Parses a business hours text string into a structured [OpeningHoursRule].
  ///
  /// Returns null if the text is null or blank. Never throws on unparseable input;
  /// falls back to [OpeningHoursRule.alwaysOpen] if no restrictions can be determined.
  static OpeningHoursRule? parse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final trimmed = text.trim();

    // Check for unrestricted / 24-hour indicators
    if (_alwaysOpenRegex.hasMatch(trimmed)) {
      final is24 = trimmed.contains('24') || trimmed.contains('終日');
      return OpeningHoursRule(
        openDays: const {1, 2, 3, 4, 5, 6, 7},
        isAlwaysOpen: !is24,
        is24Hours: is24,
        rawText: trimmed,
      );
    }

    final closedDays = <int>{};
    final openDays = <int>{1, 2, 3, 4, 5, 6, 7};
    final defaultWindows = <TimeWindow>[];
    final daySpecificWindows = <int, List<TimeWindow>>{};

    // 1. Extract closed days (定休日) in Japanese
    final jpClosedMatch = _closedDayJpRegex.firstMatch(trimmed);
    if (jpClosedMatch != null) {
      final daysStr = jpClosedMatch.group(1) ?? '';
      for (final char in daysStr.split('')) {
        final dayNum = _jpWeekdayMap[char];
        if (dayNum != null) {
          closedDays.add(dayNum);
        }
      }
    }

    // 2. Extract closed days in English
    final enClosedMatch = _closedDayEnRegex.firstMatch(trimmed);
    if (enClosedMatch != null) {
      final daysStr = enClosedMatch.group(1) ?? '';
      for (final token in daysStr.toLowerCase().split(RegExp(r'[,/\s]+'))) {
        final dayNum = _enWeekdayMap[token];
        if (dayNum != null) {
          closedDays.add(dayNum);
        }
      }
    }

    // 3. Extract all time ranges
    final timeMatches = _timeRangeRegex.allMatches(trimmed).toList();
    for (final match in timeMatches) {
      final startH = int.tryParse(match.group(1)!) ?? 0;
      final startM = int.tryParse(match.group(2)!) ?? 0;
      final endH = int.tryParse(match.group(3)!) ?? 0;
      final endM = int.tryParse(match.group(4)!) ?? 0;

      final openMin = startH * 60 + startM;
      var closeMin = endH * 60 + endM;

      // Handle overnight / early morning closures (e.g. 18:00 - 02:00 -> 18:00 - 26:00)
      if (closeMin < openMin && endH < 12) {
        closeMin += 1440;
      }

      if (closeMin > openMin) {
        defaultWindows.add(TimeWindow(openMinutes: openMin, closeMinutes: closeMin));
      }
    }

    // Remove explicitly closed days from open days
    for (final c in closedDays) {
      openDays.remove(c);
    }

    // If no time windows were extracted, but closed days exist, assume regular day hours (09:00 - 18:00)
    if (defaultWindows.isEmpty && closedDays.isNotEmpty) {
      defaultWindows.add(const TimeWindow(openMinutes: 540, closeMinutes: 1080));
    }

    return OpeningHoursRule(
      openDays: openDays,
      closedDays: closedDays,
      defaultWindows: defaultWindows,
      daySpecificWindows: daySpecificWindows,
      is24Hours: false,
      isAlwaysOpen: defaultWindows.isEmpty && closedDays.isEmpty,
      rawText: trimmed,
    );
  }
}
