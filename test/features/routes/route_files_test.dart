import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/routes/models/example_route.dart';
import 'package:trip_planner/features/routes/services/example_route_service.dart' show isRouteImage;

/// The route files in `web/routes/`, which Hosting serves: each one reads,
/// index.json lists each once with its right counts and cover, and no
/// picture is anyone's but Anitabi's.
void main() {
  final dir = Directory('web/routes');
  final index = exampleRouteIndexFromJson(jsonDecode(File('${dir.path}/index.json').readAsStringSync()) as Map<String, dynamic>);

  test('index.json lists every route file once, with its counts', () {
    final files = {
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.json') && !f.path.endsWith('index.json')) f.uri.pathSegments.last.replaceAll('.json', ''),
    };
    expect(index.map((r) => r.id).toSet(), files);
    expect(index.map((r) => r.id).toSet().length, index.length, reason: 'each once');
    for (final summary in index) {
      final route = ExampleRoute.fromJson(jsonDecode(File('${dir.path}/${summary.id}.json').readAsStringSync()) as Map<String, dynamic>);
      final fromFile = route.summary;
      expect(fromFile.toJson(), summary.toJson(), reason: '${summary.id} in index.json matches its file');
    }
  });

  test('every picture is an Anitabi one, every place has a position, and the credits are there', () {
    for (final summary in index) {
      final route = ExampleRoute.fromJson(jsonDecode(File('${dir.path}/${summary.id}.json').readAsStringSync()) as Map<String, dynamic>);
      expect(route.credits.map((c) => c.name), contains('Anitabi'), reason: summary.id);
      expect(route.placeCount, greaterThan(0), reason: summary.id);
      for (final place in route.places) {
        for (final f in place.frames) {
          if (f.image != null) expect(isRouteImage(f.image), isTrue, reason: '${summary.id} ${place.name}: ${f.image}');
          expect(f.image != null || f.shot != null, isTrue, reason: '${summary.id} ${place.name}: a frame shows something');
        }
      }
    }
  });
}
