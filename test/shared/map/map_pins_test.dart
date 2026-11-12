import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/shared/map/app_map.dart';

MapPin pin(String id, double lat, double lng, {String? label, bool selected = false, bool done = false, int count = 1}) =>
    MapPin(
      id: id,
      point: LatLng(lat, lng),
      name: id,
      color: Colors.purple,
      label: label,
      selected: selected,
      done: done,
      count: count,
    );

void main() {
  group('clusterPins', () {
    // About 30 m apart in Uji, and one 2 km away.
    final near = [pin('a', 34.8890, 135.8077), pin('b', 34.8892, 135.8079), pin('c', 34.8894, 135.8075)];
    final far = pin('d', 34.9050, 135.8200);

    test('merges pins that crowd when zoomed out, and splits them when zoomed in', () {
      final out = clusterPins([...near, far], zoom: 12);
      expect(out, hasLength(2));
      expect(out.first.pins.map((p) => p.id), ['a', 'b', 'c']);
      expect(out.first.point, near.first.point, reason: 'a cluster sits on its first pin, so it does not drift');
      expect(out.last.single, isTrue);

      final close = clusterPins([...near, far], zoom: 19);
      expect(close, hasLength(4));
    });

    test('never merges the next pin, so its ring shows', () {
      final next = MapPin(id: 'b', point: const LatLng(34.8892, 135.8079), name: 'b', color: Colors.purple, next: true);
      final out = clusterPins([near[0], next, near[2]], zoom: 12);
      expect(out.where((c) => c.single && c.first.next), hasLength(1));
    });

    test('pins on top of each other still merge with a small radius', () {
      final same = [pin('a', 34.8890, 135.8077), pin('b', 34.88901, 135.80771), pin('c', 34.8894, 135.8075)];
      final out = clusterPins(same, zoom: 19, radius: 14);
      expect(out.map((c) => c.pins.length).toList(), [2, 1]);
    });

    test('never merges the selected pin', () {
      final out = clusterPins([near[0], pin('b', 34.8892, 135.8079, selected: true), near[2]], zoom: 12);
      expect(out.where((c) => c.single && c.first.selected), hasLength(1));
      expect(out, hasLength(2));
    });

    test("labels a cluster by its pins' numbers, or by how many stops it stands for", () {
      List<MapPin> numbered(List<String> labels) =>
          [for (final (i, l) in labels.indexed) pin('p$i', 34.889, 135.8077, label: l)];
      expect(PinCluster(numbered(['3', '4', '5']), const LatLng(0, 0)).label, '3–5');
      expect(PinCluster(numbered(['5', '3']), const LatLng(0, 0)).label, '3, 5');
      expect(PinCluster(numbered(['2', '2', '2']), const LatLng(0, 0)).label, '2', reason: 'all on Day 2');
      final plain = [pin('a', 0, 0, count: 3), pin('b', 0, 0)];
      expect(PinCluster(plain, const LatLng(0, 0)).label, '4', reason: "a group's stops each count");
    });

    test('is done only when every pin is', () {
      expect(PinCluster([pin('a', 0, 0, done: true), pin('b', 0, 0)], const LatLng(0, 0)).allDone, isFalse);
      expect(PinCluster([pin('a', 0, 0, done: true), pin('b', 0, 0, done: true)], const LatLng(0, 0)).allDone, isTrue);
    });

    test('handles a library of a few thousand places quickly', () {
      final many = [for (var i = 0; i < 3000; i++) pin('p$i', 34 + (i % 60) * 0.01, 135 + (i ~/ 60) * 0.01)];
      final watch = Stopwatch()..start();
      final out = clusterPins(many, zoom: 9);
      watch.stop();
      expect(out.fold<int>(0, (n, c) => n + c.pins.length), 3000);
      expect(out.length, lessThan(3000));
      expect(watch.elapsedMilliseconds, lessThan(200));
    });
  });

  test('gives each anime the same colour every time, and none its own', () {
    const none = Colors.green;
    expect(animeColor('label-1', none: none), animeColor('label-1', none: none));
    expect(animePalette, contains(animeColor('label-1', none: none)));
    expect(animeColor(null, none: none), none);
    final spread = {for (var i = 0; i < 40; i++) animeColor('anime-$i', none: none)};
    expect(spread.length, greaterThan(5), reason: 'works spread over the palette');
  });
}
