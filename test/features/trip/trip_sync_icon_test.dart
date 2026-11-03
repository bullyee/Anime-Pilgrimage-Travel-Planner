import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/providers/sync_v2_providers.dart';
import 'package:trip_planner/features/sync/services/sync_engine_service_v2.dart';
import 'package:trip_planner/features/trip/models/trip_summary.dart';
import 'package:trip_planner/features/trip/widgets/trip_card.dart';
import 'package:trip_planner/features/trip/widgets/trip_sync_icon.dart';

import '../sync/sync_engine_v2_test.dart' show FakeFirestoreSyncV2Service;

Trip _trip(String id, {required String sharing}) => Trip(
      id: id,
      title: 'Uji',
      ownerId: 'u1',
      sharing: sharing,
      dayCount: 1,
      createdAt: DateTime(2027, 1, 1),
      updatedAt: DateTime(2027, 1, 1),
      syncStatus: 0,
    );

void main() {
  test('the status starts with where the trip stands, so a push that failed before anyone listened still shows',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cloud = FakeFirestoreSyncV2Service()
      ..onBeforeCommit = () async => throw Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.');
    await db.into(db.trips).insert(TripsCompanion.insert(
        id: 'uji', title: 'Uji', ownerId: 'u1', sharing: const Value('group'), syncStatus: const Value(1)));

    final engine = SyncEngineServiceV2(localDb: db, firestoreSync: cloud, currentUserId: 'u1');
    addTearDown(engine.stopSync);
    engine.startSync();
    for (var i = 0; i < 100 && engine.getTripSyncStatus('uji') != TripSyncStatus.error; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    expect(engine.getTripSyncStatus('uji'), TripSyncStatus.error);

    // A card built now: the engine reports nothing new, as the trip stays refused.
    final container = ProviderContainer(overrides: [syncEngineServiceV2Provider.overrideWithValue(engine)]);
    addTearDown(container.dispose);
    container.listen(tripSyncStatusProvider('uji'), (_, _) {});
    final status = await container.read(tripSyncStatusProvider('uji').future).timeout(const Duration(seconds: 1));
    expect(status, TripSyncStatus.error);
  });

  group('the sync icon', () {
    late StreamController<TripSyncStatus> statuses;

    setUp(() => statuses = StreamController<TripSyncStatus>.broadcast());
    tearDown(() => statuses.close());

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [tripSyncStatusProvider('uji').overrideWith((ref) => statuses.stream)],
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      ));
    }

    // A status passes through two streams before the icon rebuilds, which
    // takes more than one frame.
    Future<void> report(WidgetTester tester, TripSyncStatus status) async {
      statuses.add(status);
      await tester.pumpAndSettle();
    }

    testWidgets('shows nothing while the trip is in sync', (tester) async {
      await pump(tester, const TripSyncIcon(tripId: 'uji'));
      await report(tester, TripSyncStatus.synced);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('a push shows as not synced only once it outlasts the grace period', (tester) async {
      await pump(tester, const TripSyncIcon(tripId: 'uji'));
      await report(tester, TripSyncStatus.pending);
      expect(find.byType(Icon), findsNothing);

      await tester.pump(syncPendingGrace);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Not synced yet'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

      await report(tester, TripSyncStatus.synced);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('a quick sync never shows', (tester) async {
      await pump(tester, const TripSyncIcon(tripId: 'uji'));
      await report(tester, TripSyncStatus.pending);
      await tester.pump(const Duration(seconds: 1));
      await report(tester, TripSyncStatus.synced);
      await tester.pump(syncPendingGrace * 2);
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('offline and refused pushes show at once', (tester) async {
      await pump(tester, const TripSyncIcon(tripId: 'uji'));
      await report(tester, TripSyncStatus.offline);
      expect(find.byTooltip("Offline. Changes sync once you're back online"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      await report(tester, TripSyncStatus.error);
      expect(find.byTooltip("Couldn't sync this trip. Your changes are kept on this phone"), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.sync_problem));
      expect(icon.color, Theme.of(tester.element(find.byType(Scaffold))).colorScheme.error);
    });

    testWidgets('a shared trip card shows it by the title; a private one has none', (tester) async {
      Widget card(Trip trip) => TripCard(
            summary: TripSummary.from(trip: trip, days: const [], stopCount: 0, now: DateTime(2027, 1, 1)),
            onTap: () {},
          );

      await pump(tester, card(_trip('uji', sharing: 'group')));
      await report(tester, TripSyncStatus.offline);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      await pump(tester, card(_trip('uji', sharing: 'private')));
      await report(tester, TripSyncStatus.offline);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.byType(TripSyncIcon), findsNothing);
    });
  });
}
