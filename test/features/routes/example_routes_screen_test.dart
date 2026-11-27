import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/routes/models/example_route.dart';
import 'package:trip_planner/features/routes/providers/example_routes_providers.dart';
import 'package:trip_planner/features/routes/screens/example_routes_screen.dart';
import 'package:trip_planner/shared/map/app_map.dart';

/// The list of example routes and a route's page, with **Copy this route**.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const route = ExampleRoute(
    id: 'kansai-uji',
    title: '宇治：吹響吧！上低音號',
    description: '京阪宇治站出發，走宇治川兩岸。',
    anime: ['響け！ユーフォニアム'],
    area: '京都府宇治市',
    groups: [
      RouteGroup(title: '宇治川', places: [
        RoutePlace(name: '宇治橋', lat: 34.8921, lng: 135.8075, frames: [
          RouteFrame(episode: '1', shot: RouteShot(lat: 34.8920, lng: 135.8079, note: '三の間')),
        ]),
        RoutePlace(name: '平等院表参道', lat: 34.8893, lng: 135.8081),
      ]),
    ],
    credits: [RouteCredit.anitabi],
  );
  final requested = <String>[];

  Future<GoRouter> open(WidgetTester tester, String location, {bool failing = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async {
      requested.add(req.url.path);
      if (failing) return http.Response('nope', 503);
      return switch (req.url.path) {
        '/routes/index.json' => http.Response.bytes(utf8.encode(jsonEncode(exampleRouteIndexToJson([route.summary]))), 200),
        '/routes/kansai-uji.json' => http.Response.bytes(utf8.encode(jsonEncode(route.toJson())), 200),
        _ => http.Response('missing', 404),
      };
    });
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(path: '/t', builder: (_, _) => const ExampleRoutesScreen()),
      GoRoute(path: '/t/:id', builder: (_, s) => ExampleRouteScreen(routeId: s.pathParameters['id']!)),
      GoRoute(path: '/trips/:id', builder: (_, s) => Scaffold(body: Text('trip ${s.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
        mapTilesProvider.overrideWithValue(false),
        exampleRoutesSourceProvider.overrideWithValue(ExampleRoutesSource(client, Uri.https('trip-planner-2775c.web.app', '/routes/'))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the list shows each route with its anime, area and counts, and opens it', (tester) async {
    await open(tester, '/t');
    expect(find.text('Example routes'), findsOneWidget);
    expect(find.text('宇治：吹響吧！上低音號'), findsOneWidget);
    expect(find.text('響け！ユーフォニアム · 京都府宇治市'), findsOneWidget);
    expect(find.text('2 places · 1 frame'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('route:kansai-uji')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exampleRoute')), findsOneWidget);
    expect(requested, containsAll(['/routes/index.json', '/routes/kansai-uji.json']));
    await close(tester);
  });

  testWidgets("a route's page: map, groups, places and spots; Copy this route makes a trip and opens it", (tester) async {
    await open(tester, '/t/kansai-uji');
    expect(find.byKey(const Key('routeMap')), findsOneWidget);
    expect(find.text('宇治川'), findsOneWidget);
    expect(find.text('宇治橋'), findsWidgets);
    expect(find.text('平等院表参道'), findsWidgets);
    expect(find.text('Spot only'), findsOneWidget, reason: 'a frame without a picture shows its spot');
    expect(find.text('三の間 · Ep. 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Anitabi (CC BY-NC-SA 4.0)'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Anitabi (CC BY-NC-SA 4.0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('routeCopy')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final trips = await tester.runAsync(() => db.select(db.trips).get());
    expect(trips!.single.title, '宇治：吹響吧！上低音號');
    expect(find.text('trip ${trips.single.id}'), findsOneWidget);
    await close(tester);
  });

  testWidgets('without a connection, the list says so and offers to try again', (tester) async {
    await open(tester, '/t', failing: true);
    expect(find.textContaining("Couldn't load the example routes"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await close(tester);
  });
}
