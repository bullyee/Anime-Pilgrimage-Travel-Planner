import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/trip/models/place_spots.dart';
import 'package:trip_planner/features/trip/models/trip_places_view.dart';
import 'package:trip_planner/features/trip/screens/trip_map_view.dart';
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

  group('markers', () {
    Stop stop(String id, String name, {double lat = 34.892, double lng = 135.8075}) => Stop(
          id: id,
          tripId: 't',
          placeKey: 'p-$id',
          name: name,
          lat: lat,
          lng: lng,
          addedBy: 'u1',
          createdAt: t0,
          updatedAt: t0,
          syncStatus: 0,
        );
    NewReferenceImage frame(String id, String stopId, {String? note, double? lat, double? lng}) =>
        NewReferenceImage(id: id, localPath: '$id.png', note: note, lat: lat, lng: lng, stopId: stopId, createdAt: t0);

    // 宇治橋: two spots (東詰 with two frames, one of them shot; 西詰 with
    // one). 平等院: no frames, so one spot at the stop.
    final uji = stop('uji', '宇治橋');
    final byodoin = stop('byo', '平等院', lat: 34.889, lng: 135.808);
    final index = TripFrameIndex(
      own: [
        frame('f1', 'uji', note: '東詰', lat: 34.8921, lng: 135.8078),
        frame('f2', 'uji', note: '東詰', lat: 34.8921, lng: 135.8078),
        frame('f3', 'uji', note: '西詰', lat: 34.8918, lng: 135.8069),
      ],
      library: const [],
      photos: [
        Photo(id: 'ph', placeKey: 'p-uji', kind: 'original', referenceImageId: 'f1', localPath: 'ph.jpg', isShared: false, keepAsIs: false, createdAt: t0),
      ],
    );
    final section = PlacesSection(day: day('d1', 0, date: t0), places: const []);
    TripMapPlace place(Stop s, Color color) => TripMapPlace(
          place: TripPlace(id: s.id, name: s.name, stops: [s]),
          content: index.place([s]),
          section: section,
          color: color,
        );
    final places = [place(uji, Colors.teal), place(byodoin, Colors.purple)];

    test('one pin per place, with its picture, frame count and colour', () {
      final m = tripMapMarkers(places, spots: false, selectedPlace: 'byo', face: (p) => Text(p.id));
      expect(m.pins.map((p) => p.id), ['place:uji', 'place:byo']);
      expect(m.pins.map((p) => p.badge), [3, 0]);
      expect(m.pins.map((p) => p.color), [Colors.teal, Colors.purple]);
      expect((m.pins.first.face! as Text).data, 'uji');
      expect(m.pins.map((p) => p.selected), [false, true]);
      expect(m.pins.first.point.latitude, uji.lat, reason: 'at the place');
      expect(m.labels, isEmpty);
      expect(m.targets['place:uji'], (placeId: 'uji', spotKey: null));
    });

    test("zoomed in, a pin per spot, done when shot, and the places' names as labels", () {
      final ujiSpots = places.first.content.spots;
      expect(ujiSpots.map((s) => s.label), ['東詰', '西詰']);
      final m = tripMapMarkers(places, spots: true, selectedPlace: 'uji', selectedSpot: ujiSpots[1].key);
      expect(m.pins.map((p) => p.id), ['spot:uji:${ujiSpots[0].key}', 'spot:uji:${ujiSpots[1].key}', 'spot:byo:stop:byo']);
      expect(m.pins.map((p) => p.name), ['東詰', '西詰', '平等院']);
      expect(m.pins.map((p) => p.done), [true, false, false], reason: '東詰 has a shot frame');
      expect(m.pins.map((p) => p.selected), [false, true, false]);
      expect(m.pins.every((p) => p.face == null), isTrue);
      expect(m.pins[1].point.latitude, closeTo(34.8918, 1e-9), reason: 'at the spot, not the place');
      expect(m.labels.map((l) => l.name), ['宇治橋', '平等院']);
      expect(m.targets[m.pins[1].id], (placeId: 'uji', spotKey: ujiSpots[1].key));
    });

    test('tripMapPlaces keeps list order, each place once, and filters to a day', () {
      final a = TripPlace(id: 'uji', name: '宇治橋', stops: [uji]);
      final b = TripPlace(id: 'byo', name: '平等院', stops: [byodoin]);
      final view = TripPlacesView(
        days: [
          PlacesSection(day: day('d1', 0, date: t0), places: [a]),
          PlacesSection(day: day('d2', 1, date: t0.add(const Duration(days: 1))), places: [b, a]),
        ],
        unsorted: const PlacesSection(day: null, places: []),
      );
      final contents = {'uji': index.place([uji]), 'byo': index.place([byodoin])};
      Color colorOf(PlacesSection s) => s.dayId == 'd1' ? Colors.teal : Colors.purple;
      expect(tripMapPlaces(view, contents, colorOf).map((p) => (p.id, p.color)), [('uji', Colors.teal), ('byo', Colors.purple)]);
      expect(tripMapPlaces(view, contents, colorOf, dayId: 'd2').map((p) => p.id), ['byo', 'uji'], reason: "the day's order, for its route");
    });

    test('a group not folded yet that sits on two days is one place in all, with a card on each day', () {
      final east = stop('east', '宇治橋 東詰');
      final west = stop('west', '宇治橋 西詰');
      final onDay1 = TripPlace(id: 'east', name: '宇治橋', group: '宇治橋', stops: [east]);
      final onDay2 = TripPlace(id: 'west', name: '宇治橋', group: '宇治橋', stops: [west]);
      final b = TripPlace(id: 'byo', name: '平等院', stops: [byodoin]);
      final view = TripPlacesView(
        days: [
          PlacesSection(day: day('d1', 0, date: t0), places: [onDay1]),
          PlacesSection(day: day('d2', 1, date: t0.add(const Duration(days: 1))), places: [b, onDay2]),
        ],
        unsorted: PlacesSection(day: null, places: [b]),
      );
      expect(view.all.map((p) => p.id), ['east', 'byo'], reason: 'the group where it comes first, and a stop once');
      expect(view.everyCard.map((p) => p.id), ['east', 'byo', 'west', 'byo']);
    });
  });
}
