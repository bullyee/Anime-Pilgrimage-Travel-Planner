import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/models/library_entry.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/services/anitabi_import.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AnitabiSpot Chinese Name and Multilingual Search', () {
    late AppDatabase db;
    late PlaceRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = DriftPlaceRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('AnitabiSpot.fromJson extracts chineseName from cn field', () {
      final raw = {
        'id': '101',
        'name': '宇治橋',
        'cn': '宇治桥',
        'geo': [34.8935, 135.8075],
        'image': '/images/uji.jpg',
        'ep': '1',
        's': 120,
        'mark': 'Bridge scene',
      };

      final spot = AnitabiSpot.fromJson(raw);
      expect(spot, isNotNull);
      expect(spot!.name, equals('宇治橋'));
      expect(spot.chineseName, equals('宇治桥'));
      expect(spot.hasLocation, isTrue);
    });

    test('importSpots persists chineseName to Places table and updates existing rows if missing', () async {
      final spot = AnitabiSpot(
        id: 'spot_1',
        name: '宇治橋',
        chineseName: '宇治桥',
        lat: 34.8935,
        lng: 135.8075,
      );

      final summary = await AnitabiImport.importSpots(
        places: repo,
        bangumiId: '115908',
        animeName: 'Sound! Euphonium',
        spots: [spot],
        download: (_) async => null,
      );

      expect(summary.added, equals(1));

      final place = await repo.getPlace('anitabi:spot_1');
      expect(place, isNotNull);
      expect(place!.name, equals('宇治橋'));
      expect(place.chineseName, equals('宇治桥'));

      // If an existing place had no chineseName, importing again populates it
      await (db.update(db.places)..where((t) => t.placeKey.equals('anitabi:spot_1')))
          .write(const PlacesCompanion(chineseName: Value(null)));

      final placeWithoutCn = await repo.getPlace('anitabi:spot_1');
      expect(placeWithoutCn!.chineseName, isNull);

      final summary2 = await AnitabiImport.importSpots(
        places: repo,
        bangumiId: '115908',
        animeName: 'Sound! Euphonium',
        spots: [spot],
        download: (_) async => null,
      );

      expect(summary2.alreadySaved, equals(1));
      final placeUpdated = await repo.getPlace('anitabi:spot_1');
      expect(placeUpdated!.chineseName, equals('宇治桥'));
    });

    test('filterLibrary matches by original name, simplified Chinese, and traditional Chinese', () {
      final place1 = Place(
        placeKey: 'p1',
        name: '宇治橋',
        chineseName: '宇治桥',
        lat: 34.8935,
        lng: 135.8075,
        visibility: 'saved',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final place2 = Place(
        placeKey: 'p2',
        name: '大吉山展望台',
        chineseName: '大吉山展望台',
        lat: 34.8900,
        lng: 135.8150,
        visibility: 'saved',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final entries = [
        LibraryEntry(place: place1, labels: const [], tripIds: const {}),
        LibraryEntry(place: place2, labels: const [], tripIds: const {}),
      ];

      // 1. Search with Traditional Chinese '宇治橋' matches p1
      final filterTc = const LibraryFilter(query: '宇治橋');
      final resultTc = filterLibrary(entries, filterTc, const []);
      expect(resultTc.map((e) => e.place.placeKey), contains('p1'));
      expect(resultTc.map((e) => e.place.placeKey), isNot(contains('p2')));

      // 2. Search with Simplified Chinese '宇治桥' matches p1 via chineseName
      final filterSc = const LibraryFilter(query: '宇治桥');
      final resultSc = filterLibrary(entries, filterSc, const []);
      expect(resultSc.map((e) => e.place.placeKey), contains('p1'));

      // 3. Search with Traditional Chinese for mountain '大吉山'
      final filterMtn = const LibraryFilter(query: '大吉山');
      final resultMtn = filterLibrary(entries, filterMtn, const []);
      expect(resultMtn.map((e) => e.place.placeKey), contains('p2'));
    });
  });
}
