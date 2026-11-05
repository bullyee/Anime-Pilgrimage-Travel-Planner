import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/personal_backup_service.dart';

// Lightweight Fake Firestore for testing users/{userId} personal backup paths
// ignore: subtype_of_sealed_class
class FakePersonalFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> docs = {};

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
  final FakePersonalFirestore _db;
  final String _collectionPath;

  _FakeCollectionReference(this._db, this._collectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docId = path ?? 'auto_id';
    return _FakeDocumentReference(_db, '$_collectionPath/$docId');
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final prefix = '$_collectionPath/';
    final matchingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final entry in _db.docs.entries) {
      if (entry.key.startsWith(prefix)) {
        final subPath = entry.key.substring(prefix.length);
        if (!subPath.contains('/')) {
          matchingDocs.add(_FakeQueryDocumentSnapshot(
            _FakeDocumentReference(_db, entry.key),
            subPath,
            entry.value,
          ));
        }
      }
    }

    return _FakeQuerySnapshot(matchingDocs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  _FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQueryDocumentSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final DocumentReference<Map<String, dynamic>> _ref;
  final String _id;
  final Map<String, dynamic> _data;

  _FakeQueryDocumentSnapshot(this._ref, this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  DocumentReference<Map<String, dynamic>> get reference => _ref;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  final FakePersonalFirestore _db;
  final String _fullPath;

  _FakeDocumentReference(this._db, this._fullPath);

  @override
  String get id => _fullPath.split('/').last;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(_db, '$_fullPath/$collectionPath');
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    final data = _db.docs[_fullPath];
    return _FakeDocumentSnapshot(id, data, data != null);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _db.docs[_fullPath] = Map<String, dynamic>.from(data);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(
      {bool includeMetadataChanges = false,
      ListenSource source = ListenSource.defaultSource}) {
    final data = _db.docs[_fullPath];
    return Stream.value(_FakeDocumentSnapshot(id, data, data != null));
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
  final FakePersonalFirestore _db;
  final List<void Function()> _operations = [];

  _FakeWriteBatch(this._db);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _operations.add(() {
      final docRef = document as _FakeDocumentReference;
      _db.docs[docRef._fullPath] = Map<String, dynamic>.from(data as Map);
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
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FakePersonalFirestore fakeFirestore;
  late PersonalBackupService backupService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeFirestore = FakePersonalFirestore();
    backupService = PersonalBackupService(
      db: db,
      firestore: fakeFirestore,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('PersonalBackupService Validation', () {
    test('backup and restore throw ArgumentError on guest or empty userId', () async {
      expect(
        () => backupService.backupPersonalLibrary(userId: 'guest'),
        throwsArgumentError,
      );
      expect(
        () => backupService.backupPersonalLibrary(userId: ''),
        throwsArgumentError,
      );
      expect(
        () => backupService.restorePersonalLibrary(userId: 'guest'),
        throwsArgumentError,
      );
    });
  });

  group('PersonalBackupService Backup & Multi-Account Isolation', () {
    test('backs up personal library while ignoring trip_only places and isolates accounts', () async {
      final now = DateTime.now();

      // 1. Insert saved place (should be backed up)
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'anitabi:akiba_station',
              name: 'Akihabara Station',
              lat: 35.6983,
              lng: 139.7731,
              description: const Value('Main electric town exit'),
              coverLocalPath: const Value('/local/path/station.jpg'),
              coverRemoteUrl: const Value('https://images.example.com/station.jpg'),
              privateNote: const Value('Best entrance is the Electric Town Gate'),
              visibility: const Value('saved'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 2. Insert transient trip_only spot (should NOT be in personal library backup)
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'custom:transient_spot',
              name: 'Temporary Lunch Stop',
              lat: 35.6990,
              lng: 139.7740,
              visibility: const Value('trip_only'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 3. Insert Labels & PlaceLabels
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'lbl_steins_gate',
              name: 'Steins;Gate',
              kind: 'anime',
              createdAt: Value(now),
            ),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(
              placeKey: 'anitabi:akiba_station',
              labelId: 'lbl_steins_gate',
            ),
          );

      // 4. Insert Visits
      await db.into(db.placeVisits).insert(
            PlaceVisitsCompanion.insert(
              id: 'visit_1',
              placeKey: 'anitabi:akiba_station',
              date: '2026-11-01',
              createdAt: Value(now),
            ),
          );

      // 5. Insert Photos
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'photo_1',
              placeKey: 'anitabi:akiba_station',
              localPath: '/data/user/0/photos/p1.jpg',
              remoteUrl: const Value('https://images.example.com/p1.jpg'),
              createdAt: Value(now),
            ),
          );

      // 6. Insert Reference Frame
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'ref_1',
              placeKey: const Value('anitabi:akiba_station'),
              remoteUrl: const Value('https://images.example.com/ref1.jpg'),
              episode: const Value('Ep 1'),
              createdAt: Value(now),
            ),
          );

      // Execute backup for Alice
      final summary = await backupService.backupPersonalLibrary(userId: 'alice_uid');

      // Verify counts: transient spot excluded, placesCount = 1
      expect(summary.placesCount, equals(1));
      expect(summary.labelsCount, equals(1));
      expect(summary.visitsCount, equals(1));
      expect(summary.photosCount, equals(1));
      expect(summary.refImagesCount, equals(1));

      // Check Firestore paths
      expect(fakeFirestore.docs.containsKey('users/alice_uid/places/anitabi:akiba_station'), isTrue);
      expect(fakeFirestore.docs.containsKey('users/alice_uid/places/custom:transient_spot'), isFalse);
      expect(fakeFirestore.docs.containsKey('users/alice_uid/labels/lbl_steins_gate'), isTrue);
      expect(fakeFirestore.docs.containsKey('users/alice_uid/meta/backup'), isTrue);

      // Multi-account isolation: Bob has zero documents under users/bob_uid/
      final bobsPlaces = fakeFirestore.docs.keys.where((k) => k.startsWith('users/bob_uid/'));
      expect(bobsPlaces, isEmpty);
    });
  });

  group('PersonalBackupService Restoration & Conflict Protection', () {
    test('restores personal library on fresh device preserving relational foreign keys', () async {
      final now = DateTime.now();

      // Seed cloud backup data for Alice
      fakeFirestore.docs['users/alice_uid/places/anitabi:kanda_shrine'] = {
        'placeKey': 'anitabi:kanda_shrine',
        'name': 'Kanda Myojin Shrine',
        'lat': 35.7020,
        'lng': 139.7679,
        'description': 'Love Live & Steins;Gate pilgrimage site',
        'coverRemoteUrl': 'https://images.example.com/kanda.jpg',
        'visibility': 'saved',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      fakeFirestore.docs['users/alice_uid/labels/lbl_lovelive'] = {
        'id': 'lbl_lovelive',
        'kind': 'anime',
        'name': 'Love Live!',
        'createdAt': Timestamp.fromDate(now),
      };

      fakeFirestore.docs['users/alice_uid/place_labels/anitabi:kanda_shrine___lbl_lovelive'] = {
        'placeKey': 'anitabi:kanda_shrine',
        'labelId': 'lbl_lovelive',
      };

      fakeFirestore.docs['users/alice_uid/visits/visit_kanda'] = {
        'id': 'visit_kanda',
        'placeKey': 'anitabi:kanda_shrine',
        'date': '2026-11-03',
        'createdAt': Timestamp.fromDate(now),
      };

      fakeFirestore.docs['users/alice_uid/photos/photo_kanda'] = {
        'id': 'photo_kanda',
        'placeKey': 'anitabi:kanda_shrine',
        'kind': 'original',
        'remoteUrl': 'https://images.example.com/kanda_photo.jpg',
        'createdAt': Timestamp.fromDate(now),
      };

      // Fresh DB instance (empty)
      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      final freshService = PersonalBackupService(db: freshDb, firestore: fakeFirestore);

      final restoreResult = await freshService.restorePersonalLibrary(userId: 'alice_uid');

      expect(restoreResult.restoredPlaces, equals(1));
      expect(restoreResult.restoredLabels, equals(1));
      expect(restoreResult.restoredVisits, equals(1));
      expect(restoreResult.restoredPhotos, equals(1));

      // Verify SQLite state
      final place = await (freshDb.select(freshDb.places)..where((p) => p.placeKey.equals('anitabi:kanda_shrine'))).getSingleOrNull();
      expect(place, isNotNull);
      expect(place!.name, equals('Kanda Myojin Shrine'));

      final label = await (freshDb.select(freshDb.labels)..where((l) => l.id.equals('lbl_lovelive'))).getSingleOrNull();
      expect(label, isNotNull);
      expect(label!.name, equals('Love Live!'));

      final placeLabel = await freshDb.select(freshDb.placeLabels).get();
      expect(placeLabel.length, equals(1));
      expect(placeLabel.first.placeKey, equals('anitabi:kanda_shrine'));
      expect(placeLabel.first.labelId, equals('lbl_lovelive'));

      final visit = await (freshDb.select(freshDb.placeVisits)..where((v) => v.id.equals('visit_kanda'))).getSingleOrNull();
      expect(visit, isNotNull);
      expect(visit!.date, equals('2026-11-03'));

      await freshDb.close();
    });

    test('preserves local newer edits and local cover file paths during restore', () async {
      final oldTime = DateTime(2026, 11, 1);
      final newTime = DateTime(2026, 11, 5);

      // Cloud backup has older update
      fakeFirestore.docs['users/alice_uid/places/place_conflict'] = {
        'placeKey': 'place_conflict',
        'name': 'Old Cloud Name',
        'lat': 35.0,
        'lng': 139.0,
        'coverRemoteUrl': 'https://example.com/cloud.jpg',
        'visibility': 'saved',
        'updatedAt': Timestamp.fromDate(oldTime),
      };

      // Local database has newer edits and a local file path
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'place_conflict',
              name: 'Newer Local Name',
              lat: 35.1,
              lng: 139.1,
              coverLocalPath: const Value('/device/storage/cover.jpg'),
              coverRemoteUrl: const Value('https://example.com/cloud.jpg'),
              visibility: const Value('saved'),
              updatedAt: Value(newTime),
            ),
          );

      // Restore
      await backupService.restorePersonalLibrary(userId: 'alice_uid');

      // Local newer place is preserved (not overwritten by old cloud data)
      final place = await (db.select(db.places)..where((p) => p.placeKey.equals('place_conflict'))).getSingle();
      expect(place.name, equals('Newer Local Name'));
      expect(place.lat, equals(35.1));
      expect(place.coverLocalPath, equals('/device/storage/cover.jpg')); // Local path not wiped!
    });
  });

  group('PersonalBackupService Watch Metadata', () {
    test('watchBackupMetadata streams latest backup timestamp and entity counts', () async {
      final now = DateTime.now();
      final summary = BackupSummary(
        lastBackupAt: now,
        placesCount: 5,
        visitsCount: 3,
        labelsCount: 2,
        photosCount: 10,
        refImagesCount: 4,
      );

      fakeFirestore.docs['users/alice_uid/meta/backup'] = summary.toMap();

      final streamResult = await backupService.watchBackupMetadata('alice_uid').first;
      expect(streamResult, isNotNull);
      expect(streamResult!.placesCount, equals(5));
      expect(streamResult.photosCount, equals(10));
    });
  });
}
