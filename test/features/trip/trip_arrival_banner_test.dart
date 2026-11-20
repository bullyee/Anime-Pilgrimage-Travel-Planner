import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/sync/providers/frame_transfer_providers.dart';
import 'package:trip_planner/features/sync/providers/trip_arrival_providers.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_queue.dart';
import 'package:trip_planner/features/trip/widgets/trip_arrival_banner.dart';

class _IdleQueue extends FrameTransferQueue {
  @override
  FrameTransferState build() => const FrameTransferState();
}

void main() {
  late AppDatabase db;
  late Trip trip;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          title: 'Kansai',
          ownerId: 'bob',
          sharing: const Value('group'),
          updatedAt: Value(DateTime.now()),
        ));
    trip = await db.select(db.trips).getSingle();
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {required bool arriving, required int driveFrames}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        frameTransferQueueProvider.overrideWith(_IdleQueue.new),
        tripArrivingProvider('t1').overrideWith((ref) => Stream.value(arriving)),
        pendingDriveFrameDownloadCountProvider('t1').overrideWith((ref) => Stream.value(driveFrames)),
      ],
      child: MaterialApp(home: Scaffold(body: TripArrivalBanner(trip: trip))),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets("while the trip is coming down, it says so and offers nothing else", (tester) async {
    await pump(tester, arriving: true, driveFrames: 3);

    expect(find.text("Getting this trip's days and stops…"), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('frames on Google Drive that are not here yet are offered, until put off', (tester) async {
    await pump(tester, arriving: false, driveFrames: 3);

    expect(find.text("3 frames shared on Google Drive aren't on this phone yet. Download them?"), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('with everything here, it shows nothing', (tester) async {
    await pump(tester, arriving: false, driveFrames: 0);

    expect(find.text('Download'), findsNothing);
    expect(find.textContaining('Getting'), findsNothing);
  });
}
