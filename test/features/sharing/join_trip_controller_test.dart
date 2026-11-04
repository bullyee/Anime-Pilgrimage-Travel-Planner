import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sharing/controllers/join_trip_controller.dart';
import 'package:trip_planner/features/sharing/models/trip_invite.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/services/group_sharing_service.dart';

import 'fake_sharing_firestore.dart';

/// Firestore's answer when the phone can't reach the server.
class _OfflineSharingService extends GroupSharingService {
  _OfflineSharingService(AppDatabase db)
      : super(firestore: FakeSharingFirestore(), db: db, currentUserId: 'user_bob');

  @override
  Future<TripInvite?> getInvitePreview(String tokenOrCode) async =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
}

void main() {
  late AppDatabase db;
  late FakeSharingFirestore fakeFirestore;
  late GroupSharingService sharingService;
  late JoinTripController controller;
  const currentUserId = 'user_bob';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeFirestore = FakeSharingFirestore();
    sharingService = GroupSharingService(
      firestore: fakeFirestore,
      db: db,
      currentUserId: currentUserId,
    );
    controller = JoinTripController(sharingService: sharingService);
  });

  tearDown(() async {
    await db.close();
  });

  group('JoinTripController', () {
    test('initial state has empty code and no invite preview', () {
      expect(controller.state.code, isEmpty);
      expect(controller.state.invite, isNull);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isJoining, isFalse);
      expect(controller.state.isJoined, isFalse);
      expect(controller.state.errorMessage, isNull);
    });

    test('updateCode sanitizes input to uppercase and auto-fetches 6-char code', () async {
      // Setup active invite in fake Firestore
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 7));
      const testCode = 'KYOTO1';
      const testToken = 'token_abc123';

      fakeFirestore.inviteCodes[testCode] = {
        'token': testToken,
        'createdAt': Timestamp.fromDate(now),
      };
      fakeFirestore.invites[testToken] = {
        'token': testToken,
        'shortCode': testCode,
        'tripId': 'trip_kyoto',
        'role': 'editor',
        'createdBy': 'user_alice',
        'inviterName': 'Alice',
        'tripTitle': 'Kyoto Pilgrimage',
        'stopCount': 5,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isRevoked': false,
        'emailAllowlist': <String>[],
      };

      // Type short code in lowercase with whitespace
      await controller.updateCode('  kyoto1  ');

      expect(controller.state.code, equals('KYOTO1'));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.invite, isNotNull);
      expect(controller.state.invite?.tripTitle, equals('Kyoto Pilgrimage'));
      expect(controller.state.invite?.role, equals(TripMemberRole.editor));
    });

    test('fetchPreview sets appropriate error message when code not found', () async {
      await controller.updateCode('NOSUCH');

      expect(controller.state.invite, isNull);
      expect(controller.state.errorMessage, contains('Invite not found'));
      expect(controller.state.problem, JoinTripProblem.notFound);
    });

    test('fetchPreview flags expired invite', () async {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 1));
      const testCode = 'OLD123';
      const testToken = 'token_old';

      fakeFirestore.inviteCodes[testCode] = {
        'token': testToken,
        'createdAt': Timestamp.fromDate(past),
      };
      fakeFirestore.invites[testToken] = {
        'token': testToken,
        'shortCode': testCode,
        'tripId': 'trip_old',
        'role': 'viewer',
        'createdBy': 'user_alice',
        'inviterName': 'Alice',
        'tripTitle': 'Old Trip',
        'stopCount': 2,
        'createdAt': Timestamp.fromDate(past.subtract(const Duration(days: 7))),
        'expiresAt': Timestamp.fromDate(past),
        'isRevoked': false,
        'emailAllowlist': <String>[],
      };

      await controller.updateCode('old123');

      expect(controller.state.invite, isNotNull);
      expect(controller.state.errorMessage, contains('expired'));
      expect(controller.state.problem, JoinTripProblem.expired);
    });

    test('fetchPreview flags revoked invite', () async {
      final now = DateTime.now();
      const testCode = 'REVOKE';
      const testToken = 'token_revoked';

      fakeFirestore.inviteCodes[testCode] = {
        'token': testToken,
        'createdAt': Timestamp.fromDate(now),
      };
      fakeFirestore.invites[testToken] = {
        'token': testToken,
        'shortCode': testCode,
        'tripId': 'trip_revoked',
        'role': 'viewer',
        'createdBy': 'user_alice',
        'inviterName': 'Alice',
        'tripTitle': 'Revoked Trip',
        'stopCount': 1,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'isRevoked': true,
        'emailAllowlist': <String>[],
      };

      await controller.updateCode('revoke');

      expect(controller.state.invite, isNotNull);
      expect(controller.state.errorMessage, contains('revoked'));
      expect(controller.state.problem, JoinTripProblem.stopped);
    });

    test('joinTrip successfully adds member to trip in Firestore and Drift', () async {
      final now = DateTime.now();
      const testCode = 'JOIN01';
      const testToken = 'token_join_01';

      fakeFirestore.inviteCodes[testCode] = {
        'token': testToken,
        'createdAt': Timestamp.fromDate(now),
      };
      fakeFirestore.invites[testToken] = {
        'token': testToken,
        'shortCode': testCode,
        'tripId': 'trip_joinable',
        'role': 'editor',
        'createdBy': 'user_alice',
        'inviterName': 'Alice',
        'tripTitle': 'Summer Comiket',
        'stopCount': 4,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'isRevoked': false,
        'emailAllowlist': <String>[],
      };

      await controller.updateCode('join01');
      expect(controller.state.invite, isNotNull);

      final member = await controller.joinTrip(displayName: 'Bob The Builder');

      expect(member, isNotNull);
      expect(member?.tripId, equals('trip_joinable'));
      expect(controller.state.isJoined, isTrue);
      expect(controller.state.joinedTripId, equals('trip_joinable'));
      expect(controller.state.errorMessage, isNull);

      // Verify member was saved in Firestore under tripsV2/trip_joinable/members/user_bob
      final savedMember = fakeFirestore.members['trip_joinable']?['user_bob'];
      expect(savedMember, isNotNull);
      expect(savedMember?['role'], equals('editor'));
      expect(savedMember?['displayName'], equals('Bob The Builder'));
    });

    test('reset clears all state', () async {
      await controller.updateCode('SOMECD');
      controller.reset();

      expect(controller.state.code, isEmpty);
      expect(controller.state.invite, isNull);
      expect(controller.state.isJoined, isFalse);
    });

    test('a lookup that cannot reach the server says the phone is offline', () async {
      final offline = JoinTripController(sharingService: _OfflineSharingService(db));

      await offline.updateCode('K7MQ2P');

      expect(offline.state.isLoading, isFalse);
      expect(offline.state.invite, isNull);
      expect(offline.state.problem, JoinTripProblem.offline);
      offline.dispose();
    });

    test('a new code clears the last problem', () async {
      await controller.updateCode('NOPE23');
      expect(controller.state.problem, JoinTripProblem.notFound);

      await controller.updateCode('NOPE2');

      expect(controller.state.problem, isNull);
    });
  });
}
