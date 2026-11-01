import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/trip_member.dart';
import '../services/group_sharing_service.dart';

part 'group_sharing_providers.g.dart';

@Riverpod(keepAlive: true)
GroupSharingService groupSharingService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.user?.uid ?? 'guest_local_user';

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

