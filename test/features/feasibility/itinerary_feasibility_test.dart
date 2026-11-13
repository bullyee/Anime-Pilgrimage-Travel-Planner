import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/feasibility/models/feasibility_models.dart';
import 'package:trip_planner/features/feasibility/providers/feasibility_providers.dart';
import 'package:trip_planner/features/feasibility/services/itinerary_feasibility_service.dart';
import 'package:trip_planner/features/feasibility/services/opening_hours_parser.dart';

void main() {
  group('OpeningHoursParser', () {
    test('parses Japanese business hours with closed days (定休日)', () {
      final rule = OpeningHoursParser.parse('10:00～18:00 (定休日: 火・水曜日)');
      expect(rule, isNotNull);
      expect(rule!.closedDays, containsAll([2, 3])); // Tuesday, Wednesday
      expect(rule.openDays, containsAll([1, 4, 5, 6, 7]));
      expect(rule.defaultWindows.length, 1);
      expect(rule.defaultWindows.first.openMinutes, 600); // 10:00
      expect(rule.defaultWindows.first.closeMinutes, 1080); // 18:00

      // Tuesday: 2026-05-12 is a Tuesday
      final tuesday = DateTime(2026, 5, 12);
      expect(tuesday.weekday, DateTime.tuesday);
      expect(rule.isOpenOnDate(tuesday), isFalse);

      // Thursday: 2026-05-14 is a Thursday
      final thursday = DateTime(2026, 5, 14);
      expect(thursday.weekday, DateTime.thursday);
      expect(rule.isOpenOnDate(thursday), isTrue);
      expect(rule.isOpenAt(thursday, 660), isTrue); // 11:00
      expect(rule.isOpenAt(thursday, 540), isFalse); // 09:00 (before open)
      expect(rule.isOpenAt(thursday, 1140), isFalse); // 19:00 (after close)
    });

    test('parses split lunch and dinner hours', () {
      final rule = OpeningHoursParser.parse('11:00-14:30, 17:00-21:00');
      expect(rule, isNotNull);
      expect(rule!.defaultWindows.length, 2);
      expect(rule.defaultWindows[0].openMinutes, 660); // 11:00
      expect(rule.defaultWindows[0].closeMinutes, 870); // 14:30
      expect(rule.defaultWindows[1].openMinutes, 1020); // 17:00
      expect(rule.defaultWindows[1].closeMinutes, 1260); // 21:00

      final monday = DateTime(2026, 5, 11);
      expect(rule.isOpenAt(monday, 720), isTrue); // 12:00 (lunch)
      expect(rule.isOpenAt(monday, 960), isFalse); // 16:00 (break)
      expect(rule.isOpenAt(monday, 1080), isTrue); // 18:00 (dinner)
    });

    test('parses overnight / late-night business hours', () {
      final rule = OpeningHoursParser.parse('18:00-02:00');
      expect(rule, isNotNull);
      expect(rule!.defaultWindows.length, 1);
      expect(rule.defaultWindows.first.openMinutes, 1080); // 18:00
      expect(rule.defaultWindows.first.closeMinutes, 1560); // 26:00 (02:00 next day)
    });

    test('detects unrestricted and 24-hour spots (shrine grounds, plazas)', () {
      final shrineRule = OpeningHoursParser.parse('境内自由 / 参拝自由');
      expect(shrineRule, isNotNull);
      expect(shrineRule!.isAlwaysOpen, isTrue);
      expect(shrineRule.isOpenOnDate(DateTime(2026, 5, 12)), isTrue);

      final round24Rule = OpeningHoursParser.parse('24時間営業 年中無休');
      expect(round24Rule, isNotNull);
      expect(round24Rule!.is24Hours, isTrue);
      expect(round24Rule.isOpenAt(DateTime(2026, 5, 12), 180), isTrue); // 03:00 AM
    });

    test('handles English closed tokens (Closed: Monday)', () {
      final rule = OpeningHoursParser.parse('09:00 - 17:00; Closed: Monday');
      expect(rule, isNotNull);
      expect(rule!.closedDays, contains(1));

      final monday = DateTime(2026, 5, 11);
      expect(rule.isOpenOnDate(monday), isFalse);
    });

    test('returns null gracefully on null or empty input without throwing', () {
      expect(OpeningHoursParser.parse(null), isNull);
      expect(OpeningHoursParser.parse(''), isNull);
      expect(OpeningHoursParser.parse('   '), isNull);
    });
  });

  group('TimeWindow', () {
    test('contains and formatting methods', () {
      const window = TimeWindow(openMinutes: 540, closeMinutes: 1020);
      expect(window.contains(540), isTrue);
      expect(window.contains(700), isTrue);
      expect(window.contains(1019), isTrue);
      expect(window.contains(1020), isFalse);
      expect(window.contains(539), isFalse);
      expect(window.format(), '09:00 - 17:00');
      expect(window.toString(), '09:00 - 17:00');
    });
  });

  group('ItineraryFeasibilityService - In-memory Timeline Evaluation', () {
    const service = ItineraryFeasibilityService();

    // Sample stops
    final demachiMasugata = Stop(
      id: 'stop_1',
      tripId: 'trip_1',
      placeKey: 'place_demachi',
      name: 'Demachi Masugata Shotengai (Tamako Market)',
      lat: 35.0305,
      lng: 135.7705,
      businessHours: '10:00～18:00 (定休日: 火曜日)',
      addedBy: 'user_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 0,
    );

    final ujiBridge = Stop(
      id: 'stop_2',
      tripId: 'trip_1',
      placeKey: 'place_uji',
      name: 'Uji Bridge (Sound! Euphonium)',
      lat: 34.8905,
      lng: 135.8080,
      businessHours: '境内自由',
      addedBy: 'user_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 0,
    );

    final museumSpot = Stop(
      id: 'stop_3',
      tripId: 'trip_1',
      placeKey: 'place_museum',
      name: 'Kyoto International Manga Museum',
      lat: 35.0116,
      lng: 135.7594,
      businessHours: '10:30～17:30 (定休日: 水曜日)',
      addedBy: 'user_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 0,
    );

    test('flags closed on day error when stop is visited on its 定休日', () {
      // 2026-05-12 is a Tuesday
      final tuesday = DateTime(2026, 5, 12);
      final item = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: demachiMasugata.id,
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 60,
        transitMinutes: 15,
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final report = service.evaluateDayTimeline(
        dayId: 'day_1',
        dayTitle: 'Day 1',
        date: tuesday,
        items: [item],
        stopsMap: {demachiMasugata.id: demachiMasugata},
      );

      expect(report.isFeasible, isFalse);
      expect(report.errorCount, 1);
      final issue = report.issues.first;
      expect(issue.type, FeasibilityIssueType.closedOnDay);
      expect(issue.severity, FeasibilitySeverity.error);
      expect(issue.message, contains('Tuesday'));
      expect(issue.message, contains('Demachi Masugata'));
    });

    test('flags arrives before open warning when arriving too early', () {
      // Thursday 2026-05-14 (open from 10:00 to 18:00)
      final thursday = DateTime(2026, 5, 14);
      final item = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: demachiMasugata.id,
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 60,
        transitMinutes: 0, // Starts at default 09:00
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final report = service.evaluateDayTimeline(
        dayId: 'day_1',
        dayTitle: 'Day 1',
        date: thursday,
        items: [item],
        stopsMap: {demachiMasugata.id: demachiMasugata},
      );

      expect(report.isFeasible, isTrue); // Warnings do not make isFeasible false
      expect(report.warningCount, 1);
      final issue = report.issues.first;
      expect(issue.type, FeasibilityIssueType.arrivesBeforeOpen);
      expect(issue.severity, FeasibilitySeverity.warning);
      expect(issue.message, contains('09:00'));
      expect(issue.message, contains('10:00'));
    });

    test('flags arrives after close error when arriving past closing time', () {
      // Thursday 2026-05-14 (closes at 17:30)
      final thursday = DateTime(2026, 5, 14);
      final item = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: museumSpot.id,
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 60,
        transitMinutes: 0,
        fixedTime: 1110, // 18:30 fixed arrival
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final report = service.evaluateDayTimeline(
        dayId: 'day_1',
        date: thursday,
        items: [item],
        stopsMap: {museumSpot.id: museumSpot},
      );

      expect(report.isFeasible, isFalse);
      expect(report.errorCount, 1);
      final issue = report.issues.first;
      expect(issue.type, FeasibilityIssueType.arrivesAfterClose);
      expect(issue.severity, FeasibilitySeverity.error);
      expect(issue.message, contains('18:30'));
      expect(issue.message, contains('17:30'));
    });

    test('flags visit truncated by closing when stay extends past closing time', () {
      final thursday = DateTime(2026, 5, 14); // Closes at 17:30
      final item = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: museumSpot.id,
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 90,
        transitMinutes: 0,
        fixedTime: 1020, // 17:00 arrival, stay 90m -> departs 18:30
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final report = service.evaluateDayTimeline(
        dayId: 'day_1',
        date: thursday,
        items: [item],
        stopsMap: {museumSpot.id: museumSpot},
      );

      expect(report.isFeasible, isTrue);
      expect(report.warningCount, 1);
      final issue = report.issues.first;
      expect(issue.type, FeasibilityIssueType.visitTruncatedByClose);
      expect(issue.message, contains('60m'));
    });

    test('flags timeline overlap error when transit and previous stay clash with fixedTime', () {
      final thursday = DateTime(2026, 5, 14);
      // Stop 1: 09:00 to 10:30 (90 min stay)
      final item1 = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: ujiBridge.id,
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 90,
        transitMinutes: 0,
        fixedTime: 540, // 09:00
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      // Stop 2: Transit 45m from Stop 1 (arrives 11:15), but fixedTime is set to 10:00!
      final item2 = ScheduleItem(
        id: 'item_2',
        tripId: 'trip_1',
        stopId: demachiMasugata.id,
        dayId: 'day_1',
        sortKey: 'a1',
        stayMinutes: 60,
        transitMinutes: 45,
        fixedTime: 600, // 10:00
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final report = service.evaluateDayTimeline(
        dayId: 'day_1',
        date: thursday,
        items: [item1, item2],
        stopsMap: {
          ujiBridge.id: ujiBridge,
          demachiMasugata.id: demachiMasugata,
        },
      );

      expect(report.isFeasible, isFalse);
      expect(report.errorCount, 1);
      final overlap = report.issues.firstWhere((i) => i.type == FeasibilityIssueType.timelineOverlap);
      expect(overlap.severity, FeasibilitySeverity.error);
      expect(overlap.message, contains('missed by 75m'));
    });

    test('flags missing transit time warning when stops are far apart with 0m transit', () {
      final thursday = DateTime(2026, 5, 14);
      // Demachi to Uji Bridge is ~16 kilometers apart!
      final item1 = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: demachiMasugata.id,
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 60,
        transitMinutes: 0,
        fixedTime: 600, // 10:00
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final item2 = ScheduleItem(
        id: 'item_2',
        tripId: 'trip_1',
        stopId: ujiBridge.id,
        dayId: 'day_1',
        sortKey: 'a1',
        stayMinutes: 60,
        transitMinutes: 0, // 0 minutes transit for 16 km!
        status: 'planned',
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final report = service.evaluateDayTimeline(
        dayId: 'day_1',
        date: thursday,
        items: [item1, item2],
        stopsMap: {
          demachiMasugata.id: demachiMasugata,
          ujiBridge.id: ujiBridge,
        },
      );

      final missingTransit = report.issues.firstWhere((i) => i.type == FeasibilityIssueType.missingTransitTime);
      expect(missingTransit.severity, FeasibilitySeverity.warning);
      expect(missingTransit.message, contains('km apart'));
    });
  });

  group('ItineraryFeasibilityService - Database Integration', () {
    late AppDatabase db;
    late ItineraryFeasibilityService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = const ItineraryFeasibilityService();
    });

    tearDown(() async {
      await db.close();
    });

    test('diagnoseDay and diagnoseTrip load from SQLite and verify feasibility', () async {
      // 1. Create a trip with startDate '2026-05-12' (Tuesday)
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_kyoto',
              title: 'Kyoto Anime Tour',
              ownerId: 'user_alice',
              startDate: const Value('2026-05-12'),
              dayCount: const Value(2),
            ),
          );

      // 2. Insert Day 1 (Tuesday) and Day 2 (Wednesday)
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_1',
              tripId: 'trip_kyoto',
              sortKey: 'a0',
              title: const Value('Day 1 - Demachi'),
              pinnedDate: const Value('2026-05-12'), // Tuesday
            ),
          );
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_2',
              tripId: 'trip_kyoto',
              sortKey: 'a1',
              title: const Value('Day 2 - Uji'),
              pinnedDate: const Value('2026-05-13'), // Wednesday
            ),
          );

      // 3. Insert stops
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_demachi',
              tripId: 'trip_kyoto',
              placeKey: 'p_demachi',
              name: 'Demachi Masugata',
              lat: 35.0305,
              lng: 135.7705,
              businessHours: const Value('10:00～18:00 (定休日: 火曜日)'),
              addedBy: 'user_alice',
            ),
          );
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_uji',
              tripId: 'trip_kyoto',
              placeKey: 'p_uji',
              name: 'Uji Bridge',
              lat: 34.8905,
              lng: 135.8080,
              businessHours: const Value('年中無休'),
              addedBy: 'user_alice',
            ),
          );

      // 4. Schedule demachi on Day 1 (Tuesday - conflict!)
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'sch_1',
              tripId: 'trip_kyoto',
              stopId: 'stop_demachi',
              dayId: 'day_1',
              sortKey: 'a0',
              stayMinutes: const Value(60),
              transitMinutes: const Value(15),
            ),
          );

      // Schedule uji on Day 2 (Wednesday - valid!)
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'sch_2',
              tripId: 'trip_kyoto',
              stopId: 'stop_uji',
              dayId: 'day_2',
              sortKey: 'a0',
              stayMinutes: const Value(60),
              transitMinutes: const Value(20),
            ),
          );

      // Diagnose Day 1
      final day1Report = await service.diagnoseDay(db, 'trip_kyoto', 'day_1');
      expect(day1Report.isFeasible, isFalse);
      expect(day1Report.errorCount, 1);
      expect(day1Report.issues.first.type, FeasibilityIssueType.closedOnDay);

      // Diagnose Day 2
      final day2Report = await service.diagnoseDay(db, 'trip_kyoto', 'day_2');
      expect(day2Report.isFeasible, isTrue);
      expect(day2Report.errorCount, 0);

      // Diagnose Entire Trip
      final tripReport = await service.diagnoseTrip(db, 'trip_kyoto');
      expect(tripReport.isFeasible, isFalse);
      expect(tripReport.days.length, 2);
      expect(tripReport.errorCount, 1);
    });

    test('Riverpod providers evaluate trip and day feasibility asynchronously', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          itineraryFeasibilityServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_riv',
              title: 'Riverpod Trip',
              ownerId: 'user_bob',
            ),
          );

      final tripReport = await container.read(tripFeasibilityProvider('trip_riv').future);
      expect(tripReport.tripId, 'trip_riv');
      expect(tripReport.isFeasible, isTrue);
    });
  });
}
