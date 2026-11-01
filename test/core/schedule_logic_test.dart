import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/utils/schedule_logic.dart';

void main() {
  group('ScheduleLogicEngine - Day Block Dates', () {
    test('computes consecutive dates from start date', () {
      final blocks = [
        const DayBlockInfo(id: 'b1', sortKey: 'a0'),
        const DayBlockInfo(id: 'b2', sortKey: 'a1'),
        const DayBlockInfo(id: 'b3', sortKey: 'a2'),
        const DayBlockInfo(id: 'b4', sortKey: 'a3'), // backup block
      ];

      final resolved = ScheduleLogicEngine.computeBlockDates(
        blocks: blocks,
        startDate: DateTime.utc(2027, 4, 1),
        dayCount: 3,
      );

      expect(resolved.length, equals(4));

      // Day 1
      expect(resolved[0].isBackup, isFalse);
      expect(resolved[0].date, equals(DateTime.utc(2027, 4, 1)));

      // Day 2
      expect(resolved[1].isBackup, isFalse);
      expect(resolved[1].date, equals(DateTime.utc(2027, 4, 2)));

      // Day 3
      expect(resolved[2].isBackup, isFalse);
      expect(resolved[2].date, equals(DateTime.utc(2027, 4, 3)));

      // Day 4 (backup)
      expect(resolved[3].isBackup, isTrue);
      expect(resolved[3].date, isNull);
    });

    test('pinned date sets date and subsequent blocks continue from pin', () {
      final blocks = [
        const DayBlockInfo(id: 'b1', sortKey: 'a0'),
        DayBlockInfo(id: 'b2', sortKey: 'a1', pinnedDate: DateTime.utc(2027, 4, 5)), // Jump to 4/5
        const DayBlockInfo(id: 'b3', sortKey: 'a2'),
      ];

      final resolved = ScheduleLogicEngine.computeBlockDates(
        blocks: blocks,
        startDate: DateTime.utc(2027, 4, 1),
        dayCount: 3,
      );

      expect(resolved[0].date, equals(DateTime.utc(2027, 4, 1)));
      expect(resolved[1].date, equals(DateTime.utc(2027, 4, 5)));
      expect(resolved[2].date, equals(DateTime.utc(2027, 4, 6))); // Continues from pin
    });

    test('rejects pins that do not strictly increase along order in validation, and marks conflict in computeBlockDates', () {
      final blocks = [
        DayBlockInfo(id: 'b1', sortKey: 'a0', pinnedDate: DateTime.utc(2027, 4, 5)),
        DayBlockInfo(id: 'b2', sortKey: 'a1', pinnedDate: DateTime.utc(2027, 4, 5)), // Same date
      ];

      expect(
        () => ScheduleLogicEngine.validatePinnedDates(blocks),
        throwsArgumentError,
      );

      final backwardsBlocks = [
        DayBlockInfo(id: 'b1', sortKey: 'a0', pinnedDate: DateTime.utc(2027, 4, 6)),
        DayBlockInfo(id: 'b2', sortKey: 'a1', pinnedDate: DateTime.utc(2027, 4, 4)), // Decreasing
      ];

      expect(
        () => ScheduleLogicEngine.validatePinnedDates(backwardsBlocks),
        throwsArgumentError,
      );

      // computeBlockDates does not throw on stored data; marks hasConflict = true
      final resolved = ScheduleLogicEngine.computeBlockDates(
        blocks: blocks,
        startDate: DateTime.utc(2027, 4, 1),
        dayCount: 2,
      );
      expect(resolved[1].hasConflict, isTrue);
      expect(resolved[0].date, isNot(equals(resolved[1].date)));

      // validatePinnedDates with startDate rejects pinning block 1 to the same date as unpinned block 0
      expect(
        () => ScheduleLogicEngine.validatePinnedDates(
          [
            const DayBlockInfo(id: 'b1', sortKey: 'a0'),
            DayBlockInfo(id: 'b2', sortKey: 'a1', pinnedDate: DateTime.utc(2027, 4, 1)),
          ],
          startDate: DateTime.utc(2027, 4, 1),
          dayCount: 2,
        ),
        throwsArgumentError,
      );

      // validatePinnedDates with startDate rejects pinning block 0 before startDate
      expect(
        () => ScheduleLogicEngine.validatePinnedDates(
          [
            DayBlockInfo(id: 'b1', sortKey: 'a0', pinnedDate: DateTime.utc(2027, 3, 31)),
          ],
          startDate: DateTime.utc(2027, 4, 1),
          dayCount: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ScheduleLogicEngine - Timeline Schedule Times', () {
    test('computes sequential start and end times with stay and transit', () {
      final items = [
        const ScheduleItemInfo(id: 's1', stopId: 'p1', dayId: 'd1', sortKey: 'a0', stayMinutes: 60, transitMinutes: 15),
        const ScheduleItemInfo(id: 's2', stopId: 'p2', dayId: 'd1', sortKey: 'a1', stayMinutes: 90, transitMinutes: 20),
      ];

      final timeline = ScheduleLogicEngine.computeScheduleTimes(items, defaultDayStartMinutes: 540); // 09:00

      expect(timeline.length, equals(2));

      // Stop 1: 09:00 to 10:00 (540 to 600)
      expect(timeline[0].startMinutes, equals(540));
      expect(timeline[0].endMinutes, equals(600));
      expect(timeline[0].startTimeFormatted, equals('09:00'));
      expect(timeline[0].endTimeFormatted, equals('10:00'));
      expect(timeline[0].hasConflict, isFalse);

      // Stop 2: Arrival at 10:15 (600 + 15 transit). Stay 90 min -> 11:45 (705)
      expect(timeline[1].startMinutes, equals(615));
      expect(timeline[1].endMinutes, equals(705));
      expect(timeline[1].startTimeFormatted, equals('10:15'));
      expect(timeline[1].endTimeFormatted, equals('11:45'));
      expect(timeline[1].hasConflict, isFalse);
    });

    test('supports fixed time and detects time conflict', () {
      final items = [
        const ScheduleItemInfo(id: 's1', stopId: 'p1', dayId: 'd1', sortKey: 'a0', stayMinutes: 120, transitMinutes: 30),
        // Item 1 ends at 09:00 + 120m = 11:00, transit 30m -> arrival 11:30 (690).
        // Item 2 has fixed time 11:00 (660 min) which is before arrival 11:30.
        const ScheduleItemInfo(id: 's2', stopId: 'p2', dayId: 'd1', sortKey: 'a1', fixedTimeMinutes: 660, stayMinutes: 60),
      ];

      final timeline = ScheduleLogicEngine.computeScheduleTimes(items, defaultDayStartMinutes: 540);

      expect(timeline[0].startMinutes, equals(540));
      expect(timeline[0].endMinutes, equals(660));

      expect(timeline[1].startMinutes, equals(660));
      expect(timeline[1].startTimeFormatted, equals('11:00'));
      expect(timeline[1].hasConflict, isTrue);
    });

    test('supports times past midnight / 24:00 (e.g. 25:30)', () {
      final items = [
        const ScheduleItemInfo(
          id: 's1',
          stopId: 'p1',
          dayId: 'd1',
          sortKey: 'a0',
          fixedTimeMinutes: 1530, // 25:30
          stayMinutes: 90,
        ),
      ];

      final timeline = ScheduleLogicEngine.computeScheduleTimes(items);
      expect(timeline[0].startMinutes, equals(1530));
      expect(timeline[0].endMinutes, equals(1620));
      expect(timeline[0].startTimeFormatted, equals('25:30'));
      expect(timeline[0].endTimeFormatted, equals('27:00'));

      expect(parseTimelineTimeString('25:30'), equals(1530));
      expect(formatTimelineMinutes(1530), equals('25:30'));
    });
  });

  group('ScheduleLogicEngine - Trip Status and Backlog', () {
    test('trip status planning / ongoing / finished', () {
      final blocks = ScheduleLogicEngine.computeBlockDates(
        blocks: [
          const DayBlockInfo(id: 'b1', sortKey: 'a0'),
          const DayBlockInfo(id: 'b2', sortKey: 'a1'),
        ],
        startDate: DateTime.utc(2027, 4, 10),
        dayCount: 2,
      );

      // Before start
      expect(
        ScheduleLogicEngine.computeTripStatus(
          resolvedBlocks: blocks,
          now: DateTime.utc(2027, 4, 9, 23, 59),
        ),
        equals(TripStatus.planning),
      );

      // During trip
      expect(
        ScheduleLogicEngine.computeTripStatus(
          resolvedBlocks: blocks,
          now: DateTime.utc(2027, 4, 10, 12, 0),
        ),
        equals(TripStatus.ongoing),
      );

      // On last day
      expect(
        ScheduleLogicEngine.computeTripStatus(
          resolvedBlocks: blocks,
          now: DateTime.utc(2027, 4, 11, 23, 59),
        ),
        equals(TripStatus.ongoing),
      );

      // After trip
      expect(
        ScheduleLogicEngine.computeTripStatus(
          resolvedBlocks: blocks,
          now: DateTime.utc(2027, 4, 12, 0, 1),
        ),
        equals(TripStatus.finished),
      );
    });

    test('backlog includes stops not scheduled', () {
      final allStops = ['stop_1', 'stop_2', 'stop_3', 'stop_4'];
      final items = [
        const ScheduleItemInfo(id: 'i1', stopId: 'stop_1', dayId: 'd1', sortKey: 'a0'),
        const ScheduleItemInfo(id: 'i2', stopId: 'stop_3', dayId: 'd1', sortKey: 'a1', status: 'done'),
        const ScheduleItemInfo(id: 'i3', stopId: 'stop_4', dayId: 'd1', sortKey: 'a2', status: 'skipped'),
      ];

      final backlog = ScheduleLogicEngine.computeBacklog(
        allTripStopIds: allStops,
        scheduleItems: items,
      );

      // stop_1 & stop_3 are scheduled
      // stop_2 is never scheduled -> in backlog
      // stop_4 was skipped -> in backlog
      expect(backlog, contains('stop_2'));
      expect(backlog, contains('stop_4'));
      expect(backlog, isNot(contains('stop_1')));
      expect(backlog, isNot(contains('stop_3')));
    });
  });
}

