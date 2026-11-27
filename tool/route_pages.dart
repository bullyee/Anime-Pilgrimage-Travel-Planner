// Writes a link-preview page for each example route into the web build:
// `build/web/t/<id>/index.html` and `build/web/t/index.html`. Run it after
// `flutter build web --wasm --release` and before `firebase deploy`:
//
//   dart run tool/route_pages.dart
//
// The routes come from `build/web/routes/` (copied there from `web/routes/`
// by the build). Each page is the web app's own index.html with the route's
// title, description and first picture as OpenGraph tags, so a link posted
// on Threads, X or PTT shows a preview card, and opening it starts the web
// app on the route.
import 'dart:convert';
import 'dart:io';

import 'package:trip_planner/features/routes/models/example_route.dart';
import 'package:trip_planner/features/routes/route_page_html.dart';

const _site = 'https://trip-planner-2775c.web.app';

void main(List<String> args) {
  final build = Directory(args.isEmpty ? 'build/web' : args.first);
  final index = File('${build.path}/index.html');
  final routesDir = Directory('${build.path}/routes');
  if (!index.existsSync() || !routesDir.existsSync()) {
    stderr.writeln('No web build with routes in ${build.path}: run `flutter build web --wasm --release` first.');
    exit(1);
  }
  final indexHtml = index.readAsStringSync();
  final list = exampleRouteIndexFromJson(jsonDecode(File('${routesDir.path}/index.json').readAsStringSync()) as Map<String, dynamic>);

  var written = 0;
  for (final summary in list) {
    final file = File('${routesDir.path}/${summary.id}.json');
    if (!file.existsSync()) {
      stderr.writeln('index.json lists ${summary.id}, but routes/${summary.id}.json is missing.');
      exit(1);
    }
    final route = ExampleRoute.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    final page = routePageHtml(
      indexHtml,
      title: route.title,
      description: route.description ?? [if (route.anime.isNotEmpty) route.anime.join('、'), ?route.area].join(' · '),
      image: route.cover,
      url: '$_site/t/${route.id}',
    );
    final out = File('${build.path}/t/${route.id}/index.html')..createSync(recursive: true);
    out.writeAsStringSync(page);
    written++;
  }
  File('${build.path}/t/index.html')
    ..createSync(recursive: true)
    ..writeAsStringSync(routePageHtml(
      indexHtml,
      title: '範例路線 · Trip Planner',
      description: '我們自己走過的動畫聖地巡禮路線，可以複製成自己的行程。',
      image: list.map((r) => r.cover).nonNulls.firstOrNull,
      url: '$_site/t',
    ));
  stdout.writeln('Wrote ${written + 1} pages under ${build.path}/t/.');
}
