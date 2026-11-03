import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
