import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/models/duplicates.dart';
import 'package:trip_planner/features/library/services/place_search.dart';

Place _place(String key, String name, double lat, double lng) => Place(
      placeKey: key,
      name: name,
      lat: lat,
      lng: lng,
      visibility: 'saved',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('Google Maps links and typed coordinates', () {
    test('the place pin wins over the map centre', () {
      const url = 'https://www.google.com/maps/place/Uji+Bridge/@34.8936,135.8070,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d34.89352!4d135.80755';
      expect(coordinatesInMapsLink(url), const LatLng(34.89352, 135.80755));
    });

    test('the other forms Google shares', () {
      expect(coordinatesInMapsLink('https://www.google.com/maps/@34.8936,135.807,15z'), const LatLng(34.8936, 135.807));
      expect(coordinatesInMapsLink('https://maps.google.com/?q=34.8935,135.8075'), const LatLng(34.8935, 135.8075));
      expect(coordinatesInMapsLink('https://www.google.com/maps/search/?api=1&query=34.8935%2C135.8075'), const LatLng(34.8935, 135.8075));
      expect(coordinatesInMapsLink('https://www.google.com/maps/dir/?api=1&destination=34.8935,135.8075'), const LatLng(34.8935, 135.8075));
      expect(coordinatesInMapsLink('https://www.google.com/maps/search/34.8935,+135.8075'), const LatLng(34.8935, 135.8075));
      expect(coordinatesInMapsLink('https://www.google.com/maps/place/Uji+Bridge'), isNull);
      expect(coordinatesInMapsLink('https://maps.google.com/?q=134.8,195.8'), isNull, reason: 'out of range');
    });

    test('links inside shared text, short links and typed coordinates', () {
      expect(firstLink('宇治橋\nhttps://maps.app.goo.gl/AbCdEf123 (shared)'), 'https://maps.app.goo.gl/AbCdEf123');
      expect(isShortMapsLink('https://maps.app.goo.gl/AbCdEf123'), isTrue);
      expect(isShortMapsLink('https://www.google.com/maps/@1,2,3z'), isFalse);
      expect(typedCoordinates('34.8935, 135.8075'), const LatLng(34.8935, 135.8075));
      expect(typedCoordinates('34.8935 135.8075'), const LatLng(34.8935, 135.8075));
      expect(typedCoordinates('Uji Bridge'), isNull);
    });
  });

  group('PlaceSearch', () {
    test('searches Nominatim with the app\'s User-Agent and reads the results', () async {
      late http.Request seen;
      final search = PlaceSearch(client: MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {'name': '宇治橋', 'display_name': '宇治橋, 宇治市, 京都府, 日本', 'lat': '34.8935', 'lon': '135.8075'},
            {'name': '', 'display_name': 'Uji, Kyoto, Japan', 'lat': '34.88', 'lon': '135.80'},
            {'name': 'broken', 'display_name': 'x', 'lat': 'nope', 'lon': '1'},
          ])),
          200,
        );
      }));
      final found = await search.search('宇治橋');
      expect(seen.url.host, 'nominatim.openstreetmap.org');
      expect(seen.url.path, '/search');
      expect(seen.url.queryParameters['q'], '宇治橋');
      expect(seen.url.queryParameters['format'], 'jsonv2');
      expect(seen.headers['User-Agent'], PlaceSearch.userAgent);
      expect(found.map((f) => f.name), ['宇治橋', 'Uji'], reason: 'unnamed results take the first part of the address');
      expect(found.first.at, const LatLng(34.8935, 135.8075));
    });

    test('a failed search says so', () async {
      final search = PlaceSearch(client: MockClient((_) async => http.Response('busy', 429)));
      expect(search.search('x'), throwsA(isA<PlaceSearchException>()));
    });

    test('searches are spaced a second apart', () async {
      final search = PlaceSearch(client: MockClient((_) async => http.Response('[]', 200)));
      final watch = Stopwatch()..start();
      await search.search('a');
      await search.search('b');
      expect(watch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 950)));
    });

    test('a short link is followed to the coordinates of the full link', () async {
      final hops = <Uri>[];
      final search = PlaceSearch(client: MockClient((request) async {
        hops.add(request.url);
        if (request.url.host == 'maps.app.goo.gl') {
          return http.Response('', 302, headers: {'location': 'https://www.google.com/maps/place/x/@34.8935,135.8075,17z'});
        }
        return http.Response('', 200);
      }));
      expect(await search.resolveShortLink('https://maps.app.goo.gl/AbCdEf123'), const LatLng(34.8935, 135.8075));
      expect(hops, hasLength(1), reason: 'the redirect target already holds the coordinates');
    });
  });

  group('likelyDuplicate', () {
    final places = [
      _place('a', '宇治橋', 34.89350, 135.80750),
      _place('b', 'Byodoin', 34.88920, 135.80760),
      _place('c', 'Asagiri Bridge', 34.89120, 135.81140),
    ];

    test('a close place with a similar name is a likely duplicate', () {
      final match = likelyDuplicate(places, name: '宇治橋 (east bank)', at: const LatLng(34.89370, 135.80760));
      expect(match?.place.placeKey, 'a');
      expect(match!.meters, lessThan(50));
    });

    test('a very close place counts whatever its name; a far one never does', () {
      expect(likelyDuplicate(places, name: 'Something else', at: const LatLng(34.89355, 135.80752))?.place.placeKey, 'a');
      expect(likelyDuplicate(places, name: 'Something else', at: const LatLng(34.89390, 135.80750)), isNull);
      expect(likelyDuplicate(places, name: '宇治橋', at: const LatLng(34.90, 135.82)), isNull);
    });

    test('names compare without case, spaces or punctuation', () {
      expect(similarNames('Uji Bridge', 'uji-bridge!'), isTrue);
      expect(similarNames('Uji Bridge', 'Uji'), isTrue);
      expect(similarNames('Byodoin', 'Uji'), isFalse);
    });
  });
}
