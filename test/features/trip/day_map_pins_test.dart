import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/trip/widgets/day_map_pins.dart';

/// A day's pins are numbered only when the user ordered the day with times.
void main() {
  final t0 = DateTime(2027);
  PlannerItem item(String id, {int? fixedTime}) => PlannerItem(
        item: ScheduleItem(
          id: 'i-$id',
          tripId: 't',
          stopId: id,
          dayId: 'd',
          sortKey: id,
          stayMinutes: defaultStayMinutes,
          transitMinutes: 0,
          fixedTime: fixedTime,
          status: 'planned',
          updatedAt: t0,
          syncStatus: 0,
        ),
        stop: Stop(id: id, tripId: 't', placeKey: 'p-$id', name: id, lat: 0, lng: 0, addedBy: 'u1', createdAt: t0, updatedAt: t0, syncStatus: 0),
        startMinutes: 540,
        endMinutes: 600,
        fixed: fixedTime != null,
        conflict: false,
      );

  test('a day without times shows plain dots', () {
    final pins = dayMapPins([item('a'), item('b')], color: const Color(0xFF000000));
    expect(pins.map((p) => p.label), [null, null]);
  });

  test('a day with a time is numbered in its order', () {
    final pins = dayMapPins([item('a', fixedTime: 600), item('b')], color: const Color(0xFF000000));
    expect(pins.map((p) => p.label), ['1', '2']);
  });
}
