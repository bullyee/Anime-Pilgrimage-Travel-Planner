import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/trip/services/trip_route_export_service.dart';

void main() {
  const service = TripRouteExportService();

  Trip makeTrip({
    String id = 'trip-1',
    String title = 'Kyoto Anime Tour',
    String? description = 'Visiting Hibike! & K-On! spots',
    String? startDate,
  }) {
    return Trip(
      id: id,
      title: title,
      description: description,
      ownerId: 'u1',
      sharing: 'private',
      startDate: startDate ?? '2026-05-01',
      dayCount: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      syncStatus: 0,
    );
  }

  Stop makeStop({
    required String id,
    required String name,
    double lat = 34.89,
    double lng = 135.80,
    String? note,
    String? address,
    String? description,
  }) {
    return Stop(
      id: id,
      tripId: 'trip-1',
      placeKey: 'k_$id',
      name: name,
      lat: lat,
      lng: lng,
      description: description,
      address: address,
      note: note,
      addedBy: 'u1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      syncStatus: 0,
    );
  }

  PlannerItem makeItem({
    required String itemId,
    required Stop stop,
    int startMinutes = 540, // 09:00
    int endMinutes = 600,
  }) {
    return PlannerItem(
      item: ScheduleItem(
        id: itemId,
        tripId: 'trip-1',
        stopId: stop.id,
        dayId: 'day-1',
        sortKey: 'a0',
        stayMinutes: 60,
        transitMinutes: 15,
        status: 'planned',
        updatedAt: DateTime.utc(2026, 1, 1),
        syncStatus: 0,
      ),
      stop: stop,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      fixed: false,
      conflict: false,
    );
  }

  PlannerDay makeDay({
    String id = 'day-1',
    int index = 0,
    bool isBackup = false,
    DateTime? date,
    List<PlannerItem> items = const [],
  }) {
    final dateStr = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : null;
    return PlannerDay(
      day: TripDay(
        id: id,
        tripId: 'trip-1',
        sortKey: 'a$index',
        pinnedDate: dateStr,
        updatedAt: DateTime.utc(2026, 1, 1),
        syncStatus: 0,
      ),
      index: index,
      isBackup: isBackup,
      date: date ?? DateTime.utc(2026, 5, 1),
      pinConflict: false,
      freeDaysBefore: 0,
      items: items,
    );
  }

  group('TripRouteExportService.slugify', () {
    test('cleans English titles with spaces and dashes', () {
      expect(TripRouteExportService.slugify('Kyoto Anime Tour 2026'), 'Kyoto_Anime_Tour_2026');
      expect(TripRouteExportService.slugify('My-Trip--Name'), 'My-Trip--Name');
    });

    test('preserves Japanese Kanji and Kana', () {
      expect(TripRouteExportService.slugify('響け！ユーフォニアム 聖地巡礼'), '響けユーフォニアム_聖地巡礼');
    });

    test('falls back to "trip" when title has only special characters or is empty', () {
      expect(TripRouteExportService.slugify(''), 'trip');
      expect(TripRouteExportService.slugify('!@#\$%^&*()'), 'trip');
      expect(TripRouteExportService.slugify('   '), 'trip');
    });
  });

  group('TripRouteExportService.hasValidCoordinates', () {
    test('returns false for (0.0, 0.0)', () {
      expect(TripRouteExportService.hasValidCoordinates(0.0, 0.0), isFalse);
    });

    test('returns false for out-of-range coordinates', () {
      expect(TripRouteExportService.hasValidCoordinates(91.0, 135.0), isFalse);
      expect(TripRouteExportService.hasValidCoordinates(-91.0, 135.0), isFalse);
      expect(TripRouteExportService.hasValidCoordinates(35.0, 181.0), isFalse);
      expect(TripRouteExportService.hasValidCoordinates(35.0, -181.0), isFalse);
    });

    test('returns true for valid coordinates', () {
      expect(TripRouteExportService.hasValidCoordinates(34.89, 135.80), isTrue);
      expect(TripRouteExportService.hasValidCoordinates(-33.86, 151.20), isTrue);
    });
  });

  group('GPX Export', () {
    test('generates valid GPX 1.1 structure with waypoints and routes', () {
      final trip = makeTrip(title: 'Kyoto Tour');
      final stop1 = makeStop(id: 's1', name: 'Uji Bridge', lat: 34.890, lng: 135.810, note: 'Opening scene');
      final stop2 = makeStop(id: 's2', name: 'Mount Daikichi', lat: 34.895, lng: 135.815);
      final item1 = makeItem(itemId: 'i1', stop: stop1, startMinutes: 540); // 09:00
      final item2 = makeItem(itemId: 'i2', stop: stop2, startMinutes: 660); // 11:00
      final day1 = makeDay(id: 'd1', index: 0, date: DateTime.utc(2026, 5, 1), items: [item1, item2]);

      final view = PlannerView(trip: trip, days: [day1], backlog: []);
      final result = service.exportGpx(
        trip: trip,
        plannerView: view,
        exportedAt: DateTime.utc(2026, 5, 1, 8, 0, 0),
      );

      expect(result.fileName, 'Kyoto_Tour-route.gpx');
      expect(result.mimeType, 'application/gpx+xml');
      expect(result.stopCount, 2);
      expect(result.skippedCount, 0);

      final xml = result.content;
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<gpx version="1.1" creator="Trip Planner"'));
      expect(xml, contains('<metadata>'));
      expect(xml, contains('<name>Kyoto Tour</name>'));
      expect(xml, contains('<time>2026-05-01T08:00:00.000Z</time>'));

      // Waypoints
      expect(xml, contains('<wpt lat="34.89" lon="135.81">'));
      expect(xml, contains('<name>Uji Bridge</name>'));
      expect(xml, contains('<desc>Opening scene</desc>'));
      expect(xml, contains('<time>2026-05-01T09:00:00.000Z</time>'));
      expect(xml, contains('<wpt lat="34.895" lon="135.815">'));
      expect(xml, contains('<name>Mount Daikichi</name>'));

      // Routes
      expect(xml, contains('<rte>'));
      expect(xml, contains('<name>Day 1 (2026-05-01)</name>'));
      expect(xml, contains('<number>1</number>'));
      expect(xml, contains('<rtept lat="34.89" lon="135.81">'));
      expect(xml, contains('<rtept lat="34.895" lon="135.815">'));
      expect(xml.endsWith('</gpx>'), isTrue);
    });

    test('escapes XML special characters in all text fields', () {
      final trip = makeTrip(
        title: 'Ben & Jerry\'s <Tokyo> "Special"',
        description: 'Testing <tag> & "quotes" & \'apos\'',
      );
      final stop = makeStop(
        id: 's1',
        name: 'Spot <A> & "B"',
        note: 'Note with <markup> & "quotes"',
      );
      final item = makeItem(itemId: 'i1', stop: stop);
      final day = makeDay(items: [item]);
      final view = PlannerView(trip: trip, days: [day], backlog: []);

      final result = service.exportGpx(trip: trip, plannerView: view);
      final xml = result.content;

      expect(xml, contains('<name>Ben &amp; Jerry&apos;s &lt;Tokyo&gt; &quot;Special&quot;</name>'));
      expect(xml, contains('<desc>Testing &lt;tag&gt; &amp; &quot;quotes&quot; &amp; &apos;apos&apos;</desc>'));
      expect(xml, contains('<name>Spot &lt;A&gt; &amp; &quot;B&quot;</name>'));
      expect(xml, contains('<desc>Note with &lt;markup&gt; &amp; &quot;quotes&quot;</desc>'));
    });

    test('skips stops with (0.0, 0.0) coordinates and reports skipped count', () {
      final trip = makeTrip();
      final validStop = makeStop(id: 's1', name: 'Valid Stop', lat: 35.0, lng: 135.0);
      final noCoordsStop = makeStop(id: 's2', name: 'No Coords', lat: 0.0, lng: 0.0);
      final outOfBoundsStop = makeStop(id: 's3', name: 'Out of bounds', lat: 99.0, lng: 200.0);

      final item1 = makeItem(itemId: 'i1', stop: validStop);
      final item2 = makeItem(itemId: 'i2', stop: noCoordsStop);
      final item3 = makeItem(itemId: 'i3', stop: outOfBoundsStop);
      final day = makeDay(items: [item1, item2, item3]);

      final view = PlannerView(trip: trip, days: [day], backlog: []);
      final result = service.exportGpx(trip: trip, plannerView: view);

      expect(result.stopCount, 1);
      expect(result.skippedCount, 2);
      expect(result.content, contains('Valid Stop'));
      expect(result.content, isNot(contains('No Coords')));
      expect(result.content, isNot(contains('Out of bounds')));
    });

    test('includes backlog stops with coordinates as waypoints without schedule time', () {
      final trip = makeTrip();
      final scheduledStop = makeStop(id: 's1', name: 'Scheduled', lat: 35.1, lng: 135.1);
      final backlogStop = makeStop(id: 's2', name: 'Backlog Spot', lat: 35.2, lng: 135.2, note: 'Maybe visit');
      final backlogNoCoord = makeStop(id: 's3', name: 'Backlog No Coord', lat: 0.0, lng: 0.0);

      final day = makeDay(items: [makeItem(itemId: 'i1', stop: scheduledStop)]);
      final view = PlannerView(trip: trip, days: [day], backlog: [backlogStop, backlogNoCoord]);

      final result = service.exportGpx(trip: trip, plannerView: view);

      expect(result.stopCount, 2);
      expect(result.skippedCount, 1);
      expect(result.content, contains('<name>Backlog Spot</name>'));
      expect(result.content, contains('<desc>Maybe visit</desc>'));
      // Backlog stop has no <time>
      expect(result.content, isNot(contains('<wpt lat="35.2" lon="135.2">\n    <name>Backlog Spot</name>\n    <desc>Maybe visit</desc>\n    <time>')));
    });

    test('deduplicates waypoints when a stop appears on multiple days but preserves in routes', () {
      final trip = makeTrip();
      final repeatedStop = makeStop(id: 's1', name: 'Kyoto Station', lat: 34.985, lng: 135.758);
      final otherStop = makeStop(id: 's2', name: 'Fushimi Inari', lat: 34.967, lng: 135.772);

      final day1 = makeDay(id: 'd1', index: 0, date: DateTime.utc(2026, 5, 1), items: [
        makeItem(itemId: 'i1', stop: repeatedStop, startMinutes: 540),
        makeItem(itemId: 'i2', stop: otherStop, startMinutes: 600),
      ]);
      final day2 = makeDay(id: 'd2', index: 1, date: DateTime.utc(2026, 5, 2), items: [
        makeItem(itemId: 'i3', stop: repeatedStop, startMinutes: 540),
      ]);

      final view = PlannerView(trip: trip, days: [day1, day2], backlog: []);
      final result = service.exportGpx(trip: trip, plannerView: view);

      expect(result.stopCount, 2);
      // <wpt> for Kyoto Station should only appear once
      final wptMatches = RegExp(r'<wpt lat="34.985" lon="135.758">').allMatches(result.content);
      expect(wptMatches.length, 1);

      // <rtept> for Kyoto Station should appear in both day routes
      final rteptMatches = RegExp(r'<rtept lat="34.985" lon="135.758">').allMatches(result.content);
      expect(rteptMatches.length, 2);
    });
  });

  group('GeoJSON Export', () {
    test('generates valid GeoJSON FeatureCollection', () {
      final trip = makeTrip(title: 'Hibike Tour');
      final stop1 = makeStop(
        id: 's1',
        name: 'Uji River',
        lat: 34.89,
        lng: 135.80,
        address: 'Uji, Kyoto',
        note: 'Bench scene',
      );
      final stop2 = makeStop(id: 's2', name: 'No Coord', lat: 0.0, lng: 0.0);
      final item1 = makeItem(itemId: 'i1', stop: stop1, startMinutes: 600); // 10:00
      final item2 = makeItem(itemId: 'i2', stop: stop2);
      final day = makeDay(date: DateTime.utc(2026, 5, 1), items: [item1, item2]);

      final view = PlannerView(trip: trip, days: [day], backlog: []);
      final result = service.exportGeoJson(trip: trip, plannerView: view);

      expect(result.fileName, 'Hibike_Tour-route.geojson');
      expect(result.mimeType, 'application/geo+json');
      expect(result.stopCount, 1);
      expect(result.skippedCount, 1);

      final decoded = jsonDecode(result.content) as Map<String, dynamic>;
      expect(decoded['type'], 'FeatureCollection');
      expect(decoded['name'], 'Hibike Tour');

      final features = decoded['features'] as List;
      expect(features.length, 1);

      final feature = features[0] as Map<String, dynamic>;
      expect(feature['type'], 'Feature');

      // Coordinates MUST be [lng, lat]
      final geom = feature['geometry'] as Map<String, dynamic>;
      expect(geom['type'], 'Point');
      expect(geom['coordinates'], [135.80, 34.89]);

      final props = feature['properties'] as Map<String, dynamic>;
      expect(props['day'], 1);
      expect(props['order'], 1);
      expect(props['name'], 'Uji River');
      expect(props['time'], '2026-05-01T10:00:00.000Z');
      expect(props['notes'], 'Bench scene');
      expect(props['address'], 'Uji, Kyoto');
    });

    test('includes backlog stops in GeoJSON with day = null', () {
      final trip = makeTrip();
      final backlogStop = makeStop(id: 's1', name: 'Backlog Spot', lat: 35.0, lng: 135.5, note: 'Maybe visit');
      final view = PlannerView(trip: trip, days: [], backlog: [backlogStop]);

      final result = service.exportGeoJson(trip: trip, plannerView: view);
      expect(result.stopCount, 1);

      final decoded = jsonDecode(result.content) as Map<String, dynamic>;
      final features = decoded['features'] as List;
      expect(features.length, 1);

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['day'], isNull);
      expect(props['order'], 1);
      expect(props['name'], 'Backlog Spot');
      expect(props['notes'], 'Maybe visit');
    });
  });

  group('Adversarial & Edge Cases (Rule 1 & Rule 2)', () {
    test('empty trip produces valid output with 0 stops', () {
      final trip = makeTrip(title: 'Empty Trip');
      final view = PlannerView(trip: trip, days: [], backlog: []);

      final gpxResult = service.exportGpx(trip: trip, plannerView: view);
      expect(gpxResult.stopCount, 0);
      expect(gpxResult.skippedCount, 0);
      expect(gpxResult.content, contains('<metadata>'));
      expect(gpxResult.content, isNot(contains('<wpt')));
      expect(gpxResult.content, isNot(contains('<rte')));

      final geoResult = service.exportGeoJson(trip: trip, plannerView: view);
      expect(geoResult.stopCount, 0);
      expect(geoResult.skippedCount, 0);
      final decoded = jsonDecode(geoResult.content) as Map<String, dynamic>;
      expect(decoded['features'], isEmpty);
    });

    test('trip where all stops have no coordinates produces stopCount 0', () {
      final trip = makeTrip();
      final s1 = makeStop(id: 's1', name: 'Spot 1', lat: 0.0, lng: 0.0);
      final s2 = makeStop(id: 's2', name: 'Spot 2', lat: 0.0, lng: 0.0);
      final day = makeDay(items: [
        makeItem(itemId: 'i1', stop: s1),
        makeItem(itemId: 'i2', stop: s2),
      ]);
      final view = PlannerView(trip: trip, days: [day], backlog: []);

      final gpxResult = service.exportGpx(trip: trip, plannerView: view);
      expect(gpxResult.stopCount, 0);
      expect(gpxResult.skippedCount, 2);

      final geoResult = service.exportGeoJson(trip: trip, plannerView: view);
      expect(geoResult.stopCount, 0);
      expect(geoResult.skippedCount, 2);
    });

    test('handles emojis and extreme unicode characters in titles and descriptions', () {
      final trip = makeTrip(
        title: '⛩️ 宇治の聖地巡礼 🌸 2026',
        description: '響け！ユーフォニアム🎵 & 涼宮ハルヒの憂鬱✨',
      );
      final stop = makeStop(
        id: 's1',
        name: '久美子ベンチ 🎷',
        lat: 34.89,
        lng: 135.80,
        note: '黃昏時的對話 🌅',
      );
      final day = makeDay(items: [makeItem(itemId: 'i1', stop: stop)]);
      final view = PlannerView(trip: trip, days: [day], backlog: []);

      final gpxResult = service.exportGpx(trip: trip, plannerView: view);
      expect(gpxResult.content, contains('久美子ベンチ 🎷'));
      expect(gpxResult.content, contains('黃昏時的對話 🌅'));
      expect(gpxResult.fileName, contains('宇治の聖地巡礼'));

      final geoResult = service.exportGeoJson(trip: trip, plannerView: view);
      final decoded = jsonDecode(geoResult.content) as Map<String, dynamic>;
      expect(decoded['name'], '⛩️ 宇治の聖地巡礼 🌸 2026');
      final feature = (decoded['features'] as List)[0] as Map<String, dynamic>;
      expect(feature['properties']['name'], '久美子ベンチ 🎷');
      expect(feature['properties']['notes'], '黃昏時的對話 🌅');
    });
  });
}
