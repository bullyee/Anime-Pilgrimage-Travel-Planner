import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/l10n/l10n.dart';
import 'package:trip_planner/features/trip/models/place_spots.dart';
import 'package:trip_planner/features/trip/providers/trip_stop_providers.dart';

void main() {
  final t0 = DateTime(2027, 6, 19, 10);

  Stop stop(String id, String name, {String? area, String? note, double lat = 34.892, double lng = 135.8075}) => Stop(
        id: id,
        tripId: 't',
        placeKey: 'p-$id',
        name: name,
        lat: lat,
        lng: lng,
        area: area,
        note: note,
        addedBy: 'u1',
        createdAt: t0,
        updatedAt: t0,
        syncStatus: 0,
      );

  NewReferenceImage frame(String id, {String? path, String? url, String? note, double? lat, double? lng, String? stopId}) =>
      NewReferenceImage(id: id, localPath: path ?? '$id.png', remoteUrl: url, note: note, lat: lat, lng: lng, stopId: stopId, createdAt: t0);

  Photo photo(String id, {String? ref, DateTime? at}) => Photo(
        id: id,
        placeKey: 'p',
        kind: 'original',
        referenceImageId: ref,
        localPath: '$id.jpg',
        isShared: false,
        keepAsIs: false,
        takenAt: at,
        createdAt: t0,
      );

  group('spotLabel', () {
    test('the note wins, first line only', () {
      expect(spotLabel(stop('a', '宇治橋 三の間', area: '宇治橋', note: '第 3 根柱子北側\n往上游'), '宇治橋'), '第 3 根柱子北側');
    });
    test('the group name in front is left out', () {
      expect(spotLabel(stop('a', '宇治橋 三の間', area: '宇治橋'), '宇治橋'), '三の間');
      expect(spotLabel(stop('a', '宇治橋・東詰', area: '宇治橋'), '宇治橋'), '東詰');
      expect(spotLabel(stop('a', 'Uji Bridge, west bank', area: 'Uji Bridge'), 'Uji Bridge'), 'west bank');
    });
    test('else the whole name', () {
      expect(spotLabel(stop('a', '宇治橋', area: '宇治橋'), '宇治橋'), '宇治橋', reason: 'nothing after the group name');
      expect(spotLabel(stop('a', '平等院'), null), '平等院');
      expect(spotLabel(stop('a', 'Gate', area: 'Cafe Rose'), 'Cafe Rose'), 'Gate');
    });
  });

  test('placeEntries: the stop\'s group, or the stop alone', () {
    final entries = [
      TripStopEntry(stop: stop('a', 'A', area: 'Rose')),
      TripStopEntry(stop: stop('b', 'B')),
      TripStopEntry(stop: stop('c', 'C', area: 'Rose')),
    ];
    expect([for (final e in placeEntries(entries, 'c')) e.stop.id], ['a', 'c']);
    expect([for (final e in placeEntries(entries, 'b')) e.stop.id], ['b']);
    expect(placeEntries(entries, 'gone'), isEmpty);
  });

  test('byDistance: nearest first, list order without a position', () {
    final near = stop('near', 'N', lat: 34.8921, lng: 135.8076);
    final far = stop('far', 'F', lat: 34.8800, lng: 135.8200);
    LatLng at(Stop s) => LatLng(s.lat, s.lng);
    expect(byDistance([far, near], at), [far, near]);
    expect(byDistance([far, near], at, lat: 34.892, lng: 135.8075), [near, far]);
    expect(distanceText(42), '40 m');
    expect(distanceText(1234), '1.2 km');
  });

  group('placeSpots', () {
    final place = stop('p', '宇治橋', lat: 34.8920, lng: 135.8080);
    List<PlaceSpot> spotsOf(List<NewReferenceImage> frames, {List<Stop>? stops, String? group}) =>
        placeSpots(stops: stops ?? [place], group: group, framesOf: (s) => [for (final f in frames) if ((f.stopId ?? 'p') == s.id) f]);

    test('the same note close together is one spot, at the mean position', () {
      final spots = spotsOf([
        frame('a', note: '三の間', lat: 34.89210, lng: 135.80750),
        frame('b', note: '三の間', lat: 34.89218, lng: 135.80750), // about 9 m north
        frame('c', note: '東詰', lat: 34.89180, lng: 135.80900),
      ]);
      expect([for (final s in spots) s.label], ['三の間', '東詰']);
      expect([for (final f in spots.first.frames) f.id], ['a', 'b']);
      expect(spots.first.lat, closeTo(34.89214, 1e-9));
      expect(spots.first.key, 'a');
      expect(spots.first.estimated, isFalse);
    });

    test('the same note far apart, or different notes in one place, are separate spots', () {
      final spots = spotsOf([
        frame('a', note: '三の間', lat: 34.8921, lng: 135.8075),
        frame('b', note: '三の間', lat: 34.8925, lng: 135.8075), // about 45 m away
        frame('c', note: '柱の陰', lat: 34.8921, lng: 135.8075),
      ]);
      expect([for (final s in spots) s.key], ['a', 'b', 'c']);
    });

    test('frames without a position are about at the stop, and without a note go by its name', () {
      final spots = spotsOf([frame('a'), frame('b')]);
      final spot = spots.single;
      expect(spot.label, '宇治橋');
      expect(spot.frames, hasLength(2));
      expect(spot.estimated, isTrue);
      expect((spot.lat, spot.lng), (34.8920, 135.8080));
    });

    test('a group not folded yet: each stop\'s frames are its spots, and a stop without frames is one', () {
      final bay = stop('bay', '宇治橋 三の間', area: '宇治橋', lat: 34.8921, lng: 135.8075);
      final gate = stop('gate', '宇治橋 東詰', area: '宇治橋', lat: 34.8918, lng: 135.8090);
      final spots = spotsOf([frame('a', stopId: 'bay'), frame('b', stopId: 'bay', note: '柱の陰')], stops: [bay, gate], group: '宇治橋');
      expect([for (final s in spots) s.label], ['三の間', '柱の陰', '東詰']);
      expect(spots.last.key, 'stop:gate');
      expect(spots.last.frames, isEmpty);
      expect(spots.last.estimated, isFalse);
    });

    test('placeFramesOf: the stop\'s copy wins over the library\'s frame', () {
      final copy = frame('copy', path: 'a.png', note: '三の間');
      final lib = frame('lib', path: 'a.png');
      final other = frame('other', path: 'b.png');
      expect([for (final f in placeFramesOf(own: [copy], library: [lib, other])) f.id], ['copy', 'other']);
    });
  });

  group('shotFrames', () {
    test('by the frame\'s id, newest photo', () {
      final f = frame('f1', path: 'a.png');
      final shot = shotFrames(shown: [f], all: [f], photos: [
        photo('old', ref: 'f1', at: t0),
        photo('new', ref: 'f1', at: t0.add(const Duration(hours: 1))),
      ]);
      expect(shot['f1']!.id, 'new');
    });
    test('a photo of a hidden copy of the frame counts for the one shown', () {
      final shown = frame('place-f', path: 'a.png');
      final copy = frame('stop-f', path: 'a.png');
      final shot = shotFrames(shown: [shown], all: [shown, copy], photos: [photo('p', ref: 'stop-f')]);
      expect(shot.keys, ['place-f']);
    });
    test('photos of nothing, or of another frame, don\'t count', () {
      final f = frame('f1', path: 'a.png');
      final g = frame('f2', path: 'b.png');
      final shot = shotFrames(shown: [f, g], all: [f, g], photos: [photo('p', ref: 'f2'), photo('q')]);
      expect(shot.keys, ['f2']);
    });
    test('a spot with no frames counts as shot once there is a photo', () {
      expect(spotShot(shown: const [], shot: const {}, photos: [photo('p')]), isTrue);
      expect(spotShot(shown: const [], shot: const {}, photos: const []), isFalse);
      expect(spotShot(shown: [frame('f', path: 'a')], shot: const {}, photos: [photo('p')]), isFalse);
    });
  });

  test('the place page counts are plurals in every language', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.placeSpotCount(1), '1 spot');
    expect(en.placeSpotCount(3), '3 spots');
    expect(en.placeFrameCount(1), '1 frame');
    final zh = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
    expect(zh.placeSpotCount(3), '3 個機位');
    expect(zh.placeShotCount(2), '拍過 2');
    expect(zh.placeStartShooting(4), '開始拍 · 還有 4 張沒拍');
    expect(en.placeStartShooting(1), 'Start shooting · 1 not shot');
    expect(lookupAppLocalizations(const Locale('ja')).placeFrameCount(2), '比較画像 2 枚');
  });

  group('what to shoot next', () {
    // Two spots of 宇治橋: 三の間 to the west, 東詰 about 140 m east.
    final place = stop('p', '宇治橋', lat: 34.8920, lng: 135.8080);
    final west = [frame('w1', note: '三の間', lat: 34.8921, lng: 135.8075), frame('w2', note: '三の間', lat: 34.8921, lng: 135.8075)];
    final east = [frame('e1', note: '東詰', lat: 34.8918, lng: 135.8090)];
    PlaceContent content(List<Photo> photos) =>
        TripFrameIndex(own: [for (final f in [...west, ...east]) f.copyWith(stopId: const Value('p'))], library: const [], photos: photos)
            .place([place]);

    test('the queue is the frames not shot, nearest spot first, or in order without a position', () {
      final c = content([photo('x', ref: 'w1')]);
      expect(c.shotCount, 1);
      expect(c.unshotCount, 2);
      expect([for (final f in shootingQueue(c)) f.id], ['w2', 'e1']);
      expect([for (final f in shootingQueue(c, lat: 34.8918, lng: 135.8091)) f.id], ['e1', 'w2']);
    });

    test('nextToShoot names the spot and how far it is, and nothing once all is shot', () {
      final next = nextToShoot(content(const []), lat: 34.8918, lng: 135.8091);
      expect(next!.frame.id, 'e1');
      expect(next.spot.label, '東詰');
      expect(next.metres, lessThan(15));
      expect(nextToShoot(content(const []))!.spot.label, '三の間');
      expect(nextToShoot(content([photo('a', ref: 'w1'), photo('b', ref: 'w2'), photo('c', ref: 'e1')])), isNull);
    });

    test("the latest shot is the place's thumbnail", () {
      final c = content([photo('old', ref: 'w1', at: t0), photo('new', ref: 'e1', at: t0.add(const Duration(hours: 2)))]);
      expect(c.latestShot!.id, 'new');
      expect(c.firstFrame!.id, 'w1');
    });

    test('compassTo: which way a spot is', () {
      expect(compassTo(34.0, 135.0, 34.001, 135.0), Compass.n);
      expect(compassTo(34.0, 135.0, 34.001, 135.0012), Compass.ne);
      expect(compassTo(34.0, 135.0, 33.999, 135.0), Compass.s);
      expect(compassTo(34.0, 135.0, 34.0, 134.999), Compass.w);
    });
  });
}
