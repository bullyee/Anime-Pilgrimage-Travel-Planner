import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';

void main() {
  late AppDatabase db;
  late PlaceRepository placeRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PlaceRepository Integration Tests', () {
    test('upsertPlace inserts and retrieves place by placeKey', () async {
      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'anitabi:123',
          name: 'Toyosato Elementary School',
          lat: 35.2033,
          lng: 136.2333,
          description: const Value('K-On club room'),
          accessTips: const Value('Walk 10 min from Toyosato Station'),
          visibility: const Value('saved'),
        ),
      );

      final place = await placeRepo.getPlace('anitabi:123');
      expect(place, isNotNull);
      expect(place!.name, equals('Toyosato Elementary School'));
      expect(place.visibility, equals('saved'));
      expect(place.accessTips, equals('Walk 10 min from Toyosato Station'));
    });

    test('createTripOnlyPlace creates place with trip_only visibility', () async {
      final place = await placeRepo.createTripOnlyPlace(
        name: 'Custom Spot',
        lat: 35.0,
        lng: 135.0,
        accessTips: 'Under the bridge',
      );

      expect(place.visibility, equals('trip_only'));
      expect(place.name, equals('Custom Spot'));

      // Filter by saved should not return it
      final savedPlaces = await placeRepo.getPlaces(visibility: 'saved');
      expect(savedPlaces.any((p) => p.placeKey == place.placeKey), isFalse);

      // Promote to saved
      await placeRepo.setPlaceVisibility(place.placeKey, 'saved');
      final updated = await placeRepo.getPlace(place.placeKey);
      expect(updated!.visibility, equals('saved'));
    });

    test('getOrCreateLabel dedups anime by bangumiId and tags by name', () async {
      // 1. Anime dedup
      final a1 = await placeRepo.getOrCreateLabel(kind: 'anime', name: 'K-On!', bangumiId: '1424');
      final a2 = await placeRepo.getOrCreateLabel(kind: 'anime', name: 'K-On! Season 1', bangumiId: '1424');
      expect(a1.id, equals(a2.id));

      // 2. Tag dedup
      final t1 = await placeRepo.getOrCreateLabel(kind: 'tag', name: 'School');
      final t2 = await placeRepo.getOrCreateLabel(kind: 'tag', name: 'School');
      expect(t1.id, equals(t2.id));

      // 3. Different kinds do not collide
      final r1 = await placeRepo.getOrCreateLabel(kind: 'region', name: 'Kyoto');
      expect(r1.id, isNot(equals(t1.id)));
    });

    test('attachLabelToPlace and getPlacesByLabel joins correctly', () async {
      final animeLabel = await placeRepo.getOrCreateLabel(kind: 'anime', name: 'Hibike! Euphonium', bangumiId: '105151');
      final tagLabel = await placeRepo.getOrCreateLabel(kind: 'tag', name: 'Bench');

      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'anitabi:uji_bench',
          name: 'Kumiko Bench',
          lat: 34.89,
          lng: 135.81,
        ),
      );

      await placeRepo.attachLabelToPlace('anitabi:uji_bench', animeLabel.id);
      await placeRepo.attachLabelToPlace('anitabi:uji_bench', tagLabel.id);

      final animePlaces = await placeRepo.getPlacesByLabel(animeLabel.id);
      expect(animePlaces.length, equals(1));
      expect(animePlaces.first.name, equals('Kumiko Bench'));

      final labels = await placeRepo.getLabelsForPlace('anitabi:uji_bench');
      expect(labels.length, equals(2));
      expect(labels.map((l) => l.name), containsAll(['Hibike! Euphonium', 'Bench']));
    });
  });
}
