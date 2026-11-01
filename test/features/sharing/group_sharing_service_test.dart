import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sharing/models/trip_invite.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/services/group_sharing_service.dart';

// Fake Firestore for GroupSharingService unit testing
class FakeSharingFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> invites = {};
  final Map<String, Map<String, dynamic>> inviteCodes = {};
  final Map<String, Map<String, Map<String, dynamic>>> members = {};
  final Map<String, Map<String, dynamic>> tripsV2 = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(this, collectionPath);
  }

  @override
  WriteBatch batch() => _FakeSharingWriteBatch(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionReference implements CollectionReference<Map<String, dynamic>> {
  final FakeSharingFirestore _db;
  final String _path;

  _FakeCollectionReference(this._db, this._path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final fullPath = path != null ? '$_path/$path' : '$_path/auto_id';
    return _FakeDocumentReference(_db, fullPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  final FakeSharingFirestore _db;
  final String _fullPath;

  _FakeDocumentReference(this._db, this._fullPath);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(_db, '$_fullPath/$collectionPath');
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final parts = _fullPath.split('/');
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites') _db.invites[docId] = Map.from(data);
      if (col == 'invite_codes') _db.inviteCodes[docId] = Map.from(data);
      if (col == 'tripsV2') _db.tripsV2[docId] = Map.from(data);
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      _db.members.putIfAbsent(tripId, () => {})[memberId] = Map.from(data);
    }
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final parts = _fullPath.split('/');
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites' && _db.invites.containsKey(docId)) {
        data.forEach((k, v) => _db.invites[docId]![k.toString()] = v);
      }
      if (col == 'tripsV2' && _db.tripsV2.containsKey(docId)) {
        data.forEach((k, v) => _db.tripsV2[docId]![k.toString()] = v);
      }
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      if (_db.members[tripId]?.containsKey(memberId) == true) {
        data.forEach((k, v) => _db.members[tripId]![memberId]![k.toString()] = v);
      }
    }
  }

  @override
  Future<void> delete() async {
    final parts = _fullPath.split('/');
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites') _db.invites.remove(docId);
      if (col == 'invite_codes') _db.inviteCodes.remove(docId);
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      _db.members[tripId]?.remove(memberId);
    }
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final parts = _fullPath.split('/');
    Map<String, dynamic>? data;
    bool exists = false;
    if (parts.length == 2) {
      final col = parts[0];
      final docId = parts[1];
      if (col == 'invites') {
        data = _db.invites[docId];
        exists = data != null;
      } else if (col == 'invite_codes') {
        data = _db.inviteCodes[docId];
        exists = data != null;
      } else if (col == 'tripsV2') {
        data = _db.tripsV2[docId];
        exists = data != null;
      }
    } else if (parts.length == 4) {
      final tripId = parts[1];
      final memberId = parts[3];
      data = _db.members[tripId]?[memberId];
      exists = data != null;
    }
    return _FakeDocumentSnapshot(data, exists);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final bool _exists;

  _FakeDocumentSnapshot(this._data, this._exists);

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSharingWriteBatch implements WriteBatch {
  final FakeSharingFirestore _db;
  final List<void Function()> _ops = [];

  _FakeSharingWriteBatch(this._db);

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    _ops.add(() => document.update(data));
  }

  @override
  Future<void> commit() async {
    for (final op in _ops) {
      op();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late FakeSharingFirestore fakeFirestore;
  late GroupSharingService sharingService;
  const currentUserId = 'user_alice';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeFirestore = FakeSharingFirestore();
    sharingService = GroupSharingService(
      firestore: fakeFirestore,
      db: db,
      currentUserId: currentUserId,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('GroupSharingService - Models & Helpers', () {
    test('generateShortCode generates valid 6-char alphanumeric code', () {
      final code1 = GroupSharingService.generateShortCode();
      final code2 = GroupSharingService.generateShortCode();

      expect(code1.length, 6);
      expect(code2.length, 6);
      expect(code1, isNot(code2));
      expect(RegExp(r'^[A-Z2-9]{6}$').hasMatch(code1), isTrue);
    });

    test('TripMemberRole string conversion and parsing', () {
      expect(TripMemberRole.fromString('owner'), TripMemberRole.owner);
      expect(TripMemberRole.fromString('editor'), TripMemberRole.editor);
      expect(TripMemberRole.fromString('viewer'), TripMemberRole.viewer);
      expect(TripMemberRole.fromString('unknown'), TripMemberRole.viewer);

      expect(TripMemberRole.owner.toRoleString(), 'owner');
      expect(TripMemberRole.editor.toRoleString(), 'editor');
      expect(TripMemberRole.viewer.toRoleString(), 'viewer');
    });

    test('TripInvite validity checks', () {
      final validInvite = TripInvite(
        token: 'token_1',
        shortCode: 'CODE12',
        tripId: 'trip_1',
        role: TripMemberRole.editor,
        createdBy: 'user_1',
        inviterName: 'Alice',
        tripTitle: 'Trip',
        stopCount: 5,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      expect(validInvite.isValid, isTrue);
      expect(validInvite.isExpired, isFalse);

      final revokedInvite = TripInvite(
        token: 'token_2',
        shortCode: 'CODE34',
        tripId: 'trip_1',
        role: TripMemberRole.editor,
        createdBy: 'user_1',
        inviterName: 'Alice',
        tripTitle: 'Trip',
        stopCount: 5,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        isRevoked: true,
      );
      expect(revokedInvite.isValid, isFalse);

      final expiredInvite = TripInvite(
        token: 'token_3',
        shortCode: 'CODE56',
        tripId: 'trip_1',
        role: TripMemberRole.editor,
        createdBy: 'user_1',
        inviterName: 'Alice',
        tripTitle: 'Trip',
        stopCount: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredInvite.isValid, isFalse);
      expect(expiredInvite.isExpired, isTrue);
    });
  });

  group('GroupSharingService - Invites & Members', () {
    test('creates invite and resolves via token and short code preview', () async {
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_kyoto',
              title: 'Kyoto Trip',
              ownerId: currentUserId,
              sharing: const Value('group'),
              startDate: const Value('2026-11-20'),
            ),
          );

      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_1',
              tripId: 'trip_kyoto',
              placeKey: 'anitabi:1',
              name: 'Fushimi Inari',
              lat: 34.967,
              lng: 135.772,
              addedBy: currentUserId,
            ),
          );

      final invite = await sharingService.createInvite(
        tripId: 'trip_kyoto',
        role: TripMemberRole.editor,
        inviterName: 'Alice',
      );

      expect(invite.tripId, 'trip_kyoto');
      expect(invite.role, TripMemberRole.editor);
      expect(invite.stopCount, 1);
      expect(invite.shortCode.length, 6);

      // Verify FakeFirestore stored the invite and code
      expect(fakeFirestore.invites.containsKey(invite.token), isTrue);
      expect(fakeFirestore.inviteCodes.containsKey(invite.shortCode), isTrue);

      // Resolve preview by token
      final previewByToken = await sharingService.getInvitePreview(invite.token);
      expect(previewByToken, isNotNull);
      expect(previewByToken!.tripTitle, 'Kyoto Trip');

      // Resolve preview by shortCode
      final previewByCode = await sharingService.getInvitePreview(invite.shortCode);
      expect(previewByCode, isNotNull);
      expect(previewByCode!.token, invite.token);
    });

    test('joins trip via valid invite and updates member roles / ownership', () async {
      final invite = TripInvite(
        token: 'invite_bob_token',
        shortCode: 'BOB123',
        tripId: 'trip_test',
        role: TripMemberRole.editor,
        createdBy: currentUserId,
        inviterName: 'Alice',
        tripTitle: 'Test Trip',
        stopCount: 2,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      fakeFirestore.invites[invite.token] = invite.toMap();

      // Bob joins
      final bobService = GroupSharingService(
        firestore: fakeFirestore,
        db: db,
        currentUserId: 'user_bob',
      );

      final member = await bobService.joinTripWithInvite(
        invite.token,
        displayName: 'Bob',
      );

      expect(member.userId, 'user_bob');
      expect(member.role, TripMemberRole.editor);
      expect(fakeFirestore.members['trip_test']?['user_bob'], isNotNull);

      // Alice updates Bob's role to viewer
      await sharingService.updateMemberRole('trip_test', 'user_bob', TripMemberRole.viewer);
      expect(fakeFirestore.members['trip_test']!['user_bob']!['role'], 'viewer');

      // Transfer ownership to Bob
      fakeFirestore.tripsV2['trip_test'] = {'ownerId': currentUserId};
      fakeFirestore.members.putIfAbsent('trip_test', () => {})[currentUserId] = {
        'userId': currentUserId,
        'role': 'owner',
        'displayName': 'Alice',
      };
      await sharingService.transferOwnership('trip_test', 'user_bob');
      expect(fakeFirestore.tripsV2['trip_test']!['ownerId'], 'user_bob');
      expect(fakeFirestore.members['trip_test']!['user_bob']!['role'], 'owner');
      expect(fakeFirestore.members['trip_test']![currentUserId]!['role'], 'editor');

      // Bob removes Alice
      await bobService.removeMember('trip_test', currentUserId);
      expect(fakeFirestore.members['trip_test']?.containsKey(currentUserId), isFalse);
    });

    test('revokes invite prevents subsequent joins', () async {
      final invite = TripInvite(
        token: 'token_to_revoke',
        shortCode: 'REVOKE',
        tripId: 'trip_test',
        role: TripMemberRole.editor,
        createdBy: currentUserId,
        inviterName: 'Alice',
        tripTitle: 'Test Trip',
        stopCount: 1,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      fakeFirestore.invites[invite.token] = invite.toMap();

      await sharingService.revokeInvite(invite.token);
      expect(fakeFirestore.invites[invite.token]!['isRevoked'], isTrue);

      final charlieService = GroupSharingService(
        firestore: fakeFirestore,
        db: db,
        currentUserId: 'user_charlie',
      );

      expect(
        () => charlieService.joinTripWithInvite(invite.token),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('GroupSharingService - Guest Transition Claiming', () {
    test('claimGuestTrips reassigns orphan guest trips to signed in user', () async {
      // Create two trips in guest mode
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'guest_trip_1',
              title: 'Draft Pilgrimage 1',
              ownerId: 'guest_local_user',
            ),
          );

      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'guest_trip_2',
              title: 'Draft Pilgrimage 2',
              ownerId: 'guest_local_user',
            ),
          );

      // Create a trip already owned by another user
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'other_trip',
              title: 'Other Trip',
              ownerId: 'user_david',
            ),
          );

      final claimedCount = await sharingService.claimGuestTrips('user_alice');
      expect(claimedCount, 2);

      final trip1 = await (db.select(db.trips)..where((t) => t.id.equals('guest_trip_1'))).getSingle();
      expect(trip1.ownerId, 'user_alice');
      expect(trip1.updatedBy, 'user_alice');

      final trip2 = await (db.select(db.trips)..where((t) => t.id.equals('guest_trip_2'))).getSingle();
      expect(trip2.ownerId, 'user_alice');

      final other = await (db.select(db.trips)..where((t) => t.id.equals('other_trip'))).getSingle();
      expect(other.ownerId, 'user_david'); // Untouched
    });
  });
}
