import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/trip/models/walking_transit_models.dart';
import 'package:trip_planner/features/trip/services/walking_transit_service.dart';

void main() {
  group('WalkingTransitService - Tobler Algorithm & Physics Unit Tests', () {
    test('Tobler velocity calculates flat, optimal downhill, uphill, and steep braking speeds', () {
      // 1. Flat ground (S = 0): 6 * exp(-0.175) ≈ 5.036 km/h
      final flatSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 1000.0,
        elevationChangeMeters: 0.0,
      );
      expect(flatSpeed, closeTo(5.036, 0.05));

      // 2. Optimal gentle downhill (S = -0.05): 6 * exp(0) = 6.000 km/h
      final peakSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 1000.0,
        elevationChangeMeters: -50.0,
      );
      expect(peakSpeed, closeTo(6.000, 0.01));

      // 3. Moderate uphill (S = +0.10, 10% slope): 6 * exp(-3.5 * 0.15) ≈ 3.549 km/h
      final moderateUphillSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 1000.0,
        elevationChangeMeters: 100.0,
      );
      expect(moderateUphillSpeed, closeTo(3.549, 0.05));

      // 4. Steep mountain uphill (S = +0.25, 25% shrine stairs): 6 * exp(-3.5 * 0.30) ≈ 2.099 km/h
      final steepUphillSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 1000.0,
        elevationChangeMeters: 250.0,
      );
      expect(steepUphillSpeed, closeTo(2.099, 0.05));

      // 5. Steep downhill (S = -0.20): 6 * exp(-3.5 * 0.15) ≈ 3.549 km/h (braking)
      final steepDownhillSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 1000.0,
        elevationChangeMeters: -200.0,
      );
      expect(steepDownhillSpeed, closeTo(3.549, 0.05));

      // 6. Zero distance edge case handles gracefully
      final zeroDistanceSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 0.0,
        elevationChangeMeters: 0.0,
      );
      expect(zeroDistanceSpeed, equals(5.0));

      // 7. Extreme near-vertical climb clamps to minimum safe scrambling pace (0.5 km/h)
      final verticalSpeed = WalkingTransitService.calculateToblerVelocity(
        distanceMeters: 100.0,
        elevationChangeMeters: 150.0, // 150% gradient
      );
      expect(verticalSpeed, equals(0.5));
    });

    test('estimateSegment compares flat vs steep uphill transit times realistically', () {
      const service = WalkingTransitService();

      // Flat segment (1000m, Δh = 0)
      final flatSeg = service.estimateSegment(
        fromStopId: 's1',
        toStopId: 's2',
        fromName: 'Flat Origin',
        toName: 'Flat Target',
        fromLat: 35.0000,
        fromLng: 135.0000,
        fromElevation: 50.0,
        toLat: 35.0000,
        toLng: 135.0110, // ~1000m
        toElevation: 50.0,
        bufferMinutes: 1,
      );

      // Steep uphill segment (same horizontal distance, but +200m climb)
      final uphillSeg = service.estimateSegment(
        fromStopId: 's1',
        toStopId: 's3',
        fromName: 'Mountain Base',
        toName: 'Mountain Peak',
        fromLat: 35.0000,
        fromLng: 135.0000,
        fromElevation: 50.0,
        toLat: 35.0000,
        toLng: 135.0110,
        toElevation: 250.0, // +200m elevation gain!
        bufferMinutes: 1,
      );

      expect(flatSeg.isSteepUphill, isFalse);
      expect(uphillSeg.isSteepUphill, isTrue);

      // Uphill transit time must be significantly higher than flat walking time
      expect(uphillSeg.estimatedTransitMinutes, greaterThan(flatSeg.estimatedTransitMinutes * 1.5));
    });
  });

  group('WalkingTransitService - SQLite Calibration & Scope Isolation Tests', () {
    late AppDatabase db;
    late WalkingTransitService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = const WalkingTransitService();

      // Seed Trip
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_uji_pilgrimage',
            title: 'Hibike! Euphonium Uji Pilgrimage',
            ownerId: 'user_alice',
            startDate: const Value('2026-11-07'),
            dayCount: const Value(1),
          ));

      // Seed Day 1
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_uji_1',
            tripId: 'trip_uji_pilgrimage',
            sortKey: 'a0',
            title: const Value('Day 1 - Sound! Euphonium Sacred Route'),
          ));

      // Seed Places (Kyoto Station -> Keihan Uji Station -> Daikichiyama Observation Deck)
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_keihan_uji',
            name: 'Keihan Uji Station',
            lat: 34.8917,
            lng: 135.8119,
          ));
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_uji_shrine',
            name: 'Uji Shrine Approach',
            lat: 34.8910,
            lng: 135.8155,
          ));
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_daikichiyama',
            name: 'Daikichiyama Observation Deck',
            lat: 34.8928,
            lng: 135.8208,
          ));

      // Seed Stops
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_1_keihan',
            tripId: 'trip_uji_pilgrimage',
            placeKey: 'place_keihan_uji',
            name: 'Keihan Uji Station',
            lat: 34.8917,
            lng: 135.8119,
            addedBy: 'user_alice',
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_2_shrine',
            tripId: 'trip_uji_pilgrimage',
            placeKey: 'place_uji_shrine',
            name: 'Uji Shrine Approach',
            lat: 34.8910,
            lng: 135.8155,
            addedBy: 'user_alice',
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_3_daikichi',
            tripId: 'trip_uji_pilgrimage',
            placeKey: 'place_daikichiyama',
            name: 'Daikichiyama Observation Deck',
            lat: 34.8928,
            lng: 135.8208,
            addedBy: 'user_alice',
          ));

      // Seed ScheduleItems with initial 0 transitMinutes
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_1',
            tripId: 'trip_uji_pilgrimage',
            stopId: 'stop_1_keihan',
            dayId: 'day_uji_1',
            sortKey: 'a0',
            stayMinutes: const Value(30),
            transitMinutes: const Value(0),
          ));
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_2',
            tripId: 'trip_uji_pilgrimage',
            stopId: 'stop_2_shrine',
            dayId: 'day_uji_1',
            sortKey: 'a1',
            stayMinutes: const Value(45),
            transitMinutes: const Value(0),
          ));
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_3',
            tripId: 'trip_uji_pilgrimage',
            stopId: 'stop_3_daikichi',
            dayId: 'day_uji_1',
            sortKey: 'a2',
            stayMinutes: const Value(90),
            transitMinutes: const Value(0),
          ));
    });

    tearDown(() async {
      await db.close();
    });

    test('calculateDayWalkingFatigue computes elevation gain, segments, and fatigue level accurately', () async {
      // Elevations: Station 20m, Shrine 25m, Mountain 131m (climb of +106m)
      final elevations = {
        'stop_1_keihan': 20.0,
        'stop_2_shrine': 25.0,
        'stop_3_daikichi': 131.0,
      };

      final report = await service.calculateDayWalkingFatigue(
        db,
        'trip_uji_pilgrimage',
        'day_uji_1',
        stopElevations: elevations,
      );

      expect(report.segmentCount, equals(2));
      expect(report.totalDistanceMeters, greaterThan(800.0));
      expect(report.totalElevationGainMeters, closeTo(111.0, 1.0));
      expect(report.segments[0].elevationChangeMeters, closeTo(5.0, 0.5));
      expect(report.segments[1].elevationChangeMeters, closeTo(106.0, 0.5));
      expect(report.segments[1].isSteepUphill, isTrue); // Daikichiyama mountain trail slope > 15%
      expect(report.fatigueLevel, equals(WalkingFatigueLevel.strenuous));
    });

    test('applyDayWalkingTransits calibrates SQLite ScheduleItems transitMinutes without corrupting other columns (Rule 2)', () async {
      final elevations = {
        'stop_1_keihan': 20.0,
        'stop_2_shrine': 25.0,
        'stop_3_daikichi': 131.0,
      };

      final summary = await service.applyDayWalkingTransits(
        db,
        'trip_uji_pilgrimage',
        'day_uji_1',
        stopElevations: elevations,
      );

      expect(summary.updatedScheduleItemCount, equals(3));
      expect(summary.totalTransitMinutesAssigned, greaterThan(10));

      // Verify item_1 has transit to item_2
      final item1 = await (db.select(db.scheduleItems)..where((s) => s.id.equals('item_1'))).getSingle();
      expect(item1.transitMinutes, greaterThan(0));
      expect(item1.stayMinutes, equals(30)); // Rule 2: Partial Update Protection preserved!

      // Verify item_2 has uphill hiking transit to mountain observation deck
      final item2 = await (db.select(db.scheduleItems)..where((s) => s.id.equals('item_2'))).getSingle();
      expect(item2.transitMinutes, greaterThan(item1.transitMinutes)); // Hiking uphill takes longer!
      expect(item2.stayMinutes, equals(45));

      // Verify last stop (item_3) has 0 transit minutes
      final item3 = await (db.select(db.scheduleItems)..where((s) => s.id.equals('item_3'))).getSingle();
      expect(item3.transitMinutes, equals(0));
      expect(item3.stayMinutes, equals(90));
    });

    test('applyTripWalkingTransits applies walking calibration across all days of trip', () async {
      final summaries = await service.applyTripWalkingTransits(
        db,
        'trip_uji_pilgrimage',
      );

      expect(summaries.length, equals(1));
      expect(summaries.first.updatedScheduleItemCount, equals(3));
    });

    test('Entity Scope Isolation: calculating fatigue for a day of another trip throws ArgumentError', () async {
      // Create foreign trip
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_foreign',
            title: 'Foreign Trip',
            ownerId: 'user_eve',
          ));

      // Attempting to calculate day_uji_1 under trip_foreign MUST throw ArgumentError
      expect(
        () => service.calculateDayWalkingFatigue(db, 'trip_foreign', 'day_uji_1'),
        throwsArgumentError,
      );
      expect(
        () => service.applyDayWalkingTransits(db, 'trip_foreign', 'day_uji_1'),
        throwsArgumentError,
      );
    });

    test('Day with 0 or 1 stop returns zero segments without throwing', () async {
      // Create empty day
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_empty',
            tripId: 'trip_uji_pilgrimage',
            sortKey: 'b0',
          ));

      final emptyReport = await service.calculateDayWalkingFatigue(
        db,
        'trip_uji_pilgrimage',
        'day_empty',
      );
      expect(emptyReport.segmentCount, equals(0));
      expect(emptyReport.totalWalkingMinutes, equals(0));
      expect(emptyReport.fatigueLevel, equals(WalkingFatigueLevel.easy));
    });
  });
}
