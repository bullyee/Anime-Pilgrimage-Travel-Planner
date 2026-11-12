import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A pin on one of the app's maps (#roadmap v0.4.0, "The maps").
///
/// [id] must be stable for the same thing across rebuilds (a stop's or a
/// place's id): it keys the marker, so Flutter never reuses one pin's widget
/// for another while the map moves.
class MapPin {
  final String id;
  final LatLng point;

  /// Drawn inside the pin: a stop's number in the day, or null for a plain dot.
  final String? label;

  final Color color;

  /// Visited / done: drawn grey with a check.
  final bool done;

  /// The one picked: drawn larger, never merged into a cluster.
  final bool selected;

  /// The one to go to next: a ring around it, never merged into a cluster.
  final bool next;

  /// How many stops this pin stands for (a group of stops is one pin), shown
  /// as a small badge when more than one.
  final int count;

  /// Read by screen readers, and shown under the pin when [selected].
  final String name;

  const MapPin({
    required this.id,
    required this.point,
    required this.name,
    required this.color,
    this.label,
    this.done = false,
    this.selected = false,
    this.next = false,
    this.count = 1,
  });
}

/// Pins that sit within a few pixels of each other at a zoom, shown as one.
class PinCluster {
  /// In the order the pins were given; never empty.
  final List<MapPin> pins;

  /// Where the cluster is drawn: its first pin, so it doesn't drift as others
  /// join.
  final LatLng point;

  const PinCluster(this.pins, this.point);

  bool get single => pins.length == 1;
  MapPin get first => pins.first;

  /// Stops it stands for, counting each group's stops.
  int get count => pins.fold(0, (n, p) => n + p.count);

  bool get allDone => pins.every((p) => p.done);

  /// The text on the bubble: the pins' numbers when they all have one ("3–5",
  /// "3, 5", or "2" for stops all on Day 2), otherwise how many stops it
  /// stands for.
  String get label {
    final numbers = [for (final p in pins) int.tryParse(p.label ?? '')];
    if (numbers.every((n) => n != null)) {
      final unique = {for (final n in numbers) n!}.toList()..sort();
      if (unique.length == 1) return '${unique.single}';
      if (unique.length == 2) return '${unique.first}, ${unique.last}';
      return '${unique.first}–${unique.last}';
    }
    return '$count';
  }

  /// The pins' colour when they share one, else null.
  Color? get sharedColor {
    final c = pins.first.color;
    return pins.every((p) => p.color == c) ? c : null;
  }
}

/// Groups [pins] that lie within [radius] logical pixels of each other at
/// [zoom]. Greedy and stable: pins are taken in order, each joins the nearest
/// cluster started within [radius], or starts one. A [MapPin.selected] or
/// [MapPin.next] pin is never merged, so its ring always shows. A grid of [radius]-sized cells keeps it linear in the number
/// of pins, so a library of a few thousand places clusters in a few ms.
List<PinCluster> clusterPins(
  List<MapPin> pins, {
  required double zoom,
  double radius = 36,
  Crs crs = const Epsg3857(),
}) {
  final clusters = <_Building>[];
  final grid = <(int, int), List<_Building>>{};
  for (final pin in pins) {
    final at = crs.latLngToOffset(pin.point, zoom);
    if (pin.selected || pin.next || !at.dx.isFinite || !at.dy.isFinite) {
      clusters.add(_Building(pin, at));
      continue;
    }
    final cx = (at.dx / radius).floor();
    final cy = (at.dy / radius).floor();
    _Building? best;
    var bestDistance = radius * radius;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final c in grid[(cx + dx, cy + dy)] ?? const <_Building>[]) {
          final d = (c.at - at).distanceSquared;
          if (d <= bestDistance) {
            bestDistance = d;
            best = c;
          }
        }
      }
    }
    if (best != null) {
      best.pins.add(pin);
    } else {
      final c = _Building(pin, at);
      clusters.add(c);
      (grid[(cx, cy)] ??= []).add(c);
    }
  }
  return [for (final c in clusters) PinCluster(c.pins, c.pins.first.point)];
}

class _Building {
  final List<MapPin> pins;
  final Offset at;

  _Building(MapPin first, this.at) : pins = [first];
}

/// The bounds to show [points] in, or null for fewer than two.
CameraFit? fitPoints(List<LatLng> points, {EdgeInsets padding = const EdgeInsets.all(40), double maxZoom = 16}) {
  if (points.length < 2) return null;
  return CameraFit.coordinates(coordinates: points, padding: padding, maxZoom: maxZoom);
}
