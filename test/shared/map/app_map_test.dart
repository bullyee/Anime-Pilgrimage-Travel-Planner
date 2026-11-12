import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/shared/map/app_map.dart';

MapPin pin(String id, double lat, double lng, {String? label, bool selected = false}) =>
    MapPin(id: id, point: LatLng(lat, lng), name: 'Spot $id', color: Colors.purple, label: label, selected: selected);

Future<void> pumpMap(WidgetTester tester, AppMap map) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [mapTilesProvider.overrideWithValue(false)],
    child: MaterialApp(home: Scaffold(body: SizedBox(width: 400, height: 600, child: map))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('keys each pin by its id, and tags the selected one with its name', (tester) async {
    await pumpMap(
      tester,
      AppMap(pins: [pin('a', 34.88, 135.80, label: '1'), pin('b', 34.90, 135.83, label: '2', selected: true)]),
    );
    expect(find.byKey(const ValueKey('pin:a')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin:b')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Spot b'), findsOneWidget, reason: 'the selected pin carries its name');
    expect(find.text('Spot a'), findsNothing);
  });

  testWidgets('crowded pins are one bubble; tapping it zooms in to split them', (tester) async {
    final tapped = <String>[];
    await pumpMap(
      tester,
      AppMap(
        // About 30 m apart: one bubble at the fitted zoom (16), apart from 17.
        pins: [pin('a', 34.8890, 135.8077), pin('b', 34.8892, 135.8079), pin('c', 34.8894, 135.8075), pin('far', 34.95, 135.90)],
        onPinTap: (p) => tapped.add(p.id),
      ),
    );
    final bubble = find.byKey(const ValueKey('cluster:a'));
    expect(bubble, findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.text('3')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin:a')), findsNothing);

    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cluster:a')), findsNothing);
    expect(find.byKey(const ValueKey('pin:a')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin:b')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pin:b')));
    expect(tapped, ['b']);
  });

  testWidgets("pins on one spot that zooming can't split open as a list", (tester) async {
    List<String>? opened;
    await pumpMap(
      tester,
      AppMap(
        pins: [pin('a', 34.8890, 135.8077), pin('b', 34.8890, 135.8077), pin('far', 34.95, 135.90)],
        onClusterOpen: (pins) => opened = [for (final p in pins) p.id],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('cluster:a')));
    await tester.pumpAndSettle();
    expect(opened, ['a', 'b']);
  });

  testWidgets('fits the pins again when fitKey changes, without rebuilding the map', (tester) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    AppMap map(List<MapPin> pins, Object key) => AppMap(controller: controller, pins: pins, fitKey: key, cluster: false);
    await pumpMap(tester, map([pin('a', 34.88, 135.80), pin('b', 34.89, 135.81)], 1));
    final before = controller.camera.center;

    await pumpMap(tester, map([pin('c', 35.01, 135.76), pin('d', 35.02, 135.77)], 2));
    expect(controller.camera.center.latitude, closeTo(35.015, 0.01));
    expect(controller.camera.center, isNot(before));
    expect(find.byKey(const ValueKey('pin:c')), findsOneWidget);
  });

  testWidgets('draws the next pin over a bubble next to it', (tester) async {
    await pumpMap(
      tester,
      AppMap(pins: [
        MapPin(id: 'n', point: const LatLng(34.8890, 135.8077), name: 'Next', color: Colors.purple, label: '1', next: true),
        pin('a', 34.8891, 135.8078, label: '2'),
        pin('b', 34.8892, 135.8079, label: '3'),
        pin('far', 34.95, 135.90, label: '4'),
      ]),
    );
    final markers = tester.widgetList<Positioned>(find.descendant(of: find.byType(MarkerLayer), matching: find.byType(Positioned))).toList();
    final keys = [for (final m in markers) (m.key as ValueKey<String>?)?.value];
    expect(keys, contains('cluster:a'));
    expect(keys.indexOf('pin:n'), greaterThan(keys.indexOf('cluster:a')), reason: 'painted later, so on top');
  });

  testWidgets('tapping a bubble between zoom 16 and 17 zooms in without throwing', (tester) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await pumpMap(
      tester,
      AppMap(
        controller: controller,
        pins: [pin('a', 34.8890, 135.8077), pin('b', 34.8892, 135.8079), pin('c', 34.8894, 135.8075), pin('far', 34.95, 135.90)],
      ),
    );
    controller.move(const LatLng(34.8892, 135.8077), 16.3);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cluster:a')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cluster:a')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.camera.zoom, closeTo(clusterUntilZoom, 0.01));
    expect(find.byKey(const ValueKey('pin:a')), findsOneWidget);
  });
}
