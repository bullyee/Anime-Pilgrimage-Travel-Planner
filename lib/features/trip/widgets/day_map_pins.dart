import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/map/map_pins.dart';
import '../../planner/models/planner_view.dart';

/// A day's stops as map pins, the same on Home's small map and the day map:
/// one pin per block of the plan (a group's stops that follow each other are
/// one pin, with a badge saying how many), numbered in the day's order, grey
/// with a check once every stop in it is visited.
///
/// The pin's id is its first stop's, so it stays the same pin while stops are
/// visited.
List<MapPin> dayMapPins(
  List<PlannerItem> items, {
  required Color color,
  String? selectedStopId,
  String? nextStopId,
}) =>
    [
      for (final (i, block) in planBlocks(items).indexed)
        MapPin(
          id: block.first.stop.id,
          point: blockPoint(block),
          name: block.group ?? block.first.stop.name,
          label: '${i + 1}',
          color: color,
          done: block.items.every((it) => it.done),
          selected: selectedStopId != null && block.items.any((it) => it.stop.id == selectedStopId),
          next: nextStopId != null && block.items.any((it) => it.stop.id == nextStopId),
          count: block.items.length,
        ),
    ];

/// Where a block's pin goes: the middle of its stops.
LatLng blockPoint(PlannerBlock block) {
  final n = block.items.length;
  final lat = block.items.fold<double>(0, (s, it) => s + it.stop.lat) / n;
  final lng = block.items.fold<double>(0, (s, it) => s + it.stop.lng) / n;
  return LatLng(lat, lng);
}

/// The block [stopId] is in, among [items]' blocks.
PlannerBlock? blockOfStop(List<PlannerItem> items, String stopId) {
  for (final b in planBlocks(items)) {
    if (b.items.any((it) => it.stop.id == stopId)) return b;
  }
  return null;
}
