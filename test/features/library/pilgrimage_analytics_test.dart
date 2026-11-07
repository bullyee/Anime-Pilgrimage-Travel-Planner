import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/library/models/pilgrimage_stats_models.dart';
import 'package:trip_planner/features/library/providers/pilgrimage_analytics_providers.dart';
import 'package:trip_planner/features/library/services/pilgrimage_analytics_service.dart';

void main() {
  group('AnimeCompletionStat & Model Metrics', () {
    test('computes completion ratio, percentage, and completion status accurately', () {
      const partial = AnimeCompletionStat(
        animeLabelId: 'lbl_kon',
        animeTitle: 'K-On!',
        totalSpotCount: 4,
        visitedSpotCount: 3,
        photoCount: 5,
      );

      expect(partial.completionRatio, 0.75);
      expect(partial.completionPercentage, 75.0);
      expect(partial.isCompleted, isFalse);

      const completed = AnimeCompletionStat(
        animeLabelId: 'lbl_tamako',
        animeTitle: 'Tamako Market',
        totalSpotCount: 5,
        visitedSpotCount: 5,
        photoCount: 12,
      );

      expect(completed.completionRatio, 1.0);
      expect(completed.completionPercentage, 100.0);
      expect(completed.isCompleted, isTrue);

      const empty = AnimeCompletionStat(
        animeLabelId: 'lbl_empty',
        animeTitle: 'Empty Anime',
        totalSpotCount: 0,
        visitedSpotCount: 0,
        photoCount: 0,
      );

      expect(empty.completionRatio, 0.0);
      expect(empty.completionPercentage, 0.0);
      expect(empty.isCompleted, isFalse);
    });

    test('TripCompletionStat calculates execution ratios and counts', () {
      const tripStat = TripCompletionStat(
        tripId: 'trip_1',
        tripTitle: 'Kyoto Journey',
        totalStops: 10,
        plannedStops: 3,
        doneStops: 6,
        skippedStops: 1,
        photoCount: 18,
      );

      expect(tripStat.completionRatio, 0.6);
      expect(tripStat.completionPercentage, 60.0);
    });
  });

  group('PilgrimageAnalyticsService - SQLite Database Aggregation', () {
    late AppDatabase db;
    late PilgrimageAnalyticsService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = const PilgrimageAnalyticsService();
    });

    tearDown(() async {
      await db.close();
    });

    test('getLibrarySummary returns zeroed metrics on empty library', () async {
      final summary = await service.getLibrarySummary(db);
      expect(summary.totalDistinctAnime, 0);
      expect(summary.totalPlaces, 0);
      expect(summary.totalVisitedPlaces, 0);
      expect(summary.totalPhotosTaken, 0);
      expect(summary.overallCompletionPercentage, 0.0);
      expect(summary.animeStats, isEmpty);
      expect(summary.regionStats, isEmpty);
    });

    test('getLibrarySummary aggregates per-anime and per-region progress from SQLite', () async {
      // 1. Insert 2 anime labels
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'lbl_eupho',
              kind: 'anime',
              name: 'Sound! Euphonium',
            ),
          );
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'lbl_kon',
              kind: 'anime',
              name: 'K-On!',
            ),
          );

      // 2. Insert 3 places for Euphonium (Kyoto) and 2 places for K-On! (Shiga & Kyoto)
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_uji_bridge',
              name: 'Uji Bridge',
              address: const Value('京都府宇治市宇治'),
              lat: 34.8905,
              lng: 135.8080,
            ),
          );
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_daikichiyama',
              name: 'Daikichiyama Observation Deck',
              address: const Value('京都府宇治市宇治山田'),
              lat: 34.8930,
              lng: 135.8150,
            ),
          );
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_rokujizo',
              name: 'Rokujizo Station',
              address: const Value('京都府宇治市六地蔵'),
              lat: 34.9320,
              lng: 135.7930,
            ),
          );
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_toyosato',
              name: 'Toyosato Elementary School',
              address: const Value('滋賀県犬上郡豊郷町石畑'),
              lat: 35.2025,
              lng: 136.2335,
            ),
          );
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_kamogawa',
              name: 'Kamogawa Stepping Stones',
              address: const Value('京都府京都市左京区下高野'),
              lat: 35.0305,
              lng: 135.7705,
            ),
          );

      // 3. Link places to anime labels
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(placeKey: 'p_uji_bridge', labelId: 'lbl_eupho'),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(placeKey: 'p_daikichiyama', labelId: 'lbl_eupho'),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(placeKey: 'p_rokujizo', labelId: 'lbl_eupho'),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(placeKey: 'p_toyosato', labelId: 'lbl_kon'),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(placeKey: 'p_kamogawa', labelId: 'lbl_kon'),
          );

      // 4. Insert photos:
      // - Uji Bridge (visited, 2 photos)
      // - Daikichiyama (visited, 1 photo)
      // - Rokujizo (UNVISITED)
      // - Toyosato (visited, 1 photo)
      // - Kamogawa (UNVISITED)
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'photo_1',
              placeKey: 'p_uji_bridge',
              localPath: '/tmp/p1.jpg',
            ),
          );
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'photo_2',
              placeKey: 'p_uji_bridge',
              localPath: '/tmp/p2.jpg',
            ),
          );
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'photo_3',
              placeKey: 'p_daikichiyama',
              localPath: '/tmp/p3.jpg',
            ),
          );
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'photo_4',
              placeKey: 'p_toyosato',
              localPath: '/tmp/p4.jpg',
            ),
          );

      // 5. Query overall summary
      final summary = await service.getLibrarySummary(db);

      expect(summary.totalDistinctAnime, 2);
      expect(summary.totalPlaces, 5);
      expect(summary.totalVisitedPlaces, 3);
      expect(summary.totalPhotosTaken, 4);
      expect(summary.overallCompletionPercentage, 60.0);

      // Verify Euphonium stats (3 spots, 2 visited = 66.7%)
      final euphoStat = summary.animeStats.firstWhere((a) => a.animeLabelId == 'lbl_eupho');
      expect(euphoStat.totalSpotCount, 3);
      expect(euphoStat.visitedSpotCount, 2);
      expect(euphoStat.photoCount, 3);
      expect(euphoStat.completionPercentage, 66.7);
      expect(euphoStat.unvisitedPlaceKeys, contains('p_rokujizo'));

      // Verify K-On! stats (2 spots, 1 visited = 50.0%)
      final konStat = summary.animeStats.firstWhere((a) => a.animeLabelId == 'lbl_kon');
      expect(konStat.totalSpotCount, 2);
      expect(konStat.visitedSpotCount, 1);
      expect(konStat.photoCount, 1);
      expect(konStat.completionPercentage, 50.0);
      expect(konStat.unvisitedPlaceKeys, contains('p_kamogawa'));

      // Verify region buckets (Kyoto: 4 spots, Shiga: 1 spot)
      final kyotoRegion = summary.regionStats.firstWhere((r) => r.regionName == '京都');
      expect(kyotoRegion.totalSpotCount, 4);
      expect(kyotoRegion.visitedSpotCount, 2);

      final shigaRegion = summary.regionStats.firstWhere((r) => r.regionName == '滋賀');
      expect(shigaRegion.totalSpotCount, 1);
      expect(shigaRegion.visitedSpotCount, 1);
    });

    test('getAnimeCompletion computes single anime stats with unvisited list', () async {
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'lbl_tamako',
              kind: 'anime',
              name: 'Tamako Market',
            ),
          );

      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_demachi',
              name: 'Demachi Masugata',
              lat: 35.0305,
              lng: 135.7705,
            ),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(placeKey: 'p_demachi', labelId: 'lbl_tamako'),
          );

      final stat = await service.getAnimeCompletion(db, 'lbl_tamako');
      expect(stat, isNotNull);
      expect(stat!.animeTitle, 'Tamako Market');
      expect(stat.totalSpotCount, 1);
      expect(stat.visitedSpotCount, 0);
      expect(stat.unvisitedPlaceKeys, ['p_demachi']);

      // Non-existent label returns null
      final nonExistent = await service.getAnimeCompletion(db, 'lbl_missing');
      expect(nonExistent, isNull);
    });

    test('getTripCompletion enforces entity scope isolation across trips', () async {
      // Create Alice Trip and Bob Trip
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_alice',
              title: 'Alice Pilgrimage',
              ownerId: 'user_alice',
            ),
          );
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_bob',
              title: 'Bob Pilgrimage',
              ownerId: 'user_bob',
            ),
          );

      // Insert Stops for Alice (2 stops) and Bob (1 stop)
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_a1',
              tripId: 'trip_alice',
              placeKey: 'p1',
              name: 'Alice Spot 1',
              lat: 35.0,
              lng: 135.0,
              addedBy: 'user_alice',
            ),
          );
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_a2',
              tripId: 'trip_alice',
              placeKey: 'p2',
              name: 'Alice Spot 2',
              lat: 35.1,
              lng: 135.1,
              addedBy: 'user_alice',
            ),
          );
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_b1',
              tripId: 'trip_bob',
              placeKey: 'p3',
              name: 'Bob Spot 1',
              lat: 36.0,
              lng: 136.0,
              addedBy: 'user_bob',
            ),
          );

      // Create Day and Schedule items for Alice (1 done, 1 planned)
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_a',
              tripId: 'trip_alice',
              sortKey: 'a0',
            ),
          );
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'sch_a1',
              tripId: 'trip_alice',
              stopId: 'stop_a1',
              dayId: 'day_a',
              sortKey: 'a0',
              status: const Value('done'),
            ),
          );
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'sch_a2',
              tripId: 'trip_alice',
              stopId: 'stop_a2',
              dayId: 'day_a',
              sortKey: 'a1',
              status: const Value('planned'),
            ),
          );

      // Alice's trip completion should see 2 stops, 1 done, 1 planned (50%)
      final aliceStat = await service.getTripCompletion(db, 'trip_alice');
      expect(aliceStat.totalStops, 2);
      expect(aliceStat.doneStops, 1);
      expect(aliceStat.plannedStops, 1);
      expect(aliceStat.completionPercentage, 50.0);

      // Bob's trip completion should see 1 stop, 0 schedule items
      final bobStat = await service.getTripCompletion(db, 'trip_bob');
      expect(bobStat.totalStops, 1);
      expect(bobStat.doneStops, 0);
      expect(bobStat.completionPercentage, 0.0);
    });

    test('Riverpod Providers evaluate overall, anime, and trip completion', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pilgrimageAnalyticsServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(overallPilgrimageSummaryProvider.future);
      expect(summary.totalPlaces, 0);
    });
  });
}
