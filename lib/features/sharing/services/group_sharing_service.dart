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
    final trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    final stopCount = await (_db.select(_db.stops)..where((s) => s.tripId.equals(tripId))).get();

    final token = const Uuid().v4();
    final shortCode = generateShortCode();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 7));

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
      stopCount: stopCount.length,
      createdAt: now,
      expiresAt: expiresAt,
      isRevoked: false,
      emailAllowlist: emailAllowlist ?? const [],
    );

    // Save invite doc
    await _firestore.collection('invites').doc(token).set({
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

    // Save short code index
    await _firestore.collection('invite_codes').doc(shortCode).set({
      'token': token,
      'createdAt': Timestamp.fromDate(now),
    });

    return invite;
  }

  /// Resolve token or short code to an invite preview.
  Future<TripInvite?> getInvitePreview(String tokenOrCode) async {
    String token = tokenOrCode.trim();

    // If it's a 6-character short code, resolve it
    if (token.length == 6 && !token.contains('-')) {
      final codeDoc = await _firestore.collection('invite_codes').doc(token.toUpperCase()).get();
      if (!codeDoc.exists) return null;
      token = codeDoc.data()?['token'] as String? ?? token;
    }

    final inviteDoc = await _firestore.collection('invites').doc(token).get();
    if (!inviteDoc.exists) return null;

    final data = inviteDoc.data()!;
    return TripInvite(
      token: data['token'] as String? ?? token,
      shortCode: data['shortCode'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      role: TripMemberRole.fromString(data['role'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      inviterName: data['inviterName'] as String? ?? '',
      inviterAvatarUrl: data['inviterAvatarUrl'] as String?,
      tripTitle: data['tripTitle'] as String? ?? '',
      tripDates: data['tripDates'] as String?,
      stopCount: (data['stopCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: (data['expiresAt'] is Timestamp)
          ? (data['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 7)),
      isRevoked: data['isRevoked'] as bool? ?? false,
      emailAllowlist: List<String>.from(data['emailAllowlist'] as List? ?? []),
    );
  }

  /// Join a trip via invite token or short code.
  Future<TripMember> joinTripWithInvite(
    String tokenOrCode, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final invite = await getInvitePreview(tokenOrCode);
    if (invite == null || !invite.isValid) {
      throw Exception('Invite is invalid, revoked, or has expired.');
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

    // Write member doc to tripsV2/{tripId}/members/{currentUserId}
    await _firestore
        .collection('tripsV2')
        .doc(invite.tripId)
        .collection('members')
        .doc(currentUserId)
        .set({
      'userId': member.userId,
      'tripId': member.tripId,
      'role': member.role.toRoleString(),
      'displayName': member.displayName,
      'avatarUrl': member.avatarUrl,
      'joinedAt': Timestamp.fromDate(now),
      'inviteToken': invite.token,
    });

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
              return TripMember(
                userId: data['userId'] as String? ?? doc.id,
                tripId: tripId,
                role: TripMemberRole.fromString(data['role'] as String?),
                displayName: data['displayName'] as String? ?? 'Collaborator',
                avatarUrl: data['avatarUrl'] as String?,
                joinedAt: (data['joinedAt'] is Timestamp)
                    ? (data['joinedAt'] as Timestamp).toDate()
                    : DateTime.now(),
              );
            }).toList());
  }

  /// Update a member's role (Owner only).
  Future<void> updateMemberRole(
    String tripId,
    String memberUserId,
    TripMemberRole newRole,
  ) async {
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
    await _firestore
        .collection('tripsV2')
        .doc(tripId)
        .collection('members')
        .doc(memberUserId)
        .delete();
  }

  /// Leave a trip (Self-removal for non-owners).
  Future<void> leaveTrip(String tripId) async {
    await _firestore
        .collection('tripsV2')
        .doc(tripId)
        .collection('members')
        .doc(currentUserId)
        .delete();
  }

  /// Transfer trip ownership to another member.
  Future<void> transferOwnership(String tripId, String newOwnerId) async {
    final batch = _firestore.batch();

    // 1. Update trip doc ownerId
    final tripRef = _firestore.collection('tripsV2').doc(tripId);
    batch.update(tripRef, {'ownerId': newOwnerId});

    // 2. Update new owner's member doc to 'owner'
    final newOwnerRef = tripRef.collection('members').doc(newOwnerId);
    batch.update(newOwnerRef, {'role': 'owner'});

    // 3. Demote current owner's member doc to 'editor'
    final currentOwnerRef = tripRef.collection('members').doc(currentUserId);
    batch.update(currentOwnerRef, {'role': 'editor'});

    await batch.commit();

    // Update local database trip owner if local trip exists
    await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(ownerId: Value(newOwnerId)),
    );
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

    await _db.transaction(() async {
      await (_db.update(_db.trips)
            ..where((t) => t.ownerId.equals('guest_local_user')))
          .write(
        TripsCompanion(
          ownerId: Value(signedInUserId),
          updatedAt: Value(DateTime.now()),
          updatedBy: Value(signedInUserId),
        ),
      );
    });

    return guestTrips.length;
  }
}

