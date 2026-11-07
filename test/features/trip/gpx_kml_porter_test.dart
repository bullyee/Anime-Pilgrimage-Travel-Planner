import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/trip/models/gpx_kml_models.dart';
import 'package:trip_planner/features/trip/services/gpx_kml_porter_service.dart';

void main() {
  group('GpxKmlPorterService - XML & Serialization Unit Tests', () {
    const porter = GpxKmlPorterService();

    test('XML escaping and unescaping handles special characters and Japanese text', () {
      const raw = '<tag attr="val">Kyoto & Uji: 響け！ユーフォニアム \'Sound! Euphonium\' ⛩️</tag>';
      final escaped = GpxKmlPorterService.escapeXml(raw);
      expect(escaped, contains('&lt;tag attr=&quot;val&quot;&gt;'));
      expect(escaped, contains('Kyoto &amp; Uji: 響け！ユーフォニアム &apos;Sound! Euphonium&apos; ⛩️'));

      final unescaped = GpxKmlPorterService.unescapeXml(escaped);
      expect(unescaped, equals(raw));
    });

    test('extractContent extracts CDATA without unescaping inside', () {
      const cdata = '<description><![CDATA[<h3>Title & Subtitle</h3>]]></description>';
      final content = GpxKmlPorterService.getTagContent(cdata, 'description');
      expect(content, equals('<h3>Title & Subtitle</h3>'));
    });

    test('GPX roundtrip: builds well-formed GPX and parses back accurately', () {
      final doc = GpxDocument(
        name: 'Kyoto Pilgrimage Track',
        description: 'Pilgrimage spots for Tamako Market & Hibike! Euphonium',
        author: 'Bullyee',
        creator: 'Anime Pilgrimage Travel Planner',
        time: DateTime.utc(2026, 11, 7, 10, 0, 0),
        waypoints: [
          const GpxWaypoint(
            lat: 35.0116,
            lng: 135.7681,
            elevation: 45.5,
            name: 'Demachi Masugata Shotengai',
            description: 'Shopping street featured in Tamako Market',
            comment: 'Buy mochi at the flower shop entrance',
            symbol: 'Shop',
            source: 'Anitabi',
            extensions: {
              'animeTitle': 'Tamako Market',
              'placeKey': 'anitabi_tamako_01',
              'stayMinutes': '45',
            },
          ),
          const GpxWaypoint(
            lat: 34.8894,
            lng: 135.8078,
            name: 'Uji Bridge',
            description: 'Iconic spot from Hibike! Euphonium',
            extensions: {
              'animeTitle': 'Hibike! Euphonium',
              'placeKey': 'anitabi_eupho_01',
            },
          ),
        ],
        routes: [
          const GpxRoute(
            name: 'Day 1 Route',
            description: 'Morning in Demachiyanagi',
            number: '1',
            points: [
              GpxWaypoint(
                lat: 35.0116,
                lng: 135.7681,
                name: 'Demachi Masugata Shotengai',
              ),
            ],
          ),
        ],
        tracks: [
          const GpxTrack(
            name: 'Walking Track',
            segments: [
              GpxTrackSegment(points: [
                GpxWaypoint(lat: 35.0116, lng: 135.7681),
                GpxWaypoint(lat: 35.0120, lng: 135.7690),
              ]),
            ],
          ),
        ],
      );

      final xml = porter.buildGpx(doc);
      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<gpx version="1.1"'));
      expect(xml, contains('<name>Kyoto Pilgrimage Track</name>'));
      expect(xml, contains('<wpt lat="35.0116" lon="135.7681">'));
      expect(xml, contains('<animeTitle>Tamako Market</animeTitle>'));
      expect(xml, contains('<rte>'));
      expect(xml, contains('<trk>'));

      final parsed = porter.parseGpx(xml);
      expect(parsed.name, equals('Kyoto Pilgrimage Track'));
      expect(parsed.description, equals('Pilgrimage spots for Tamako Market & Hibike! Euphonium'));
      expect(parsed.author, equals('Bullyee'));
      expect(parsed.waypoints.length, equals(2));

      final wpt1 = parsed.waypoints[0];
      expect(wpt1.name, equals('Demachi Masugata Shotengai'));
      expect(wpt1.lat, closeTo(35.0116, 0.0001));
      expect(wpt1.lng, closeTo(135.7681, 0.0001));
      expect(wpt1.elevation, closeTo(45.5, 0.001));
      expect(wpt1.comment, equals('Buy mochi at the flower shop entrance'));
      expect(wpt1.extensions['animeTitle'], equals('Tamako Market'));
      expect(wpt1.extensions['placeKey'], equals('anitabi_tamako_01'));

      expect(parsed.routes.length, equals(1));
      expect(parsed.routes[0].name, equals('Day 1 Route'));
      expect(parsed.routes[0].points.length, equals(1));

      expect(parsed.tracks.length, equals(1));
      expect(parsed.tracks[0].segments.length, equals(1));
      expect(parsed.tracks[0].segments[0].points.length, equals(2));

      // Test allPoints getter
      expect(parsed.allPoints.length, equals(5)); // 2 waypoints + 1 route point + 2 track points
    });

    test('KML roundtrip: builds well-formed KML with Folders & LineStrings, parses back accurately', () {
      final doc = KmlDocument(
        name: 'Kyoto Anime Tour',
        description: 'Complete pilgrimage route',
        folders: [
          const KmlFolder(
            name: 'Day 1 - Demachi & Uji',
            description: 'First day schedule',
            placemarks: [
              KmlPlacemark(
                id: 'stop_1',
                name: 'Demachi Masugata Shotengai',
                description: '<h3>Tamako Market</h3><p>Arcade</p>',
                lat: 35.0116,
                lng: 135.7681,
                elevation: 40.0,
                extendedData: {
                  'animeTitle': 'Tamako Market',
                  'placeKey': 'place_demachi',
                },
              ),
              KmlPlacemark(
                id: 'stop_2',
                name: 'Uji River Bank',
                description: 'Kumiko and Reina concert spot',
                lat: 34.8900,
                lng: 135.8100,
                extendedData: {
                  'animeTitle': 'Hibike! Euphonium',
                },
              ),
            ],
            paths: [
              KmlLineString(
                name: 'Day 1 Transit Line',
                coordinates: [
                  GeoPoint(lat: 35.0116, lng: 135.7681),
                  GeoPoint(lat: 34.8900, lng: 135.8100),
                ],
              ),
            ],
          ),
        ],
      );

      final xml = porter.buildKml(doc);
      expect(xml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect(xml, contains('<Document>'));
      expect(xml, contains('<name>Kyoto Anime Tour</name>'));
      expect(xml, contains('<Folder>'));
      expect(xml, contains('<coordinates>135.7681,35.0116,40.0</coordinates>')); // KML is lng,lat,ele!
      expect(xml, contains('<LineString>'));

      final parsed = porter.parseKml(xml);
      expect(parsed.name, equals('Kyoto Anime Tour'));
      expect(parsed.folders.length, equals(1));

      final folder = parsed.folders[0];
      expect(folder.name, equals('Day 1 - Demachi & Uji'));
      expect(folder.placemarks.length, equals(2));

      final pm1 = folder.placemarks[0];
      expect(pm1.name, equals('Demachi Masugata Shotengai'));
      expect(pm1.lat, closeTo(35.0116, 0.0001));
      expect(pm1.lng, closeTo(135.7681, 0.0001));
      expect(pm1.elevation, closeTo(40.0, 0.01));
      expect(pm1.extendedData['animeTitle'], equals('Tamako Market'));

      expect(folder.paths.length, equals(1));
      expect(folder.paths[0].coordinates.length, equals(2));
      expect(folder.paths[0].coordinates[0].lng, closeTo(135.7681, 0.0001));
      expect(folder.paths[0].coordinates[0].lat, closeTo(35.0116, 0.0001));
    });

    test('Adversarial GPX parsing handles missing tags, attributes in reverse order, and invalid coords', () {
      const dirtyXml = '''
      <gpx version="1.1" creator="ExternalApp">
        <!-- Reverse order lat/lon and single quotes -->
        <wpt lon='135.7681' lat='35.0116'>
          <name>Valid Point</name>
        </wpt>
        <!-- Invalid latitude > 90 -->
        <wpt lat="120.0" lon="135.0">
          <name>Out of Bounds Latitude</name>
        </wpt>
        <!-- Empty point with self closing tag or missing coords -->
        <wpt lat="35.0" lon="invalid_number">
          <name>Corrupt Lon</name>
        </wpt>
      </gpx>
      ''';

      final parsed = porter.parseGpx(dirtyXml);
      expect(parsed.waypoints.length, equals(2)); // Corrupt Lon returns null, Out of Bounds parsed into model
      expect(parsed.waypoints[0].name, equals('Valid Point'));
      expect(parsed.waypoints[0].isValid, isTrue);

      expect(parsed.waypoints[1].name, equals('Out of Bounds Latitude'));
      expect(parsed.waypoints[1].isValid, isFalse); // model detects lat > 90
    });
  });

  group('GpxKmlPorterService - SQLite Database Integration & Scope Isolation Tests', () {
    late AppDatabase db;
    late GpxKmlPorterService porter;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      porter = const GpxKmlPorterService();

      // Seed a trip
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_kyoto_2026',
            title: 'Kyoto Anime Odyssey',
            ownerId: 'user_alice',
            description: const Value('Visiting classic anime scenes in Kyoto & Uji'),
            startDate: const Value('2026-11-07'),
            dayCount: const Value(2),
          ));

      // Seed Day 1 & Day 2
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_1',
            tripId: 'trip_kyoto_2026',
            sortKey: 'a0',
            title: const Value('Day 1 - Demachi'),
            pinnedDate: const Value('2026-11-07'),
          ));
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_2',
            tripId: 'trip_kyoto_2026',
            sortKey: 'a1',
            title: const Value('Day 2 - Uji'),
            pinnedDate: const Value('2026-11-08'),
          ));

      // Seed Places (Parent rows)
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_shotengai',
            name: 'Demachi Masugata Shotengai',
            lat: 35.0116,
            lng: 135.7681,
            description: const Value('Tamako Market shopping street'),
            address: const Value('Kyoto, Kamigyo Ward, Masugata-cho'),
          ));
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_uji_bridge',
            name: 'Uji Bridge',
            lat: 34.8894,
            lng: 135.8078,
            description: const Value('Hibike! Euphonium bridge'),
            address: const Value('Kyoto, Uji'),
          ));

      // Seed Anime Labels & Links
      await db.into(db.labels).insert(LabelsCompanion.insert(
            id: 'lbl_tamako',
            kind: 'anime',
            name: 'Tamako Market',
          ));
      await db.into(db.labels).insert(LabelsCompanion.insert(
            id: 'lbl_eupho',
            kind: 'anime',
            name: 'Hibike! Euphonium',
          ));

      // Seed Stops (Child rows)
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_1',
            tripId: 'trip_kyoto_2026',
            placeKey: 'place_shotengai',
            name: 'Demachi Masugata Shotengai',
            lat: 35.0116,
            lng: 135.7681,
            description: const Value('Tamako Market shopping street'),
            note: const Value('Check out the mackerel banner'),
            address: const Value('Kyoto, Kamigyo Ward, Masugata-cho'),
            addedBy: 'user_alice',
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_2',
            tripId: 'trip_kyoto_2026',
            placeKey: 'place_uji_bridge',
            name: 'Uji Bridge',
            lat: 34.8894,
            lng: 135.8078,
            description: const Value('Hibike! Euphonium bridge'),
            addedBy: 'user_alice',
          ));

      // Link stop labels
      await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(
            stopId: 'stop_1',
            labelId: 'lbl_tamako',
          ));
      await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(
            stopId: 'stop_2',
            labelId: 'lbl_eupho',
          ));

      // Seed ScheduleItems
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_1',
            tripId: 'trip_kyoto_2026',
            stopId: 'stop_1',
            dayId: 'day_1',
            sortKey: 'a0',
            stayMinutes: const Value(90),
            status: const Value('planned'),
          ));
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_2',
            tripId: 'trip_kyoto_2026',
            stopId: 'stop_2',
            dayId: 'day_2',
            sortKey: 'a0',
            stayMinutes: const Value(60),
            status: const Value('done'),
          ));
    });

    tearDown(() async {
      await db.close();
    });

    test('exportTripToGpx exports full trip metadata, stops, routes, and anime extensions', () async {
      final gpxString = await porter.exportTripToGpx(db, 'trip_kyoto_2026');

      expect(gpxString, contains('<name>Kyoto Anime Odyssey</name>'));
      expect(gpxString, contains('<wpt lat="35.0116" lon="135.7681">'));
      expect(gpxString, contains('<name>Demachi Masugata Shotengai</name>'));
      expect(gpxString, contains('<animeTitle>Tamako Market</animeTitle>'));
      expect(gpxString, contains('<cmt>Check out the mackerel banner</cmt>'));

      // Check routes
      expect(gpxString, contains('<rte>'));
      expect(gpxString, contains('<name>Day 1 - Demachi (2026-11-07)</name>'));
      expect(gpxString, contains('<name>Day 2 - Uji (2026-11-08)</name>'));

      // Parse back and verify structure
      final parsed = porter.parseGpx(gpxString);
      expect(parsed.waypoints.length, equals(2));
      expect(parsed.routes.length, equals(2));
      expect(parsed.routes[0].points.first.name, equals('Demachi Masugata Shotengai'));
      expect(parsed.routes[1].points.first.name, equals('Uji Bridge'));
    });

    test('exportTripToKml exports folders for each day, placemarks with HTML description, and LineStrings', () async {
      final kmlString = await porter.exportTripToKml(db, 'trip_kyoto_2026');

      expect(kmlString, contains('<name>Kyoto Anime Odyssey</name>'));
      expect(kmlString, contains('<Folder>'));
      expect(kmlString, contains('<name>Day 1 - Demachi (2026-11-07)</name>'));
      expect(kmlString, contains('<name>Day 2 - Uji (2026-11-08)</name>'));
      expect(kmlString, contains('<coordinates>135.7681,35.0116,0</coordinates>'));
      expect(kmlString, contains('<h3>Demachi Masugata Shotengai</h3>'));
      expect(kmlString, contains('<p><b>Anime:</b> Tamako Market</p>'));

      final parsed = porter.parseKml(kmlString);
      expect(parsed.folders.length, equals(2));
      expect(parsed.folders[0].placemarks.length, equals(1));
      expect(parsed.folders[0].placemarks[0].name, equals('Demachi Masugata Shotengai'));
      expect(parsed.folders[1].placemarks.length, equals(1));
      expect(parsed.folders[1].placemarks[0].name, equals('Uji Bridge'));
    });

    test('importGpxToTrip inserts parent Places, child Stops, and ScheduleItems with Rule 2 integrity', () async {
      const gpxImportXml = '''<?xml version="1.0" encoding="UTF-8"?>
      <gpx version="1.1" creator="TestExport">
        <wpt lat="35.0272" lon="135.7982">
          <name>Ginkaku-ji Shrine Approach</name>
          <desc>Philosopher Path entrance</desc>
          <cmt>Peaceful early morning stroll</cmt>
          <extensions>
            <animeTitle>The Tatami Galaxy</animeTitle>
            <placeKey>tatami_ginkakuji</placeKey>
            <stayMinutes>45</stayMinutes>
          </extensions>
        </wpt>
        <!-- Invalid coordinate to verify resilient handling (Adversarial) -->
        <wpt lat="-95.0" lon="135.0">
          <name>Invalid Latitude Spot</name>
        </wpt>
      </gpx>
      ''';

      final result = await porter.importGpxToTrip(
        db,
        'trip_kyoto_2026',
        gpxImportXml,
        targetDayId: 'day_1',
        addedBy: 'user_bob',
      );

      expect(result.importedCount, equals(1));
      expect(result.skippedCount, equals(1));
      expect(result.errors.length, equals(1));
      expect(result.errors[0], contains('Invalid coordinates'));

      // Verify parent Place was inserted into database (Zero Data Loss)
      final place = await (db.select(db.places)..where((p) => p.placeKey.equals('tatami_ginkakuji'))).getSingleOrNull();
      expect(place, isNotNull);
      expect(place!.name, equals('Ginkaku-ji Shrine Approach'));
      expect(place.lat, closeTo(35.0272, 0.0001));

      // Verify child Stop was inserted into database
      final stopId = result.createdStopIds.first;
      final stop = await (db.select(db.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
      expect(stop, isNotNull);
      expect(stop!.tripId, equals('trip_kyoto_2026'));
      expect(stop.placeKey, equals('tatami_ginkakuji'));
      expect(stop.addedBy, equals('user_bob'));

      // Verify Anime Label was created and attached
      final labelRows = await (db.select(db.stopLabels).join([
        innerJoin(db.labels, db.labels.id.equalsExp(db.stopLabels.labelId)),
      ])..where(db.stopLabels.stopId.equals(stopId)))
          .get();
      expect(labelRows.length, equals(1));
      expect(labelRows.first.readTable(db.labels).name, equals('The Tatami Galaxy'));

      // Verify ScheduleItem was created under day_1
      final scheduleItem = await (db.select(db.scheduleItems)..where((s) => s.stopId.equals(stopId))).getSingleOrNull();
      expect(scheduleItem, isNotNull);
      expect(scheduleItem!.dayId, equals('day_1'));
      expect(scheduleItem.stayMinutes, equals(45));
    });

    test('importKmlToTrip automatically creates TripDays and imports placemarks into their respective days', () async {
      const kmlImportXml = '''<?xml version="1.0" encoding="UTF-8"?>
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <name>K-ON! Toyosato & Kyoto Trip</name>
          <Folder>
            <name>Day 3 - Toyosato Primary School</name>
            <Placemark>
              <name>Toyosato Elementary School Old Building</name>
              <description><![CDATA[<p>Sakuragaoka High School in K-ON!</p>]]></description>
              <ExtendedData>
                <Data name="animeTitle"><value>K-ON!</value></Data>
                <Data name="placeKey"><value>place_kon_toyosato</value></Data>
              </ExtendedData>
              <Point>
                <coordinates>136.2335,35.2014,0</coordinates>
              </Point>
            </Placemark>
          </Folder>
        </Document>
      </kml>
      ''';

      final result = await porter.importKmlToTrip(
        db,
        'trip_kyoto_2026',
        kmlImportXml,
        addedBy: 'user_charlie',
      );

      expect(result.importedCount, equals(1));
      expect(result.skippedCount, equals(0));

      // Check that a 3rd day block was automatically created for Day 3!
      final allDays = await (db.select(db.tripDays)..where((d) => d.tripId.equals('trip_kyoto_2026'))).get();
      expect(allDays.length, equals(3));
      final day3 = allDays.firstWhere((d) => d.title == 'Day 3 - Toyosato Primary School');
      expect(day3, isNotNull);

      // Check stop in day 3
      final stopId = result.createdStopIds.first;
      final scheduleItem = await (db.select(db.scheduleItems)..where((s) => s.stopId.equals(stopId))).getSingle();
      expect(scheduleItem.dayId, equals(day3.id));

      final stop = await (db.select(db.stops)..where((s) => s.id.equals(stopId))).getSingle();
      expect(stop.name, equals('Toyosato Elementary School Old Building'));
      expect(stop.description, equals('Sakuragaoka High School in K-ON!')); // HTML stripped cleanly
    });

    test('Entity Scope Isolation: importing to a day that belongs to another trip throws ArgumentError', () async {
      // Create a foreign trip with its own day
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_foreign_tokyo',
            title: 'Tokyo Trip',
            ownerId: 'user_eve',
          ));
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_tokyo_1',
            tripId: 'trip_foreign_tokyo',
            sortKey: 'b0',
          ));

      const sampleGpx = '''<?xml version="1.0" encoding="UTF-8"?>
      <gpx version="1.1" creator="Test">
        <wpt lat="35.6895" lon="139.6917"><name>Tokyo St</name></wpt>
      </gpx>''';

      // Attempting to import into trip_kyoto_2026 using day_tokyo_1 MUST throw ArgumentError
      expect(
        () => porter.importGpxToTrip(
          db,
          'trip_kyoto_2026',
          sampleGpx,
          targetDayId: 'day_tokyo_1',
        ),
        throwsArgumentError,
      );
    });

    test('Exporting non-existent trip throws ArgumentError', () async {
      expect(
        () => porter.exportTripToGpx(db, 'non_existent_trip_id'),
        throwsArgumentError,
      );
      expect(
        () => porter.exportTripToKml(db, 'non_existent_trip_id'),
        throwsArgumentError,
      );
    });

    test('Adversarial: Empty or malformed XML returns zero imports without crash', () async {
      final gpxResult = await porter.importGpxToTrip(db, 'trip_kyoto_2026', '');
      expect(gpxResult.importedCount, equals(0));
      expect(gpxResult.skippedCount, equals(0));

      final kmlResult = await porter.importKmlToTrip(db, 'trip_kyoto_2026', '<kml><corrupted');
      expect(kmlResult.importedCount, equals(0));
      expect(kmlResult.skippedCount, equals(0));
    });

    test('Trip with unscheduled stops exports an "Unscheduled Spots" folder in KML', () async {
      // Add a 3rd place and stop that is not scheduled on any day
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_unscheduled',
            name: 'Kiyomizu-dera Temple',
            lat: 34.9949,
            lng: 135.7850,
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_unscheduled',
            tripId: 'trip_kyoto_2026',
            placeKey: 'place_unscheduled',
            name: 'Kiyomizu-dera Temple',
            lat: 34.9949,
            lng: 135.7850,
            addedBy: 'user_alice',
          ));

      final kmlString = await porter.exportTripToKml(db, 'trip_kyoto_2026');
      expect(kmlString, contains('<name>Unscheduled Spots</name>'));
      expect(kmlString, contains('Kiyomizu-dera Temple'));

      final parsed = porter.parseKml(kmlString);
      final unFolder = parsed.folders.firstWhere((f) => f.name == 'Unscheduled Spots');
      expect(unFolder.placemarks.length, equals(1));
      expect(unFolder.placemarks.first.name, equals('Kiyomizu-dera Temple'));
    });

    test('Empty trip with no stops exports valid empty GPX and KML', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_empty',
            title: 'Empty Planned Trip',
            ownerId: 'user_alice',
          ));

      final gpx = await porter.exportTripToGpx(db, 'trip_empty');
      expect(gpx, contains('<name>Empty Planned Trip</name>'));
      final parsedGpx = porter.parseGpx(gpx);
      expect(parsedGpx.waypoints, isEmpty);
      expect(parsedGpx.routes, isEmpty);

      final kml = await porter.exportTripToKml(db, 'trip_empty');
      expect(kml, contains('<name>Empty Planned Trip</name>'));
      final parsedKml = porter.parseKml(kml);
      expect(parsedKml.folders, isEmpty);
      expect(parsedKml.standalonePlacemarks, isEmpty);
    });
  });
}
