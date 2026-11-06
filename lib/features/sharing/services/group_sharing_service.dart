import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/trip_invite.dart';
import '../models/trip_member.dart';

class GroupSharingService {
  final FirebaseFirestore _firestore;
  final AppDatabase _db;
  final String currentUserId;

  GroupSharingService({
    required FirebaseFirestore firestore,
    required AppDatabase db,
    required this.currentUserId,
  })  : _firestore = firestore,
        _db = db;

  /// Generate a random 6-character uppercase alphanumeric short code.
  static String generateShortCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid easily confused chars 0/O, 1/I
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Create a new share invite for a trip.
  Future<TripInvite> createInvite({
    required String tripId,
    required TripMemberRole role,
    String? inviterName,
    String? inviterAvatarUrl,
    List<String>? emailAllowlist,
  }) async {
    if (role == TripMemberRole.owner) {
      throw ArgumentError('Cannot create an invite with the owner role.');
    }

    // Whole milliseconds, as the local database keeps them: the cloud trip gets
    // the same updatedAt as the local one, so the sync engine's later push of
    // it isn't older than the cloud's and refused.
    final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);
    var trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();

    // Read the server's copy first. Offline, this fails at once, before the
    // trip is marked shared, where the batches below would wait for a
    // connection instead.
    final tripRef = _firestore.collection('tripsV2').doc(tripId);
    final tripSnap = await tripRef.get(const GetOptions(source: Source.server));

    // Ensure the cloud trip document and owner member record exist before creating the invite
    // so Firestore security rules (`isTripEditorOrOwner(tripId)`) authorize invite creation.
    // This comes before the trip is marked shared here: the Members tab starts listening to the
    // members as soon as it is, the rules refuse that listen until the cloud trip exists, and a
    // refused listen doesn't retry, so the tab would show the error until the app restarts.
    final promoting = trip != null && trip.sharing != 'group';
    if (trip != null && trip.ownerId == currentUserId) {
      final initBatch = _firestore.batch();
      if (!tripSnap.exists) {
        initBatch.set(tripRef, {
          'id': trip.id,
          'title': trip.title,
          'description': trip.description,
          'ownerId': trip.ownerId,
          'sharing': 'group',
          'startDate': trip.startDate,
          'dayCount': trip.dayCount,
          'members': [currentUserId],
          'createdAt': Timestamp.fromDate(trip.createdAt),
          'updatedAt': Timestamp.fromDate(promoting ? now : trip.updatedAt),
          'updatedBy': promoting ? currentUserId : (trip.updatedBy ?? currentUserId),
          'deletedAt': null,
        });
      }
      // Always write/merge the owner member doc so watchTripMembers and ownership transfers find it
      initBatch.set(
        tripRef.collection('members').doc(currentUserId),
        {
          'tripId': trip.id,
          'userId': currentUserId,
          'role': 'owner',
          'displayName': inviterName ?? 'Owner',
          'avatarUrl': inviterAvatarUrl,
          'joinedAt': Timestamp.fromDate(trip.createdAt),
        },
        SetOptions(merge: true),
      );
      await initBatch.commit();
    }

    // If the trip is still private locally, promote it to 'group' and mark its rows dirty
    if (promoting) {
      await _db.transaction(() async {
        await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
          TripsCompanion(
            sharing: const Value('group'),
            syncStatus: const Value(1),
            updatedAt: Value(now),
            updatedBy: Value(currentUserId),
          ),
        );
        await (_db.update(_db.tripDays)..where((d) => d.tripId.equals(tripId)))
            .write(const TripDaysCompanion(syncStatus: Value(1)));
        await (_db.update(_db.stops)..where((s) => s.tripId.equals(tripId)))
            .write(const StopsCompanion(syncStatus: Value(1)));
        await (_db.update(_db.scheduleItems)..where((i) => i.tripId.equals(tripId)))
            .write(const ScheduleItemsCompanion(syncStatus: Value(1)));
      });
      trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    }

    final activeStops = await (_db.select(_db.stops)
          ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull()))
        .get();

    final token = const Uuid().v4();
    final shortCode = generateShortCode();
    // The rules allow at most 7 days from the server's clock, so a phone
    // whose clock runs a little fast would be refused at exactly 7 days.
    final expiresAt = now.add(const Duration(days: 7)).subtract(const Duration(minutes: 5));
    final normalizedEmailAllowlist = emailAllowlist?.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList() ?? const [];

    final invite = TripInvite(
      token: token,
      shortCode: shortCode,
      tripId: tripId,
      role: role,
      createdBy: currentUserId,
      inviterName: inviterName ?? 'Collaborator',
      inviterAvatarUrl: inviterAvatarUrl,
      tripTitle: trip?.title ?? 'Trip Itinerary',
      tripDates: trip?.startDate,
      stopCount: activeStops.length,
      createdAt: now,
      expiresAt: expiresAt,
      isRevoked: false,
      emailAllowlist: normalizedEmailAllowlist,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('invites').doc(token), {
      'token': invite.token,
      'shortCode': invite.shortCode,
      'tripId': invite.tripId,
      'role': invite.role.toRoleString(),
      'createdBy': invite.createdBy,
      'inviterName': invite.inviterName,
      'inviterAvatarUrl': invite.inviterAvatarUrl,
      'tripTitle': invite.tripTitle,
      'tripDates': invite.tripDates,
      'stopCount': invite.stopCount,
      'createdAt': Timestamp.fromDate(invite.createdAt),
      'expiresAt': Timestamp.fromDate(invite.expiresAt),
      'isRevoked': invite.isRevoked,
      'emailAllowlist': invite.emailAllowlist,
    });

    batch.set(_firestore.collection('invite_codes').doc(shortCode), {
      'token': token,
      'tripId': tripId,
      'createdBy': currentUserId,
      'createdAt': Timestamp.fromDate(now),
    });

    await batch.commit();

    return invite;
  }

  /// Resolve token or short code to an invite preview.
  Future<TripInvite?> getInvitePreview(String tokenOrCode) async {
    String token = tokenOrCode.trim();
    // From the server, never the cache: a stopped invite mustn't look valid,
    // and offline the lookup fails at once.
    const fromServer = GetOptions(source: Source.server);

    // If it's a 6-character short code, resolve it
    if (token.length == 6 && !token.contains('-')) {
      final codeDoc = await _firestore.collection('invite_codes').doc(token.toUpperCase()).get(fromServer);
      if (!codeDoc.exists) return null;
      token = codeDoc.data()?['token'] as String? ?? token;
    }

    final inviteDoc = await _firestore.collection('invites').doc(token).get(fromServer);
    if (!inviteDoc.exists) return null;

    final data = inviteDoc.data()!;
    return TripInvite.fromMap({
      ...data,
      'token': data['token'] as String? ?? token,
    });
  }

  /// Join a trip via invite token or short code.
  Future<TripMember> joinTripWithInvite(
    String tokenOrCode, {
    String? displayName,
    String? avatarUrl,
    String? userEmail,
  }) async {
    final invite = await getInvitePreview(tokenOrCode);
    if (invite == null || !invite.isValid) {
      throw Exception('Invite is invalid, revoked, or has expired.');
    }

    if (invite.emailAllowlist.isNotEmpty) {
      final normalizedEmail = userEmail?.trim().toLowerCase();
      final allowed = invite.emailAllowlist.map((e) => e.trim().toLowerCase()).toSet();
      if (normalizedEmail == null || !allowed.contains(normalizedEmail)) {
        throw Exception('Your email is not on the invite allowlist.');
      }
    }

    final now = DateTime.now();
    final member = TripMember(
      userId: currentUserId,
      tripId: invite.tripId,
      role: invite.role,
      displayName: displayName ?? 'Collaborator',
      avatarUrl: avatarUrl,
      joinedAt: now,
    );

    final tripRef = _firestore.collection('tripsV2').doc(invite.tripId);
    final memberRef = tripRef.collection('members').doc(currentUserId);

    final batch = _firestore.batch();
    batch.set(memberRef, {
      'userId': member.userId,
      'tripId': member.tripId,
      'role': member.role.toRoleString(),
      'displayName': member.displayName,
      'avatarUrl': member.avatarUrl,
      'joinedAt': Timestamp.fromDate(now),
      'inviteToken': invite.token,
    });

    // Also add currentUserId to tripsV2/{tripId}.members so watchUserTrips queries match
    batch.update(tripRef, {
      'members': FieldValue.arrayUnion([currentUserId]),
    });

    await batch.commit();

    return member;
  }

  /// Stream of members in a trip.
  Stream<List<TripMember>> watchTripMembers(String tripId) {
    return _firestore
        .collection('tripsV2')
        .doc(tripId)
        .collection('members')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return TripMember.fromMap({
                ...data,
                'userId': data['userId'] as String? ?? doc.id,
                'tripId': data['tripId'] as String? ?? tripId,
                'displayName': data['displayName'] as String? ?? 'Collaborator',
              });
            }).toList());
  }

  /// Update a member's role (Owner only).
  Future<void> updateMemberRole(
    String tripId,
    String memberUserId,
    TripMemberRole newRole,
  ) async {
    if (newRole == TripMemberRole.owner) {
      throw ArgumentError('Cannot set role to owner via updateMemberRole. Use transferOwnership instead.');
    }
    await _firestore
        .collection('tripsV2')
        .doc(tripId)
        .collection('members')
        .doc(memberUserId)
        .update({
      'role': newRole.toRoleString(),
    });
  }

  /// Kick a member from the trip (Owner only).
  Future<void> removeMember(String tripId, String memberUserId) async {
    final tripRef = _firestore.collection('tripsV2').doc(tripId);
    final memberRef = tripRef.collection('members').doc(memberUserId);
    final tripSnap = await tripRef.get();

    final batch = _firestore.batch();
    batch.delete(memberRef);
    if (tripSnap.exists) {
      batch.update(tripRef, {
        'members': FieldValue.arrayRemove([memberUserId]),
      });
    }
    await batch.commit();
  }

  /// Leave a trip (Self-removal for non-owners; preserves a private local copy).
  Future<void> leaveTrip(String tripId) async {
    final tripRef = _firestore.collection('tripsV2').doc(tripId);
    final memberRef = tripRef.collection('members').doc(currentUserId);

    final tripSnap = await tripRef.get();
    final memberSnap = await memberRef.get();
    final localTrip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();

    final isOwner = (tripSnap.exists && tripSnap.data()?['ownerId'] == currentUserId) ||
        (memberSnap.exists && memberSnap.data()?['role'] == 'owner') ||
        (localTrip != null && localTrip.ownerId == currentUserId && localTrip.sharing == 'group');
    if (isOwner) {
      throw StateError('Owner cannot leave the trip without transferring ownership first.');
    }

    final batch = _firestore.batch();
    batch.delete(memberRef);
    if (tripSnap.exists) {
      batch.update(tripRef, {
        'members': FieldValue.arrayRemove([currentUserId]),
      });
    }
    await batch.commit();

    // Per `docs/trip-sharing.md`: leaving a trip keeps a private, unsynced local copy
    if (localTrip != null) {
      await _db.transaction(() async {
        await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
          TripsCompanion(
            ownerId: Value(currentUserId),
            sharing: const Value('private'),
            syncStatus: const Value(0),
          ),
        );
        await (_db.update(_db.tripDays)..where((d) => d.tripId.equals(tripId)))
            .write(const TripDaysCompanion(syncStatus: Value(0)));
        await (_db.update(_db.stops)..where((s) => s.tripId.equals(tripId)))
            .write(const StopsCompanion(syncStatus: Value(0)));
        await (_db.update(_db.scheduleItems)..where((i) => i.tripId.equals(tripId)))
            .write(const ScheduleItemsCompanion(syncStatus: Value(0)));
      });
    }
  }

  /// Stop sharing a trip (Owner only). Converts the trip back to private.
  Future<void> unshareTrip(String tripId) async {
    final now = DateTime.now();
    final tripRef = _firestore.collection('tripsV2').doc(tripId);
    final tripSnap = await tripRef.get();
    if (tripSnap.exists) {
      final batch = _firestore.batch();
      batch.update(tripRef, {
        'sharing': 'private',
        'members': [currentUserId],
        'updatedAt': Timestamp.fromDate(now),
        'updatedBy': currentUserId,
      });

      // Also clean up non-owner member docs in members/ subcollection
      final membersSnap = await tripRef.collection('members').get();
      for (final doc in membersSnap.docs) {
        if (doc.id != currentUserId) {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
    }

    await _db.transaction(() async {
      await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          sharing: const Value('private'),
          updatedAt: Value(now),
          updatedBy: Value(currentUserId),
          syncStatus: const Value(0),
        ),
      );
      await (_db.update(_db.tripDays)..where((d) => d.tripId.equals(tripId)))
          .write(const TripDaysCompanion(syncStatus: Value(0)));
      await (_db.update(_db.stops)..where((s) => s.tripId.equals(tripId)))
          .write(const StopsCompanion(syncStatus: Value(0)));
      await (_db.update(_db.scheduleItems)..where((i) => i.tripId.equals(tripId)))
          .write(const ScheduleItemsCompanion(syncStatus: Value(0)));
    });
  }

  /// Transfer trip ownership to another member.
  Future<void> transferOwnership(String tripId, String newOwnerId) async {
    if (newOwnerId.trim().isEmpty || newOwnerId == currentUserId) {
      throw ArgumentError('newOwnerId must be a different member.');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();

    // 1. Update trip doc ownerId and bump updatedAt so LWW propagates to collaborators
    final tripRef = _firestore.collection('tripsV2').doc(tripId);
    batch.update(tripRef, {
      'ownerId': newOwnerId,
      'updatedAt': Timestamp.fromDate(now),
      'updatedBy': currentUserId,
    });

    // 2. Update new owner's member doc to 'owner' (merge so it creates if missing)
    final newOwnerRef = tripRef.collection('members').doc(newOwnerId);
    batch.set(newOwnerRef, {
      'tripId': tripId,
      'userId': newOwnerId,
      'role': 'owner',
    }, SetOptions(merge: true));

    // 3. Demote current owner's member doc to 'editor' (merge so it creates if missing)
    final currentOwnerRef = tripRef.collection('members').doc(currentUserId);
    batch.set(currentOwnerRef, {
      'tripId': tripId,
      'userId': currentUserId,
      'role': 'editor',
    }, SetOptions(merge: true));

    await batch.commit();

    // Update local database trip owner if local trip exists
    await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(
        ownerId: Value(newOwnerId),
        updatedAt: Value(now),
        updatedBy: Value(currentUserId),
      ),
    );
  }

  /// Stream of the invites this user made for a trip that can still be used,
  /// newest first. The rules only let people list their own invites.
  Stream<List<TripInvite>> watchTripInvites(String tripId) {
    return _firestore
        .collection('invites')
        .where('tripId', isEqualTo: tripId)
        .where('createdBy', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripInvite.fromMap({
                  ...doc.data(),
                  'token': doc.data()['token'] as String? ?? doc.id,
                }))
            .where((invite) => invite.isValid)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Revoke an invite so it can no longer be used.
  Future<void> revokeInvite(String token) async {
    await _firestore.collection('invites').doc(token).update({
      'isRevoked': true,
    });
  }

  /// Claim local guest trips when transitioning from guest mode to signed in.
  Future<int> claimGuestTrips(String signedInUserId) async {
    final guestTrips = await (_db.select(_db.trips)
          ..where((t) => t.ownerId.equals('guest_local_user')))
        .get();

    if (guestTrips.isEmpty) return 0;

    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.trips)
            ..where((t) => t.ownerId.equals('guest_local_user')))
          .write(
        TripsCompanion(
          ownerId: Value(signedInUserId),
          updatedAt: Value(now),
          updatedBy: Value(signedInUserId),
        ),
      );
      await (_db.update(_db.tripDays)
            ..where((d) => d.updatedBy.equals('guest_local_user')))
          .write(TripDaysCompanion(updatedBy: Value(signedInUserId)));
      await (_db.update(_db.stops)
            ..where((s) => s.addedBy.equals('guest_local_user')))
          .write(StopsCompanion(addedBy: Value(signedInUserId)));
      await (_db.update(_db.stops)
            ..where((s) => s.updatedBy.equals('guest_local_user')))
          .write(StopsCompanion(updatedBy: Value(signedInUserId)));
      await (_db.update(_db.scheduleItems)
            ..where((i) => i.updatedBy.equals('guest_local_user')))
          .write(ScheduleItemsCompanion(updatedBy: Value(signedInUserId)));
    });

    return guestTrips.length;
  }
}
