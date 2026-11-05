import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trip/providers/trip_providers.dart';
import '../models/trip_invite.dart';
import '../models/trip_member.dart';
import '../services/group_sharing_service.dart';

part 'group_sharing_providers.g.dart';

@Riverpod(keepAlive: true)
GroupSharingService groupSharingService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);

  return GroupSharingService(
    firestore: FirebaseFirestore.instance,
    db: db,
    currentUserId: userId,
  );
}

/// Watch members list of a shared trip.
@riverpod
Stream<List<TripMember>> tripMembers(Ref ref, String tripId) {
  final sharingService = ref.watch(groupSharingServiceProvider);
  return sharingService.watchTripMembers(tripId);
}

/// The id [currentUserIdProvider] gives when nobody is signed in.
const guestUserId = 'guest_local_user';

/// Watch the invites the current user made for a trip that can still be used.
final tripInvitesProvider = StreamProvider.autoDispose.family<List<TripInvite>, String>((ref, tripId) {
  return ref.watch(groupSharingServiceProvider).watchTripInvites(tripId);
});

/// The name and photo that the signed-in user's invites and member record
/// show the others.
typedef SharingProfile = ({String? name, String? avatarUrl});

final sharingProfileProvider = Provider<SharingProfile>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  return (name: user?.displayName, avatarUrl: user?.photoURL);
});

/// What the current user can do in a trip, or null when it's not theirs to
/// share (or isn't loaded yet). A private trip is its owner's alone, and one
/// made while signed out becomes the signed-in user's when they share it.
final myTripRoleProvider = Provider.autoDispose.family<TripMemberRole?, String>((ref, tripId) {
  final me = ref.watch(currentUserIdProvider);
  final trip = ref.watch(tripDetailProvider(tripId)).valueOrNull;
  if (trip == null || trip.deletedAt != null) return null;
  if (trip.sharing != 'group') {
    return trip.ownerId == me || trip.ownerId == guestUserId ? TripMemberRole.owner : null;
  }
  final members = ref.watch(tripMembersProvider(tripId)).valueOrNull;
  final mine = members?.where((m) => m.userId == me).firstOrNull;
  return mine?.role ?? (trip.ownerId == me ? TripMemberRole.owner : null);
});

/// Whether the current user may change the trip's shared parts: its plan,
/// stops, trip notes and facts. Only a viewer may not. The rules refuse a
/// viewer's writes, so an edit would stay on their phone and never sync;
/// the screens hide the ways to make one instead. Their own note, visits and
/// photos are theirs, so those stay editable.
final canEditTripProvider = Provider.autoDispose.family<bool, String>((ref, tripId) {
  return ref.watch(myTripRoleProvider(tripId)) != TripMemberRole.viewer;
});
