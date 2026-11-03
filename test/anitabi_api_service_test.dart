import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trip_planner/features/poi/services/anitabi_api_service.dart';
import 'package:trip_planner/features/poi/services/anitabi_static_data.dart';

const _host = 'https://w.junreimap.com/d';

/// A work record as `g.json` stores it: 18 positional fields, absent ones
/// written as `0`; `[12]` holds `id, lat, lng, priority` per spot.
List<Object> _work(int id, String cn, String title, List<Object> coords) => [
      id, cn, 0, title, '京都市', 0, 0, 0, 'TV', //
      35.0, 135.7, 11, coords, 0, 0, 0, 0, 0,
    ];

/// A spot row as `g<n>.json` stores it (15 fields). No image by default, so
/// imports queue no cover download and touch no files.
List<Object?> _row(String id, Object name, {Object cn = 0, Object image = 0}) =>
    [id, name, cn, 0, 0, 1, image, 0, 3, 125, '音乐室', 0, 0, name, 2];

String _index(List<Object> works, {String version = 'v1'}) =>
    jsonEncode([works, 250, version]);

String _page(int id, List<Object?> rows) => jsonEncode([
      [id, const [], rows, 1],
    ]);

http.Response _ok(String body) => http.Response.bytes(utf8.encode(body), 200);

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  late Directory cache;
  late List<http.Request> requests;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('anitabi_test_');
    requests = [];
    AnitabiStaticData.resetPreferredHost();
  });

  tearDown(() => cache.deleteSync(recursive: true));

  /// Serves [files] (by name) from the first static host; anything else 404s.
  MockClient serve(Map<String, String> files) => MockClient((request) async {
        requests.add(request);
        final url = request.url.toString();
        for (final MapEntry(:key, :value) in files.entries) {
          if (url == '$_host/$key') return _ok(value);
        }
        return http.Response('not found', 404);
      });

  final kOn = _work(1424, '轻音少女', 'けいおん！', [
    'a', 35.05, 135.79, 3, //
    'b', 35.2, 136.23, 1,
  ]);

  group('AnitabiStaticData.work', () {
    AnitabiStaticData data(http.Client client, {DateTime Function()? now}) =>
        AnitabiStaticData(
          client: client,
          cacheDir: () async => cache,
          now: now,
        );

    test('maps spot rows to API-shaped spots with coordinates', () async {
      final work = await data(serve({
        'g.json': _index([kOn]),
        'g0.json': _page(1424, [
          _row('a', '修学院駅', image: '/images/points/1424/a.jpg'),
          _row('c', '第10話アバン'), // no coordinates in g.json
        ]),
      })).work('1424');

      expect(work!.title, 'けいおん！');
      final a = work.spots[0];
      expect(a['id'], 'a');
      expect(a['name'], '修学院駅');
      expect(a['cn'], isNull); // `0` means absent
      expect(a['geo'], [35.05, 135.79]);
      expect(a['image'],
          'https://image.anitabi.cn/points/1424/a.jpg?plan=h160');
      expect(a['ep'], '3');
      expect(a['s'], 125);
      expect(a['mark'], '音乐室');
      expect(a['origin'], 'Anitabi');
      expect(a['originURL'],
          'https://anitabi.cn/map?bangumiId=1424&pid=a');
      expect(work.spots[1]['geo'], isNull);
    });

    test('returns null for a work Anitabi does not have', () async {
      final work = await data(serve({'g.json': _index([kOn])})).work('999');
      expect(work, isNull);
    });

    test('reuses the cached index for a day and pages per version',
        () async {
      var now = DateTime(2026, 10, 29, 12);
      var version = 'v1';
      final client = MockClient((request) async {
        requests.add(request);
        return switch (request.url.pathSegments.last) {
          'g.json' => _ok(_index([kOn], version: version)),
          'g0.json' => _ok(_page(1424, [_row('a', '修学院駅')])),
          _ => http.Response('not found', 404),
        };
      });
      Future<void> fetch() => data(client, now: () => now).work('1424');
      int count(String file) =>
          requests.where((r) => r.url.path.endsWith('/$file')).length;

      await fetch();
      await fetch();
      expect(count('g.json'), 1);
      expect(count('g0.json'), 1);

      // A day later the index is refreshed; an unchanged version keeps the
      // cached page, a new one re-fetches it.
      now = now.add(const Duration(hours: 25));
      await File('${cache.path}/g.json')
          .setLastModified(now.subtract(const Duration(hours: 25)));
      version = 'v2';
      await fetch();
      expect(count('g.json'), 2);
      expect(count('g0.json'), 2);
    });

    test('falls through hosts that are dead or serve a landing page',
        () async {
      final client = MockClient((request) async {
        requests.add(request);
        return switch (request.url.host) {
          'w.junreimap.com' => http.Response('gone', 502),
          'ww.anitabi.cn' => _ok('<!DOCTYPE html><html>moved</html>'),
          _ => switch (request.url.pathSegments.last) {
              'g.json' => _ok(_index([kOn])),
              _ => _ok(_page(1424, [_row('a', '修学院駅')])),
            },
        };
      });
      final work = await data(client).work('1424');
      expect(work!.spots, hasLength(1));
      // The page skips straight to the host that answered.
      final pageHosts = requests
          .where((r) => r.url.path.endsWith('/g0.json'))
          .map((r) => r.url.host);
      expect(pageHosts, ['www.anitabi.cn']);
    });

    test('reports a Cloudflare block when every host answers 403', () async {
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('Sorry, you have been blocked', 403);
      });
      await expectLater(
        data(client).work('1424'),
        throwsA(isA<AnitabiStaticDataUnavailableException>()
            .having((e) => e.blocked, 'blocked', isTrue)),
      );
      expect(requests, hasLength(AnitabiStaticData.defaultBaseUrls.length));
    });
  });

  group('AnitabiApiService.downloadReferenceImage', () {
    const url = 'https://image.anitabi.cn/points/1424/a.jpg?plan=h360';

    test('fetches a refused image from the mirror, asking each host once', () async {
      PathProviderPlatform.instance = _FakePathProvider(cache.path);
      final path = await AnitabiApiService.downloadReferenceImage(url, MockClient((request) async {
        requests.add(request);
        return request.url.host == 'img-tc.anitabi.cn'
            ? http.Response.bytes([0xFF, 0xD8, 0xFF], 200)
            : http.Response('blocked', 403);
      }));

      expect(File(path!).existsSync(), isTrue);
      expect(requests.map((r) => r.url.host), ['image.anitabi.cn', 'img-tc.anitabi.cn']);
    });

    test('gives up when both hosts refuse, without retrying', () async {
      PathProviderPlatform.instance = _FakePathProvider(cache.path);
      final path = await AnitabiApiService.downloadReferenceImage(url, MockClient((request) async {
        requests.add(request);
        return http.Response('blocked', 403);
      }));

      expect(path, isNull);
      expect(requests, hasLength(2));
    });
  });
}
