import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sharing/models/trip_invite.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/services/group_sharing_service.dart';

import 'fake_sharing_firestore.dart';

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
    test('creates invite excluding deleted stops and resolves via token and short code preview', () async {
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
      // Tombstoned stop must not be counted in stopCount
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_deleted',
              tripId: 'trip_kyoto',
              placeKey: 'anitabi:2',
              name: 'Deleted Spot',
              lat: 35.0,
              lng: 135.0,
              addedBy: currentUserId,
              deletedAt: Value(DateTime.now()),
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

      // updateMemberRole rejects owner role
      expect(
        () => bobService.updateMemberRole('trip_test', currentUserId, TripMemberRole.owner),
        throwsArgumentError,
      );
    });

    test('unshareTrip resets sharing to private and cleans up non-owner member docs', () async {
      fakeFirestore.tripsV2['trip_unshare'] = {
        'id': 'trip_unshare',
        'ownerId': currentUserId,
        'sharing': 'group',
        'members': [currentUserId, 'user_bob', 'user_charlie'],
      };
      fakeFirestore.members['trip_unshare'] = {
        currentUserId: {'userId': currentUserId, 'role': 'owner'},
        'user_bob': {'userId': 'user_bob', 'role': 'editor'},
        'user_charlie': {'userId': 'user_charlie', 'role': 'viewer'},
      };
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_unshare',
              title: 'Unshare Test',
              ownerId: currentUserId,
              sharing: const Value('group'),
            ),
          );

      await sharingService.unshareTrip('trip_unshare');

      expect(fakeFirestore.tripsV2['trip_unshare']!['sharing'], 'private');
      expect(fakeFirestore.tripsV2['trip_unshare']!['members'], [currentUserId]);
      expect(fakeFirestore.members['trip_unshare']?.containsKey('user_bob'), isFalse);
      expect(fakeFirestore.members['trip_unshare']?.containsKey('user_charlie'), isFalse);
      expect(fakeFirestore.members['trip_unshare']?.containsKey(currentUserId), isTrue);

      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_unshare'))).getSingle();
      expect(localTrip.sharing, 'private');
    });

    test('revokes or expires invite prevents subsequent joins', () async {
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

      // Expired invite stored via toMap() (ISO string) is also rejected
      final expiredInvite = TripInvite(
        token: 'token_expired_iso',
        shortCode: 'EXPIRE',
        tripId: 'trip_test',
        role: TripMemberRole.viewer,
        createdBy: currentUserId,
        inviterName: 'Alice',
        tripTitle: 'Test Trip',
        stopCount: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        expiresAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      fakeFirestore.invites[expiredInvite.token] = expiredInvite.toMap();
      expect(
        () => charlieService.joinTripWithInvite(expiredInvite.token),
        throwsA(isA<Exception>()),
      );
    });

    test('leaveTrip rejects owner without transfer and converts non-owner local copy to private', () async {
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_leave_test',
              title: 'Shared Trip',
              ownerId: currentUserId,
              sharing: const Value('group'),
              syncStatus: const Value(0),
            ),
          );
      fakeFirestore.tripsV2['trip_leave_test'] = {
        'id': 'trip_leave_test',
        'ownerId': currentUserId,
        'members': [currentUserId, 'user_bob'],
      };
      fakeFirestore.members['trip_leave_test'] = {
        currentUserId: {'userId': currentUserId, 'role': 'owner'},
        'user_bob': {'userId': 'user_bob', 'role': 'editor'},
      };

      // Owner cannot leave without transferring ownership first
      expect(
        () => sharingService.leaveTrip('trip_leave_test'),
        throwsStateError,
      );

      // Non-owner (user_bob) leaves and keeps a private unsynced local copy
      final bobService = GroupSharingService(
        firestore: fakeFirestore,
        db: db,
        currentUserId: 'user_bob',
      );
      await bobService.leaveTrip('trip_leave_test');
      expect(fakeFirestore.members['trip_leave_test']?.containsKey('user_bob'), isFalse);

      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_leave_test'))).getSingle();
      expect(localTrip.sharing, equals('private'));
      expect(localTrip.ownerId, equals('user_bob'));
      expect(localTrip.syncStatus, equals(0));
    });
  });

  group('GroupSharingService - Guest Transition Claiming', () {
    test('claimGuestTrips reassigns orphan guest trips and child rows to signed in user', () async {
      // Create two trips in guest mode
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'guest_trip_1',
              title: 'Draft Pilgrimage 1',
              ownerId: 'guest_local_user',
            ),
          );
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'guest_stop_1',
              tripId: 'guest_trip_1',
              placeKey: 'anitabi:1',
              name: 'Spot 1',
              lat: 35.0,
              lng: 135.0,
              addedBy: 'guest_local_user',
              updatedBy: const Value('guest_local_user'),
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

      final stop1 = await (db.select(db.stops)..where((s) => s.id.equals('guest_stop_1'))).getSingle();
      expect(stop1.addedBy, 'user_alice');
      expect(stop1.updatedBy, 'user_alice');

      final trip2 = await (db.select(db.trips)..where((t) => t.id.equals('guest_trip_2'))).getSingle();
      expect(trip2.ownerId, 'user_alice');

      final other = await (db.select(db.trips)..where((t) => t.id.equals('other_trip'))).getSingle();
      expect(other.ownerId, 'user_david'); // Untouched
    });
  });
}
