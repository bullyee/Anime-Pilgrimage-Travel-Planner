import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/utils/fractional_index.dart';
import 'package:trip_planner/features/trip/models/trip_template.dart';
import 'package:trip_planner/features/trip/services/trip_template_service.dart';

// Lightweight Fake Firestore for testing templates & short code indexing
// ignore: subtype_of_sealed_class
class FakeTemplateFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> templates = {};
  final Map<String, Map<String, dynamic>> templateCodes = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _FakeCollectionReference(this, path);
  }

  @override
  WriteBatch batch() => _FakeWriteBatch(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  final FakeTemplateFirestore _db;
  final String _collectionPath;

  _FakeCollectionReference(this._db, this._collectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docId = path ?? 'auto_id';
    return _FakeDocumentReference(_db, '$_collectionPath/$docId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  final FakeTemplateFirestore _db;
  final String _fullPath;

  _FakeDocumentReference(this._db, this._fullPath);

  @override
  String get id => _fullPath.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    final parts = _fullPath.split('/');
    final col = parts[0];
    final docId = parts[1];

    Map<String, dynamic>? data;
    if (col == 'templates') {
      data = _db.templates[docId];
    } else if (col == 'template_codes') {
      data = _db.templateCodes[docId];
    }

    return _FakeDocumentSnapshot(docId, data, data != null);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final parts = _fullPath.split('/');
    final col = parts[0];
    final docId = parts[1];
    if (col == 'templates') {
      _db.templates[docId] = Map<String, dynamic>.from(data);
    } else if (col == 'template_codes') {
      _db.templateCodes[docId] = Map<String, dynamic>.from(data);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentSnapshot
    implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;
  final bool _exists;

  _FakeDocumentSnapshot(this._id, this._data, this._exists);

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWriteBatch implements WriteBatch {
  final FakeTemplateFirestore _db;
  final List<void Function()> _operations = [];

  _FakeWriteBatch(this._db);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _operations.add(() {
      final docRef = document as _FakeDocumentReference;
      final parts = docRef._fullPath.split('/');
      final col = parts[0];
      final docId = parts[1];
      if (col == 'templates') {
        _db.templates[docId] = Map<String, dynamic>.from(data as Map);
      } else if (col == 'template_codes') {
        _db.templateCodes[docId] = Map<String, dynamic>.from(data as Map);
      }
    });
  }

  @override
  Future<void> commit() async {
    for (final op in _operations) {
      op();
    }
    _operations.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late FakeTemplateFirestore fakeFirestore;
  late TripTemplateService templateService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeFirestore = FakeTemplateFirestore();
    templateService = TripTemplateService(
      db: db,
      firestore: fakeFirestore,
      currentUserId: 'alice_creator',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TripTemplate Model & Short Code', () {
    test('generateShortCode generates 6-character uppercase string with no confusing chars', () {
      final code = TripTemplateService.generateShortCode();
      expect(code.length, equals(6));
      expect(code, matches(RegExp(r'^[A-Z2-9]{6}$')));
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('1'), isFalse);
      expect(code.contains('I'), isFalse);
    });

    test('TripTemplate serialization preserves days, stops, labels, reference images, and schedule items', () {
      final now = DateTime(2026, 11, 5, 12, 0, 0);
      final template = TripTemplate(
        id: 'tpl_101',
        code: 'TEST99',
        title: 'Kyoto Sound! Euphonium Pilgrimage',
        description: 'Complete walking tour across Uji landmarks.',
        authorName: 'Kumiko Oumae',
        dayCount: 2,
        stopCount: 3,
        days: const [
          TemplateDay(dayNumber: 1, title: 'Day 1: Keihan Uji & Agata Shrine'),
          TemplateDay(dayNumber: 2, title: 'Day 2: Mount Daikokuten'),
        ],
        stops: const [
          TemplateStop(
            id: 'stop_t1',
            placeKey: 'anitabi:uji_shrine',
            name: 'Uji Shrine',
            lat: 34.8901,
            lng: 135.8123,
            description: 'Where Kumiko met Reina.',
            address: 'Uji, Kyoto',
            coverRemoteUrl: 'https://images.example.com/uji.jpg',
            labels: [TemplateLabel(name: 'Sound! Euphonium', kind: 'anime')],
            referenceImages: [
              TemplateReferenceImage(
                remoteUrl: 'https://images.example.com/ref1.jpg',
                episode: 'S1E8',
                timestampS: 745,
              ),
            ],
          ),
        ],
        scheduleItems: const [
          TemplateScheduleItem(
            dayNumber: 1,
            stopId: 'stop_t1',
            sortKey: 'a0',
            stayMinutes: 45,
            transitMinutes: 10,
            status: 'planned',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final map = template.toMap();
      expect(map['id'], equals('tpl_101'));
      expect(map['code'], equals('TEST99'));
      expect(map['title'], equals('Kyoto Sound! Euphonium Pilgrimage'));
      expect(map['authorName'], equals('Kumiko Oumae'));
      expect(map['dayCount'], equals(2));
      expect(map['stopCount'], equals(3));
      expect((map['days'] as List).length, equals(2));
      expect((map['stops'] as List).length, equals(1));
      expect((map['scheduleItems'] as List).length, equals(1));

      final reconstructed = TripTemplate.fromMap(map, 'tpl_101');
      expect(reconstructed.id, equals('tpl_101'));
      expect(reconstructed.code, equals('TEST99'));
      expect(reconstructed.title, equals(template.title));
      expect(reconstructed.authorName, equals('Kumiko Oumae'));
      expect(reconstructed.days.length, equals(2));
      expect(reconstructed.days.first.title, equals('Day 1: Keihan Uji & Agata Shrine'));
      expect(reconstructed.stops.length, equals(1));
      expect(reconstructed.stops.first.name, equals('Uji Shrine'));
      expect(reconstructed.stops.first.labels.first.name, equals('Sound! Euphonium'));
      expect(reconstructed.stops.first.referenceImages.first.episode, equals('S1E8'));
      expect(reconstructed.scheduleItems.first.stayMinutes, equals(45));
    });
  });

  group('TripTemplateService - Exporting, Publishing & Cloning', () {
    late String tripId;

    setUp(() async {
      tripId = 'src_trip_kyoto';
      final t0 = DateTime(2026, 11, 1, 10, 0);

      // Create a 2-day trip with 1 active day + 1 backup day (index >= dayCount)
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: tripId,
              title: 'Source Kyoto Trip',
              description: const Value('Original user itinerary with personal notes.'),
              ownerId: 'alice_creator',
              sharing: const Value('private'),
              startDate: const Value('2026-11-15'), // Private calendar date
              dayCount: const Value(1), // Only Day 1 is in active itinerary; Day 2 is backup
              createdAt: Value(t0),
              updatedAt: Value(t0),
              syncStatus: const Value(0),
            ),
          );

      // Day 1 (active)
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_src_1',
              tripId: tripId,
              sortKey: 'a0',
              title: const Value('Day 1: Uji River Tour'),
              pinnedDate: const Value('2026-11-15'), // Private pinned date
              updatedAt: Value(t0),
              syncStatus: const Value(0),
            ),
          );

      // Day 2 (backup day since index 1 >= dayCount 1)
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_src_2',
              tripId: tripId,
              sortKey: 'a1',
              title: const Value('Backup Rainy Day'),
              updatedAt: Value(t0),
              syncStatus: const Value(0),
            ),
          );

      // Place in library
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'anitabi:uji_river',
              name: 'Uji River Bench',
              lat: 34.891,
              lng: 135.811,
              description: const Value('Bench where Reina played trumpet.'),
            ),
          );

      // Stop attached to trip
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_src_1',
              tripId: tripId,
              placeKey: 'anitabi:uji_river',
              name: 'Uji River Bench',
              lat: 34.891,
              lng: 135.811,
              coverLocalPath: const Value('/data/local/cache/private_cover.jpg'), // Local file path
              coverRemoteUrl: const Value('https://cdn.example.com/river.jpg'),
              addedBy: 'alice_creator',
              createdAt: Value(t0),
              updatedAt: Value(t0),
              syncStatus: const Value(0),
            ),
          );

      // Stop label
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'lbl_1',
              name: 'Hibike!',
              kind: 'anime',
            ),
          );
      await db.into(db.stopLabels).insert(
            StopLabelsCompanion.insert(
              stopId: 'stop_src_1',
              labelId: 'lbl_1',
            ),
          );

      // Stop reference image
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'ref_1',
              stopId: const Value('stop_src_1'),
              localPath: const Value('/data/user/0/local_frame.jpg'), // Local file path
              remoteUrl: const Value('https://cdn.example.com/frame_ep8.jpg'),
              episode: const Value('Ep 8'),
              timestampS: const Value(920),
            ),
          );

      // Personal Photo (should be completely omitted from template)
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'photo_personal_1',
              placeKey: 'anitabi:uji_river',
              localPath: '/data/camera/my_selfie.jpg',
              tripId: Value(tripId),
            ),
          );

      // Active Schedule Item on Day 1
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'item_src_1',
              tripId: tripId,
              dayId: 'day_src_1',
              stopId: 'stop_src_1',
              sortKey: 'a0',
              stayMinutes: const Value(60),
              transitMinutes: const Value(10),
              status: const Value('planned'),
              syncStatus: const Value(0),
            ),
          );

      // Backup Schedule Item on Day 2 (should be omitted because day 2 is backup)
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'item_src_2',
              tripId: tripId,
              dayId: 'day_src_2',
              stopId: 'stop_src_1',
              sortKey: 'a0',
              stayMinutes: const Value(30),
              status: const Value('planned'),
              syncStatus: const Value(0),
            ),
          );
    });

    test('exportTripToTemplate sanitizes private calendar dates, backup days, and local paths', () async {
      final template = await templateService.exportTripToTemplate(
        tripId,
        authorName: 'Alice Explorer',
      );

      // 1. Title and description preserved
      expect(template.title, equals('Source Kyoto Trip'));
      expect(template.description, equals('Original user itinerary with personal notes.'));
      expect(template.authorName, equals('Alice Explorer'));

      // 2. Only active days (dayCount = 1) exported; backup Day 2 filtered out
      expect(template.dayCount, equals(1));
      expect(template.days.length, equals(1));
      expect(template.days.first.dayNumber, equals(1));
      expect(template.days.first.title, equals('Day 1: Uji River Tour'));

      // 3. Stops exported with labels and remote reference frames
      expect(template.stopCount, equals(1));
      expect(template.stops.length, equals(1));
      final stop = template.stops.first;
      expect(stop.name, equals('Uji River Bench'));
      expect(stop.coverRemoteUrl, equals('https://cdn.example.com/river.jpg'));
      expect(stop.labels.length, equals(1));
      expect(stop.labels.first.name, equals('Hibike!'));
      expect(stop.referenceImages.length, equals(1));
      expect(stop.referenceImages.first.remoteUrl, equals('https://cdn.example.com/frame_ep8.jpg'));
      expect(stop.referenceImages.first.episode, equals('Ep 8'));

      // 4. Schedule items on backup day omitted; only Day 1 schedule item kept
      expect(template.scheduleItems.length, equals(1));
      expect(template.scheduleItems.first.dayNumber, equals(1));
      expect(template.scheduleItems.first.stopId, equals(stop.id));
      expect(template.scheduleItems.first.stayMinutes, equals(60));
    });

    test('publishTemplate writes template snapshot and index short code to Firestore', () async {
      final template = await templateService.exportTripToTemplate(tripId);
      final published = await templateService.publishTemplate(template);

      expect(published.code.length, equals(6));
      expect(fakeFirestore.templates.containsKey(published.id), isTrue);
      expect(fakeFirestore.templateCodes.containsKey(published.code), isTrue);

      final codeDoc = fakeFirestore.templateCodes[published.code]!;
      expect(codeDoc['templateId'], equals(published.id));
      expect(codeDoc['code'], equals(published.code));

      // Resolve back via short code lookup
      final fetched = await templateService.getTemplateByCode(published.code);
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(published.id));
      expect(fetched.title, equals('Source Kyoto Trip'));
    });

    test('cloneTemplateToTrip creates independent private trip with fresh UUIDs and preserved structure', () async {
      final now = DateTime(2026, 11, 5);
      final template = TripTemplate(
        id: 'tpl_clone_src',
        code: 'CLONE1',
        title: 'Akihabara Steins;Gate Tour',
        description: 'Iconic anime locations in Tokyo.',
        authorName: 'Rintaro Okabe',
        dayCount: 2,
        stopCount: 1,
        days: const [
          TemplateDay(dayNumber: 1, title: 'Day 1: Electronic City'),
          TemplateDay(dayNumber: 2, title: 'Day 2: Shrine & River'),
        ],
        stops: const [
          TemplateStop(
            id: 'src_stop_1',
            placeKey: 'anitabi:mandarake',
            name: 'Mandarake Complex',
            lat: 35.7001,
            lng: 139.7712,
            address: 'Sotokanda 3-11-12',
            coverRemoteUrl: 'https://images.example.com/mandarake.jpg',
            labels: [TemplateLabel(name: 'Shopping', kind: 'tag')],
            referenceImages: [
              TemplateReferenceImage(
                remoteUrl: 'https://images.example.com/frame1.jpg',
                episode: 'Ep 3',
              ),
            ],
          ),
        ],
        scheduleItems: const [
          TemplateScheduleItem(
            dayNumber: 1,
            stopId: 'src_stop_1',
            sortKey: 'a0',
            stayMinutes: 90,
            transitMinutes: 15,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      // Clone as Bob with new title and custom start date
      final clonedTrip = await templateService.cloneTemplateToTrip(
        template,
        ownerId: 'bob_user',
        newTitle: 'My Tokyo Holiday',
        startDate: '2027-05-01',
      );

      // 1. Check Cloned Trip
      expect(clonedTrip.id, isNot(equals('tpl_clone_src')));
      expect(clonedTrip.title, equals('My Tokyo Holiday'));
      expect(clonedTrip.description, equals('Iconic anime locations in Tokyo.'));
      expect(clonedTrip.ownerId, equals('bob_user'));
      expect(clonedTrip.sharing, equals('private')); // Must be private local trip
      expect(clonedTrip.startDate, equals('2027-05-01'));
      expect(clonedTrip.dayCount, equals(2));
      expect(clonedTrip.syncStatus, equals(1)); // Dirty for sync

      // 2. Check Cloned Trip Days
      final days = await (db.select(db.tripDays)
            ..where((d) => d.tripId.equals(clonedTrip.id))
            ..orderBy([(d) => OrderingTerm(expression: d.sortKey)]))
          .get();
      expect(days.length, equals(2));
      expect(days[0].title, equals('Day 1: Electronic City'));
      expect(days[1].title, equals('Day 2: Shrine & River'));
      expect(days[0].pinnedDate, isNull); // Pinned date stripped
      expect(days[0].sortKey.compareTo(days[1].sortKey), lessThan(0));

      // 3. Check Cloned Stops
      final stops = await (db.select(db.stops)
            ..where((s) => s.tripId.equals(clonedTrip.id)))
          .get();
      expect(stops.length, equals(1));
      final clonedStop = stops.first;
      expect(clonedStop.id, isNot(equals('src_stop_1'))); // Fresh UUID
      expect(clonedStop.name, equals('Mandarake Complex'));
      expect(clonedStop.addedBy, equals('bob_user'));
      expect(clonedStop.coverRemoteUrl, equals('https://images.example.com/mandarake.jpg'));

      // Check Fallback Place in Places table (for library integration)
      final place = await (db.select(db.places)
            ..where((p) => p.placeKey.equals('anitabi:mandarake')))
          .getSingleOrNull();
      expect(place, isNotNull);
      expect(place!.visibility, equals('trip_only'));

      // Check Stop Labels
      final stopLabels = await (db.select(db.stopLabels)
            ..where((sl) => sl.stopId.equals(clonedStop.id)))
          .get();
      expect(stopLabels.length, equals(1));

      // Check Reference Images
      final refImages = await (db.select(db.newReferenceImages)
            ..where((r) => r.stopId.equals(clonedStop.id)))
          .get();
      expect(refImages.length, equals(1));
      expect(refImages.first.remoteUrl, equals('https://images.example.com/frame1.jpg'));
      expect(refImages.first.episode, equals('Ep 3'));

      // 4. Check Cloned Schedule Items
      final items = await (db.select(db.scheduleItems)
            ..where((si) => si.tripId.equals(clonedTrip.id)))
          .get();
      expect(items.length, equals(1));
      final clonedItem = items.first;
      expect(clonedItem.dayId, equals(days[0].id)); // Correctly linked to cloned Day 1
      expect(clonedItem.stopId, equals(clonedStop.id)); // Correctly linked to cloned Stop
      expect(clonedItem.stayMinutes, equals(90));
      expect(clonedItem.transitMinutes, equals(15));
    });

    test('cloneTemplateToTrip succeeds seamlessly for guest users without account', () async {
      final now = DateTime.now();
      final template = TripTemplate(
        id: 'tpl_guest_src',
        code: 'GUEST1',
        title: 'Quick 1-Day Tour',
        dayCount: 1,
        stopCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final cloned = await templateService.cloneTemplateToTrip(
        template,
        ownerId: 'guest_random_device_id',
      );

      expect(cloned.ownerId, equals('guest_random_device_id'));
      expect(cloned.sharing, equals('private'));
      expect(cloned.title, equals('Quick 1-Day Tour'));
    });
  });
}
