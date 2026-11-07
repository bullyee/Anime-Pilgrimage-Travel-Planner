import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/models/travelogue_models.dart';
import 'package:trip_planner/features/trip/providers/travelogue_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/services/pilgrimage_travelogue_service.dart';

void main() {
  late AppDatabase db;
  late PlaceRepository placeRepo;
  late TripRepository tripRepo;
  const service = PilgrimageTravelogueService();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'user_pilgrim', placeRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('PilgrimageTravelogueService - Compilation', () {
    test('compiles comprehensive travelogue with labels, visits, photos, and reference cuts', () async {
      // 1. Setup Trip
      final trip = await tripRepo.createTrip(
        title: 'Sound! Euphonium Uji Pilgrimage',
        description: 'Summer pilgrimage to Uji walking in the footsteps of Kumiko and Reina.',
        ownerId: 'user_pilgrim',
        startDate: '2026-08-15',
        dayCount: 1,
      );

      final days = await tripRepo.getDaysForTrip(trip.id);
      final day1 = days.first;

      // 2. Create Spots
      final stop1 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Daikichiyama Observation Deck',
        lat: 34.8950,
        lng: 135.8180,
        addedBy: 'user_pilgrim',
        description: 'Iconic mountaintop bench overlooking Uji city.',
        accessTips: 'Hike 15-20 min up the zigzag trail.',
      );
      final stop2 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Kumiko Bench',
        lat: 34.8900,
        lng: 135.8150,
        addedBy: 'user_pilgrim',
        description: 'Riverside bench near Uji Shrine.',
      );

      // 3. Schedule Stops in Day 1
      await tripRepo.scheduleStop(
        tripId: trip.id,
        stopId: stop1.id,
        dayId: day1.id,
        stayMinutes: 45,
      );
      await tripRepo.scheduleStop(
        tripId: trip.id,
        stopId: stop2.id,
        dayId: day1.id,
        stayMinutes: 30,
      );

      // Update stop note
      await (db.update(db.stops)..where((s) => s.id.equals(stop1.id))).write(
        const StopsCompanion(note: Value('Brought euphonium keychain for sunset shot.')),
      );

      // 4. Attach Anime Labels
      const labelId = 'lbl_eupho';
      await db.into(db.labels).insert(LabelsCompanion.insert(
        id: labelId,
        name: 'Sound! Euphonium',
        kind: 'anime',
      ));
      await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(
        stopId: stop1.id,
        labelId: labelId,
      ));
      await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(
        stopId: stop2.id,
        labelId: labelId,
      ));

      // 5. Check in stop 1
      await db.into(db.placeVisits).insert(PlaceVisitsCompanion.insert(
        id: 'visit_1',
        placeKey: stop1.placeKey,
        date: '2026-08-15',
        tripId: Value(trip.id),
        createdAt: Value(DateTime(2026, 8, 15, 18, 30)),
      ));

      // 6. User Photos
      await db.into(db.photos).insert(PhotosCompanion.insert(
        id: 'photo_1',
        placeKey: stop1.placeKey,
        localPath: '/storage/emulated/0/DCIM/daikichi_sunset.jpg',
        tripId: Value(trip.id),
        takenAt: Value(DateTime(2026, 8, 15, 18, 35)),
      ));

      // 7. Anime Reference Images
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'ref_1',
        placeKey: Value(stop1.placeKey),
        stopId: Value(stop1.id),
        localPath: const Value('/assets/eupho_ep8_mountain.jpg'),
        remoteUrl: const Value('https://cdn.example.com/eupho/ep8_cut.jpg'),
        episode: const Value('Episode 8'),
      ));

      // Compile
      final doc = await service.compileTravelogue(db, trip.id, authorName: 'KumikoFan');

      expect(doc.title, equals('Sound! Euphonium Uji Pilgrimage'));
      expect(doc.author, equals('KumikoFan'));
      expect(doc.animeTitles, contains('Sound! Euphonium'));
      expect(doc.totalStops, equals(2));
      expect(doc.completedStops, equals(1)); // stop 1 visited
      expect(doc.completionRate, equals(0.5));
      expect(doc.completionRatePercentage, equals('50.0%'));

      expect(doc.days.length, equals(1));
      final section = doc.days.first;
      expect(section.stops.length, equals(2));

      final entry1 = section.stops[0];
      expect(entry1.name, equals('Daikichiyama Observation Deck'));
      expect(entry1.isCompleted, isTrue);
      expect(entry1.visitDate, equals('2026-08-15'));
      expect(entry1.note, equals('Brought euphonium keychain for sunset shot.'));
      expect(entry1.photos.length, equals(1));
      expect(entry1.photos.first.refImageLocalPath, equals('/assets/eupho_ep8_mountain.jpg'));
      expect(entry1.photos.first.episode, equals('Episode 8'));
      expect(entry1.photos.first.userPhotoPath, equals('/storage/emulated/0/DCIM/daikichi_sunset.jpg'));

      final entry2 = section.stops[1];
      expect(entry2.name, equals('Kumiko Bench'));
      expect(entry2.isCompleted, isFalse);
    });

    test('throws ArgumentError if trip does not exist', () async {
      expect(
        () => service.compileTravelogue(db, 'non_existent_trip_id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles empty trip with 0 stops gracefully without crashing or dividing by zero', () async {
      final trip = await tripRepo.createTrip(
        title: 'Empty Trip',
        ownerId: 'user_pilgrim',
        dayCount: 0,
      );

      final doc = await service.compileTravelogue(db, trip.id);
      expect(doc.totalStops, equals(0));
      expect(doc.completedStops, equals(0));
      expect(doc.completionRate, equals(0.0));
      expect(doc.completionRatePercentage, equals('0.0%'));
      expect(doc.days, isEmpty);
    });
  });

  group('PilgrimageTravelogueService - Markdown Export', () {
    test('generates valid Obsidian and GitHub compatible markdown document', () async {
      final doc = TravelogueDocument(
        tripId: 'trip_100',
        title: 'Oarai Girls "Panzer" Tour & Shrine',
        description: 'Visiting Ooarai Isosaki Shrine and town shopping street.',
        author: 'Miho Nishizumi',
        startDate: '2026-09-01',
        generatedAt: DateTime(2026, 9, 2),
        animeTitles: ['Girls und Panzer'],
        totalStops: 2,
        completedStops: 1,
        days: [
          TravelogueDaySection(
            dayId: 'day_1',
            title: 'Oarai Coast',
            pinnedDate: '2026-09-01',
            stops: [
              TravelogueStopEntry(
                stopId: 'stop_1',
                placeKey: 'place_torii',
                name: 'Kamiiso no Torii',
                lat: 36.3150,
                lng: 140.5880,
                animeTitle: 'Girls und Panzer',
                description: 'Torii gate standing on the ocean rocks.',
                note: 'Arrived at sunrise for high tide waves.',
                accessTips: 'Take the bus from Oarai Station.',
                visitDate: '2026-09-01',
                visitedAt: DateTime(2026, 9, 1, 5, 45),
                stayMinutes: 45,
                photos: [
                  const TraveloguePhotoItem(
                    userPhotoPath: '/photos/torii_sunrise.jpg',
                    refImageLocalPath: '/refs/gup_op_torii.jpg',
                    episode: 'Opening',
                  ),
                ],
              ),
              const TravelogueStopEntry(
                stopId: 'stop_2',
                placeKey: 'place_hotel',
                name: 'Isami Karinto Hotel',
                lat: 36.3110,
                lng: 140.5820,
                stayMinutes: 30,
                status: 'planned',
              ),
            ],
          ),
        ],
      );

      final md = service.generateMarkdown(doc);

      // Verify YAML frontmatter
      expect(md, contains('---'));
      expect(md, contains('title: "Oarai Girls \\"Panzer\\" Tour & Shrine"'));
      expect(md, contains('author: "Miho Nishizumi"'));
      expect(md, contains('date: 2026-09-01'));
      expect(md, contains('- "Girls und Panzer"'));
      expect(md, contains('completion_rate: "50.0%"'));

      // Verify title & stats
      expect(md, contains('# ⛩️ Oarai Girls "Panzer" Tour & Shrine'));
      expect(md, contains('📍 **Total Stops**: 2 | ✅ **Completed**: 1 (50.0%)'));
      expect(md, contains('🎬 **Anime Works**: Girls und Panzer'));

      // Verify day & stops
      expect(md, contains('## 📅 Day 1: Oarai Coast (2026-09-01)'));
      expect(md, contains('### 1. ✅ Kamiiso no Torii'));
      expect(md, contains('[Open in Google Maps](https://www.google.com/maps/search/?api=1&query=36.315,140.588)'));
      expect(md, contains('> 📝 **Scene Info**: Torii gate standing on the ocean rocks.'));
      expect(md, contains('> 💡 **Pilgrim Note**: Arrived at sunrise for high tide waves.'));
      expect(md, contains('> 🚶 **Access Tips**: Take the bus from Oarai Station.'));

      // Verify side-by-side comparison table
      expect(md, contains('| Anime Reference Cut (Opening) | Pilgrim Photo |'));
      expect(md, contains('| ![](/refs/gup_op_torii.jpg) | ![](/photos/torii_sunrise.jpg) |'));

      // Verify planned stop
      expect(md, contains('### 2. ⏳ Isami Karinto Hotel'));
    });
  });

  group('PilgrimageTravelogueService - HTML Export', () {
    test('generates self-contained, responsive HTML5 with print stylesheet', () {
      final doc = TravelogueDocument(
        tripId: 'trip_html',
        title: 'Bocchi the Rock! Shimokitazawa Live House Tour',
        description: 'Touring Shelter (STARRY) and village vanguard.',
        author: 'Hitori Gotoh',
        startDate: '2026-10-01',
        generatedAt: DateTime(2026, 10, 2),
        animeTitles: ['Bocchi the Rock!'],
        totalStops: 1,
        completedStops: 1,
        days: [
          TravelogueDaySection(
            dayId: 'day_shimo',
            title: 'Shimokitazawa Live Scene',
            stops: [
              const TravelogueStopEntry(
                stopId: 'stop_shelter',
                placeKey: 'place_shelter',
                name: 'Shimokitazawa SHELTER',
                lat: 35.6610,
                lng: 139.6670,
                animeTitle: 'Bocchi the Rock!',
                description: 'The real-life live house STARRY where Kessoku Band performs.',
                note: 'Remember to respect neighborhood silence rules outside the entrance.',
                status: 'done',
              ),
            ],
          ),
        ],
      );

      final html = service.generateHtml(doc);

      // Verify HTML structure
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<html lang="en">'));
      expect(html, contains('<title>Bocchi the Rock! Shimokitazawa Live House Tour - Pilgrimage Report</title>'));
      expect(html, contains('<meta name="viewport" content="width=device-width, initial-scale=1.0">'));

      // Verify print stylesheet
      expect(html, contains('@media print'));

      // Verify rendered components
      expect(html, contains('⛩️ Bocchi the Rock! Shimokitazawa Live House Tour'));
      expect(html, contains('Shimokitazawa SHELTER'));
      expect(html, contains('🎬 Bocchi the Rock!'));
      expect(html, contains('The real-life live house STARRY where Kessoku Band performs.'));
      expect(html, contains('https://www.google.com/maps/search/?api=1&query=35.661,139.667'));
      expect(html, contains('Zero Ad Tracking'));
    });

    test('escapes HTML special characters safely to prevent injection', () {
      final doc = TravelogueDocument(
        tripId: 'trip_escape',
        title: 'Trip with <script>alert("xss")</script> & "Quotes"',
        description: '<img src=x onerror=alert(1)> & special characters',
        author: 'Alice & Bob',
        generatedAt: DateTime(2026, 1, 1),
        animeTitles: ['Anime <One> & "Two"'],
        totalStops: 0,
        completedStops: 0,
        days: [],
      );

      final html = service.generateHtml(doc);

      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt; &amp; &quot;Quotes&quot;'));
      expect(html, contains('&lt;img src=x onerror=alert(1)&gt; &amp; special characters'));
      expect(html, contains('Alice &amp; Bob'));
      expect(html, contains('Anime &lt;One&gt; &amp; &quot;Two&quot;'));
    });
  });

  group('PilgrimageTravelogueService - Direct Export Helpers & Providers', () {
    test('exportTravelogueMarkdown and exportTravelogueHtml direct methods', () async {
      final trip = await tripRepo.createTrip(
        title: 'Quick Tour',
        ownerId: 'user_pilgrim',
        dayCount: 1,
      );

      final md = await service.exportTravelogueMarkdown(db, trip.id);
      expect(md, contains('# ⛩️ Quick Tour'));

      final html = await service.exportTravelogueHtml(db, trip.id);
      expect(html, contains('⛩️ Quick Tour'));
    });

    test('Riverpod providers compile and export correctly', () async {
      final trip = await tripRepo.createTrip(
        title: 'Provider Test Tour',
        ownerId: 'user_pilgrim',
        dayCount: 1,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final doc = await container.read(tripTravelogueDocumentProvider(trip.id).future);
      expect(doc.title, equals('Provider Test Tour'));

      final md = await container.read(tripTravelogueMarkdownProvider(trip.id).future);
      expect(md, contains('Provider Test Tour'));

      final html = await container.read(tripTravelogueHtmlProvider(trip.id).future);
      expect(html, contains('Provider Test Tour'));
    });
  });
}
