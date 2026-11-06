import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/services/anitabi_import.dart';

AnitabiSpot _spot(String id, String name, {String? image}) => AnitabiSpot(
      id: id, name: name, lat: 34.8935, lng: 135.8075, episode: '1', seconds: 192,
      imageUrl: image, origin: '©Kyoto Animation', originUrl: 'https://example.org/frame',
    );

void main() {
  late AppDatabase db;
  late PlaceRepository places;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    places = DriftPlaceRepository(db);
  });
  tearDown(() => db.close());

  final spots = [_spot('1', '宇治橋', image: 'https://image.anitabi.cn/1.jpg')];

  test('a second import while the first is still downloading does not fetch or store the frame twice', () async {
    final gate = Completer<void>();
    final downloads = <String>[];
    Future<String?> slow(String url) async {
      downloads.add(url);
      await gate.future;
      return '/frames/${downloads.length}.jpg';
    }
    final first = await AnitabiImport.importSpots(
        places: places, bangumiId: '115908', animeName: 'Eupho', spots: spots, download: slow);
    final second = await AnitabiImport.importSpots(
        places: places, bangumiId: '115908', animeName: 'Eupho', spots: spots, download: slow);
    gate.complete();
    await Future.wait([first.frames, second.frames]);
    expect(downloads.length, 1);
    expect((await places.getReferenceImagesForPlace('anitabi:1')).length, 1);
  });

  test('a frame the user deleted is not downloaded again by a later import', () async {
    final first = await AnitabiImport.importSpots(
        places: places, bangumiId: '115908', animeName: 'Eupho', spots: spots,
        download: (url) async => '/frames/1.jpg');
    await first.frames;
    final frame = (await places.getReferenceImagesForPlace('anitabi:1')).single;
    await places.deleteReferenceImage(frame.id);
    final downloads = <String>[];
    final again = await AnitabiImport.importSpots(
        places: places, bangumiId: '115908', animeName: 'Eupho', spots: spots,
        download: (url) async { downloads.add(url); return '/frames/again.jpg'; });
    await again.frames;
    expect(downloads, isEmpty);
  });
}
