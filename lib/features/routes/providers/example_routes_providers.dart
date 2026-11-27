import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../sharing/invite_links.dart' show inviteLinkHosts;
import '../models/example_route.dart';

/// A developer's own copy of the route files, for trying new ones before
/// they're deployed: `--dart-define=EXAMPLE_ROUTES_BASE=http://localhost:8000/routes/`.
const _routesBaseOverride = String.fromEnvironment('EXAMPLE_ROUTES_BASE');

/// Where the route files are served: next to the web app, under `/routes/`.
/// The web app reads them from its own site; the phone from the hosted one.
Uri exampleRoutesBase() {
  if (_routesBaseOverride.isNotEmpty) return Uri.parse(_routesBaseOverride);
  return kIsWeb ? Uri.base.resolve('/routes/') : Uri.https(inviteLinkHosts.first, '/routes/');
}

/// The public link of a route: the web app's page for it, which the phone
/// opens in the app.
String exampleRouteLink(String id) => Uri.https(inviteLinkHosts.first, '/t/$id').toString();

/// Reads the route files.
class ExampleRoutesSource {
  final http.Client _client;
  final Uri _base;

  ExampleRoutesSource(this._client, this._base);

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await _client.get(_base.resolve(path)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}', _base.resolve(path));
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) throw const ExampleRouteFormatException('not an object');
    return body;
  }

  Future<List<ExampleRouteSummary>> index() async => exampleRouteIndexFromJson(await _get('index.json'));

  Future<ExampleRoute> route(String id) async {
    if (!isExampleRouteId(id)) throw ExampleRouteFormatException('bad route id "$id"');
    final route = ExampleRoute.fromJson(await _get('$id.json'));
    if (route.id != id) throw ExampleRouteFormatException('the file for "$id" says "${route.id}"');
    return route;
  }
}

final exampleRoutesSourceProvider = Provider<ExampleRoutesSource>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ExampleRoutesSource(client, exampleRoutesBase());
});

/// Every example route, for the list.
final exampleRouteIndexProvider = FutureProvider.autoDispose<List<ExampleRouteSummary>>(
  (ref) => ref.watch(exampleRoutesSourceProvider).index(),
);

/// One example route, by id.
final exampleRouteProvider = FutureProvider.autoDispose.family<ExampleRoute, String>(
  (ref, id) => ref.watch(exampleRoutesSourceProvider).route(id),
);
