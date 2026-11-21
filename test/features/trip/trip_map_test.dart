import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/trip/models/trip_places_view.dart';
import 'package:trip_planner/shared/theme/app_theme.dart';

/// The trip map's pure parts: the days' colours and the markers.
void main() {
  final t0 = DateTime(2027, 6, 19, 10);

  PlannerDay day(String id, int index, {DateTime? date, bool backup = false}) => PlannerDay(
        day: TripDay(id: id, tripId: 't', sortKey: '$index', updatedAt: t0, syncStatus: 0),
        index: index,
        isBackup: backup,
        date: date,
        pinConflict: false,
        freeDaysBefore: 0,
        items: const [],
      );

  TripPlacesView viewOf(List<PlannerDay> days) => TripPlacesView(
        days: [for (final d in days) PlacesSection(day: d, places: const [])],
        unsorted: const PlacesSection(day: null, places: []),
      );

  group('day colours', () {
    test('tea, wisteria, vermilion, then more, in day order, starting over', () {
      final theme = AppTheme.light;
      final palette = dayPalette(theme);
      expect(palette.take(3), [theme.trip.tea, theme.trip.wisteria, theme.trip.vermilion]);
      expect(palette.length, greaterThan(3));
      final days = [for (var i = 0; i < palette.length + 1; i++) day('d$i', i, date: i < 2 ? t0.add(Duration(days: i)) : null, backup: i >= 2)];
      final colors = dayColors(viewOf(days), palette);
      expect(colors['d0'], theme.trip.tea);
      expect(colors['d1'], theme.trip.wisteria);
      expect(colors['d2'], theme.trip.vermilion);
      expect(colors['d${palette.length}'], theme.trip.tea, reason: 'past the last colour it starts over');
    });

    test('a section takes its day\'s colour; Unsorted is slate', () {
      final theme = AppTheme.light;
      final view = viewOf([day('a', 0, date: t0), day('b', 1, backup: true)]);
      expect(sectionColor(theme, view, view.days[1]), theme.trip.wisteria);
      expect(sectionColor(theme, view, view.unsorted), unsortedColor(theme));
      expect(unsortedColor(theme), isNot(anyOf(dayPalette(theme))));
    });

    test('dark mode has its own shades', () {
      expect(dayPalette(AppTheme.dark).first, AppTheme.dark.trip.tea);
      expect(dayPalette(AppTheme.dark)[3], isNot(dayPalette(AppTheme.light)[3]));
    });
  });
}
