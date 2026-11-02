import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/utils/schedule_logic.dart';
import 'package:trip_planner/features/trip/models/trip_summary.dart';
import 'package:trip_planner/features/trip/widgets/trip_card.dart';

Trip _trip(String id, {String? start, int days = 3, DateTime? created}) => Trip(
      id: id,
      title: id,
      ownerId: 'u1',
      sharing: 'private',
      startDate: start,
      dayCount: days,
      createdAt: created ?? DateTime(2027, 1, 1),
      updatedAt: DateTime(2027, 1, 1),
      syncStatus: 0,
    );

TripDay _day(String id, String sortKey, {String? pinned}) => TripDay(
      id: id,
      tripId: 't',
      sortKey: sortKey,
      pinnedDate: pinned,
      updatedAt: DateTime(2027, 1, 1),
      syncStatus: 0,
    );

DateTime _utc(int y, int m, int d) => DateTime.utc(y, m, d);

void main() {
  group('TripSummary.from', () {
    test('dates follow the start date, and a pin moves the days after it', () {
      final summary = TripSummary.from(
        trip: _trip('t', start: '2027-04-29', days: 3),
        days: [_day('a', 'a0'), _day('b', 'a1'), _day('c', 'a2', pinned: '2027-05-03')],
        stopCount: 4,
        now: DateTime(2027, 4, 30, 12),
      );
      expect(summary.firstDate, _utc(2027, 4, 29));
      expect(summary.lastDate, _utc(2027, 5, 3));
      expect(summary.dayCount, 3);
      expect(summary.stopCount, 4);
      expect(summary.status, TripStatus.ongoing);
    });

    test('backup days are not counted and have no date', () {
      final summary = TripSummary.from(
        trip: _trip('t', start: '2027-04-29', days: 2),
        days: [_day('a', 'a0'), _day('b', 'a1'), _day('backup', 'a2')],
        stopCount: 0,
        now: DateTime(2027, 1, 1),
      );
      expect(summary.dayCount, 2);
      expect(summary.lastDate, _utc(2027, 4, 30));
      expect(summary.status, TripStatus.planning);
    });

    test('while the days load, dates come from the start date and day count', () {
      final summary = TripSummary.from(
        trip: _trip('t', start: '2027-04-29', days: 12),
        days: null,
        stopCount: 0,
        now: DateTime(2027, 6, 1),
      );
      expect(summary.dayCount, 12);
      expect(summary.lastDate, _utc(2027, 5, 10));
      expect(summary.status, TripStatus.finished);
    });

    test('a trip without a start date has no dates and is being planned', () {
      final summary = TripSummary.from(
        trip: _trip('t', days: 2),
        days: [_day('a', 'a0'), _day('b', 'a1')],
        stopCount: 0,
        now: DateTime(2027, 6, 1),
      );
      expect(summary.firstDate, isNull);
      expect(summary.status, TripStatus.planning);
    });
  });

  test('the list puts trips under way first, then upcoming, undated and finished ones', () {
    final now = DateTime(2027, 5, 1, 9);
    TripSummary s(Trip t) => TripSummary.from(trip: t, days: null, stopCount: 0, now: now);
    final sorted = sortTripSummaries([
      s(_trip('finished early', start: '2027-01-02', days: 2)),
      s(_trip('undated old', created: DateTime(2027, 1, 1))),
      s(_trip('upcoming later', start: '2027-08-01')),
      s(_trip('finished recently', start: '2027-04-20', days: 3)),
      s(_trip('ongoing', start: '2027-04-30')),
      s(_trip('undated new', created: DateTime(2027, 3, 1))),
      s(_trip('upcoming soon', start: '2027-05-10')),
    ]);
    expect(sorted.map((t) => t.trip.id), [
      'ongoing',
      'upcoming soon',
      'upcoming later',
      'undated new',
      'undated old',
      'finished recently',
      'finished early',
    ]);
  });

  group('tripDateLine', () {
    final now = DateTime(2027, 3, 1);
    test('shows the range and the number of days', () {
      expect(
        tripDateLine(firstDate: _utc(2027, 4, 29), lastDate: _utc(2027, 5, 4), dayCount: 6, now: now),
        'Apr 29 – May 4 · 6 days',
      );
    });
    test('adds the year for another year, and handles one day', () {
      expect(
        tripDateLine(firstDate: _utc(2028, 1, 3), lastDate: _utc(2028, 1, 3), dayCount: 1, now: now),
        'Jan 3, 2028 · 1 day',
      );
    });
    test('says when there are no dates yet', () {
      expect(tripDateLine(firstDate: null, lastDate: null, dayCount: 3, now: now), 'No dates yet · 3 days');
    });
  });
}
