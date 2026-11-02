import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A place a search found.
class FoundPlace {
  final String name;
  final String detail;
  final LatLng at;

  const FoundPlace({required this.name, required this.detail, required this.at});
}

/// The first link in [text], e.g. from a share sheet's "Uji Bridge
/// https://maps.app.goo.gl/…".
String? firstLink(String text) => RegExp(r'https?://\S+').firstMatch(text)?.group(0);

/// Whether [url] is a short Google Maps link, which has to be followed to
/// the full link before it shows coordinates.
bool isShortMapsLink(String url) =>
    RegExp(r'^https?://(maps\.app\.goo\.gl|goo\.gl/maps)/', caseSensitive: false).hasMatch(url);

final _number = r'(-?\d{1,3}(?:\.\d+)?)';

LatLng? _valid(String? lat, String? lng) {
  final a = double.tryParse(lat ?? '');
  final b = double.tryParse(lng ?? '');
  if (a == null || b == null || a.abs() > 90 || b.abs() > 180) return null;
  return LatLng(a, b);
}

/// Coordinates typed as text, like "34.8935, 135.8075", or null.
LatLng? typedCoordinates(String text) {
  final m = RegExp('^\\s*$_number\\s*[, ]\\s*$_number\\s*\$').firstMatch(text);
  return m == null ? null : _valid(m.group(1), m.group(2));
}

/// Coordinates in a full Google Maps link, or null. The place's own pin
/// (`!3dLAT!4dLNG`) wins over the map's centre (`/@LAT,LNG,17z`); links
/// also carry them as `q=`, `query=`, `ll=`, `destination=`, `daddr=` or
/// `/search/LAT,LNG`.
LatLng? coordinatesInMapsLink(String url) {
  final decoded = Uri.decodeFull(url.replaceAll('+', ' '));
  final pin = RegExp('!3d$_number!4d$_number').firstMatch(decoded);
  if (pin != null) return _valid(pin.group(1), pin.group(2));
  final at = RegExp('@$_number,$_number').firstMatch(decoded);
  if (at != null) return _valid(at.group(1), at.group(2));
  final param = RegExp('[?&](?:q|query|ll|destination|daddr|center)=$_number\\s*,\\s*$_number').firstMatch(decoded);
  if (param != null) return _valid(param.group(1), param.group(2));
  final search = RegExp('/search/$_number\\s*,\\s*$_number').firstMatch(decoded);
  if (search != null) return _valid(search.group(1), search.group(2));
  return null;
}

/// Finds places by name with OpenStreetMap's Nominatim, and follows short
/// Google Maps links.
///
/// Nominatim's usage policy (operations.osmfoundation.org/policies/nominatim)
/// allows at most one request a second, asks for a User-Agent that names the
/// app, and forbids searching as the user types. So the screens search only
/// when the user submits, and [search] spaces requests a second apart.
class PlaceSearch {
  PlaceSearch({http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  static const userAgent = 'TripPlanner/0.2 (+https://github.com/bullyee/trip_planner)';
  static const _gap = Duration(seconds: 1);

  final http.Client _client;
  final DateTime Function() _now;
  DateTime? _last;

  Future<List<FoundPlace>> search(String query, {String language = 'ja,en'}) async {
    final last = _last;
    if (last != null) {
      final wait = _gap - _now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _last = _now();
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '8',
      'accept-language': language,
    });
    final response = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (response.statusCode != 200) {
      throw PlaceSearchException('The place search answered ${response.statusCode}. Try again in a moment.');
    }
    final results = jsonDecode(utf8.decode(response.bodyBytes));
    if (results is! List) return const [];
    return [
      for (final r in results)
        if (r is Map)
          if (_valid('${r['lat']}', '${r['lon']}') case final at?)
            FoundPlace(
            name: (r['name'] as String?)?.trim().isNotEmpty == true ? r['name'] as String : '${r['display_name']}'.split(',').first,
            detail: '${r['display_name'] ?? ''}',
            at: at,
          ),
    ];
  }

  /// Follows a short Google Maps link through its redirects and reads the
  /// coordinates of the full link. Null when none turn up.
  Future<LatLng?> resolveShortLink(String url) async {
    var uri = Uri.parse(url);
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['User-Agent'] = userAgent;
      final response = await _client.send(request);
      await response.stream.drain<void>();
      final location = response.headers['location'];
      if (response.statusCode >= 300 && response.statusCode < 400 && location != null) {
        uri = uri.resolve(location);
        final found = coordinatesInMapsLink(uri.toString());
        if (found != null) return found;
        continue;
      }
      return coordinatesInMapsLink(uri.toString());
    }
    return null;
  }

  void close() => _client.close();
}

class PlaceSearchException implements Exception {
  final String message;

  const PlaceSearchException(this.message);

  @override
  String toString() => message;
}
