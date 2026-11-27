import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/routes/models/example_route.dart';
import 'package:trip_planner/features/routes/route_page_html.dart';
import 'package:trip_planner/features/routes/services/example_route_service.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

/// Example routes: the file format, making one from a trip, copying one into
/// a private trip, and the link page.
void main() {
  const ujiImage = 'https://image.anitabi.cn/points/115908/abc.jpg?plan=h360';

  ExampleRoute sample() => const ExampleRoute(
        id: 'kansai-uji',
        title: '宇治：吹響吧！上低音號',
        description: '京阪宇治站出發，走宇治川兩岸。',
        anime: ['響け！ユーフォニアム'],
        area: '京都府宇治市',
        updated: '2026-11-27',
        groups: [
          RouteGroup(title: '宇治川', places: [
            RoutePlace(name: '宇治橋', lat: 34.8921, lng: 135.8075, about: '橋上車多，靠西側拍。', frames: [
              RouteFrame(
                image: ujiImage,
                anime: '響け！ユーフォニアム',
                episode: '1',
                seconds: 754,
                shot: RouteShot(lat: 34.8920, lng: 135.8079, heading: 270, note: '三の間'),
                source: 'anitabi',
                sourceUrl: 'https://anitabi.cn/map?bangumiId=115908',
              ),
              RouteFrame(shot: RouteShot(lat: 34.8918, lng: 135.8069, note: '西詰')),
            ]),
            RoutePlace(name: '平等院表参道', lat: 34.8893, lng: 135.8081),
          ]),
          RouteGroup(places: [RoutePlace(name: '大吉山展望台', lat: 34.8957, lng: 135.8146)]),
        ],
        credits: [RouteCredit.anitabi],
      );

  group('the format', () {
    test('a route survives a round trip through JSON, with its counts and cover', () {
      final back = ExampleRoute.fromJson(sample().toJson());
      expect(back.toJson(), sample().toJson());
      expect(back.placeCount, 3);
      expect(back.frameCount, 2);
      expect(back.cover, ujiImage);
      final first = back.groups.first.places.first;
      expect(first.frames.first.shot!.heading, 270);
      expect(first.frames.last.image, isNull, reason: 'a frame shown by its spot only');
      expect(back.groups.last.title, isNull);
      final summary = back.summary;
      expect((summary.places, summary.frames, summary.cover), (3, 2, ujiImage));
      final index = exampleRouteIndexFromJson(exampleRouteIndexToJson([summary]));
      expect(index.single.id, 'kansai-uji');
      expect(index.single.anime, ['響け！ユーフォニアム']);
    });

    test('a file that would be read wrong is refused', () {
      Map<String, dynamic> json() => sample().toJson();
      void refused(Map<String, dynamic> j, String why) =>
          expect(() => ExampleRoute.fromJson(j), throwsA(isA<ExampleRouteFormatException>()), reason: why);
      refused(json()..['format'] = 2, 'a newer format');
      refused(json()..remove('format'), 'no format');
      refused(json()..['id'] = 'Kansai Uji', 'an id that is no path segment');
      refused(json()..['id'] = '../index', 'an id that climbs out');
      refused(json()..remove('title'), 'no title');
      final badImage = json();
      ((badImage['groups'] as List).first['places'] as List).first['frames'] = [
        {'image': 'http://example.com/x.jpg'},
      ];
      refused(badImage, 'a picture not on https');
      final badLat = json();
      ((badLat['groups'] as List).first['places'] as List).first['lat'] = 123.0;
      refused(badLat, 'a latitude out of range');
      expect(isExampleRouteId('kansai-uji'), isTrue);
      expect(isExampleRouteId('kansai--uji'), isFalse);
      expect(isExampleRouteId('a' * 61), isFalse);
    });

    test('ids from titles keep Latin letters and digits, or fall back to route', () {
      expect(exampleRouteIdOf('Kansai: Uji (2026)'), 'kansai-uji-2026');
      expect(exampleRouteIdOf('關西聖地巡禮'), 'route');
      expect(isExampleRouteId(exampleRouteIdOf('x' * 100)), isTrue);
    });
  });

  group('with a database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a trip becomes a route: days as groups, Anitabi pictures, spots without other pictures, nothing private', () async {
      final repo = DriftTripRepository(db, null, 'u1');
      final trip = await repo.createTrip(title: 'Kansai Uji', description: 'Two days by the river.', ownerId: 'u1', startDate: '2026-06-17', dayCount: 2);
      final days = await repo.getDaysForTrip(trip.id);
      await repo.updateDayBlock(TripDaysCompanion(id: Value(days[0].id), title: const Value('宇治川')));
      final bridge = await repo.createTripOnlySpot(tripId: trip.id, name: '宇治橋', lat: 34.8921, lng: 135.8075, addedBy: 'u1');
      await repo.updateStop(StopsCompanion(id: Value(bridge.id), note: const Value('private: meet Mika here')));
      final park = await repo.createTripOnlySpot(tripId: trip.id, name: '宇治公園', lat: 34.8890, lng: 135.8100, addedBy: 'u1');
      await repo.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: days[0].id);
      Future<void> frame(String id, String stopId, {String? remote, String? local, String? note, double? lat, double? lng}) =>
          db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
                id: id,
                stopId: Value(stopId),
                remoteUrl: Value(remote),
                localPath: Value(local),
                note: Value(note),
                lat: Value(lat),
                lng: Value(lng),
                episode: const Value('3'),
                source: Value(remote == null ? null : 'anitabi'),
              ));
      await frame('a', bridge.id, remote: ujiImage, note: '三の間', lat: 34.8920, lng: 135.8079);
      await frame('own', bridge.id, local: '/frames/mine.png', note: '西詰');
      await frame('drive', bridge.id, remote: 'https://drive.google.com/uc?id=xyz');
      await frame('bare', park.id, local: '/frames/park.png');

      final view = buildPlannerView(
        trip: (await repo.getTrip(trip.id))!,
        days: await repo.getDaysForTrip(trip.id),
        stops: await repo.getStopsForTrip(trip.id),
        items: await repo.getScheduleItemsForTrip(trip.id),
      );
      final frames = await db.select(db.newReferenceImages).get();
      final out = exportExampleRoute(trip: trip, view: view, frames: frames, anime: const ['響け！ユーフォニアム'], now: DateTime.utc(2026, 11, 27));
      final route = out.route;
      expect(route.id, 'kansai-uji');
      expect(route.updated, '2026-11-27');
      expect(route.groups.map((g) => g.title), ['宇治川', null], reason: 'the empty Day 2 is left out; Unsorted comes last, untitled');
      expect(route.groups.first.places.single.name, '宇治橋');
      expect(route.groups.last.places.single.name, '宇治公園');
      final shown = route.groups.first.places.single.frames;
      expect(shown.map((f) => f.image), [ujiImage, null], reason: "the Anitabi picture; the user's own frame keeps its spot only");
      expect(shown.map((f) => f.shot?.note), ['三の間', '西詰']);
      expect(shown.last.shot!.lat, 34.8921, reason: 'a frame nobody placed is shot from its place');
      expect((out.skippedFrames, out.framesWithoutPicture), (2, 1), reason: 'the Drive link and the bare frame have neither picture nor spot');
      final json = route.toJson().toString();
      expect(json, isNot(contains('Mika')), reason: "a stop's note never leaves");
      expect(json, isNot(contains('2026-06-17')), reason: 'nor do dates');
      expect(json, isNot(contains('drive.google.com')));
    });

    test('copying a route makes a private trip: a day per group, the places on them, frames with their spots', () async {
      final repo = DriftTripRepository(db, null, 'u1');
      final trip = await copyExampleRoute(db: db, repo: repo, route: sample(), ownerId: 'u1');
      expect(trip.title, '宇治：吹響吧！上低音號');
      expect(trip.sharing, isNot('group'));
      expect(trip.startDate, isNull, reason: 'dates are the user’s to add');
      final days = await repo.getDaysForTrip(trip.id);
      expect(days.map((d) => d.title), ['宇治川', null]);
      final view = buildPlannerView(
        trip: (await repo.getTrip(trip.id))!,
        days: days,
        stops: await repo.getStopsForTrip(trip.id),
        items: await repo.getScheduleItemsForTrip(trip.id),
      );
      expect(view.days.map((d) => d.items.map((it) => it.stop.name).toList()), [
        ['宇治橋', '平等院表参道'],
        ['大吉山展望台'],
      ]);
      final bridge = view.days.first.items.first.stop;
      expect(bridge.accessTips, '橋上車多，靠西側拍。');
      final frames = await repo.getReferenceImagesForStop(bridge.id);
      expect(frames.map((f) => f.remoteUrl), unorderedEquals([ujiImage, null]));
      final pictured = frames.firstWhere((f) => f.remoteUrl != null);
      expect((pictured.note, pictured.heading, pictured.episode, pictured.timestampS), ('三の間', 270, '1', 754));
      expect(pictured.lat, 34.8920);
      final places = await db.select(db.places).get();
      expect(places, hasLength(3), reason: 'trip-only places');
      expect(places.every((p) => p.visibility == 'trip_only'), isTrue);
    });
  });

  test('the link page is the web app with the route as preview tags', () {
    const index = '<!DOCTYPE html><html><head><base href="/">'
        '<meta name="description" content="Plan your anime pilgrimages.">'
        '<title>Anime Pilgrimage Travel Planner</title></head><body><script src="flutter_bootstrap.js" async></script></body></html>';
    final html = routePageHtml(
      index,
      title: '宇治 & "上低音號"',
      description: '京阪宇治站出發，\n走宇治川兩岸。',
      image: ujiImage,
      url: 'https://trip-planner-2775c.web.app/t/kansai-uji',
    );
    expect(html, contains('<title>宇治 &amp; &quot;上低音號&quot;</title>'));
    expect(html, contains('<meta property="og:title" content="宇治 &amp; &quot;上低音號&quot;">'));
    expect(html, contains('<meta name="description" content="京阪宇治站出發， 走宇治川兩岸。">'));
    expect(html, contains('<meta property="og:image" content="https://image.anitabi.cn/points/115908/abc.jpg?plan=h360">'));
    expect(html, contains('summary_large_image'));
    expect(html, contains('<base href="/">'), reason: 'the app still loads from the site root');
    expect(html, contains('flutter_bootstrap.js'));
    expect(html.indexOf('og:url'), lessThan(html.indexOf('</head>')));
  });
}
