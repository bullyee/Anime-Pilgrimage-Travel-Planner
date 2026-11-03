import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/sync_engine_service_v2.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

import 'sync_engine_v2_test.dart' show FakeFirestoreSyncV2Service;

void main() {
  test('another account signing in on the same phone does not detach the first account\'s shared trip', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cloud = FakeFirestoreSyncV2Service();
    final earlier = DateTime(2026, 11, 1, 10);

    // Alice's own shared trip, synced, as it sits in the phone's database and in the cloud.
    await db.into(db.trips).insert(TripsCompanion.insert(
        id: 'uji',
        title: 'Uji',
        ownerId: 'user_alice',
        sharing: const Value('group'),
        updatedAt: Value(earlier),
        syncStatus: const Value(0)));
    cloud.trips['uji'] = {
      'id': 'uji',
      'title': 'Uji',
      'ownerId': 'user_alice',
      'sharing': 'group',
      'dayCount': 1,
      'members': ['user_alice', 'user_carol'],
      'updatedAt': earlier,
    };

    // Alice signs out and Bob signs in. Bob's trip query doesn't include Alice's trip.
    final bob = SyncEngineServiceV2(localDb: db, firestoreSync: cloud, currentUserId: 'user_bob');
    bob.startSync();
    cloud.emitUserTrips([]);
    await Future.delayed(const Duration(milliseconds: 200));
    bob.stopSync();
    var trip = await (db.select(db.trips)..where((t) => t.id.equals('uji'))).getSingle();

    expect(trip.sharing, equals('group'));
    expect(trip.ownerId, equals('user_alice'));

    // Alice signs back in. Her query returns her trip as the cloud has it.
    final alice = SyncEngineServiceV2(localDb: db, firestoreSync: cloud, currentUserId: 'user_alice');
    alice.startSync();
    cloud.emitUserTrips([Map.of(cloud.trips['uji']!)]);
    await Future.delayed(const Duration(milliseconds: 200));
    trip = await (db.select(db.trips)..where((t) => t.id.equals('uji'))).getSingle();

    expect(trip.sharing, equals('group'));
    expect(trip.ownerId, equals('user_alice'));

    // Alice renames her trip.
    await DriftTripRepository(db).updateTrip(
        const TripsCompanion(id: Value('uji'), title: Value('Uji, day 2'), updatedBy: Value('user_alice')));
    await Future.delayed(const Duration(milliseconds: 800));
    alice.stopSync();
    final remote = cloud.trips['uji']!;

    expect(trip.sharing, equals('group'));
    expect(remote['sharing'], equals('group'));
    expect(remote['ownerId'], equals('user_alice'));
  });
}
