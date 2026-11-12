import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/sync/providers/frame_transfer_providers.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_queue.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';
import 'package:trip_planner/features/sync/services/transfer_foreground_service.dart';
import 'package:trip_planner/features/sync/widgets/frame_transfer_widgets.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';
import 'package:trip_planner/shared/theme/app_theme.dart';

import '../sync/fake_transfer_service.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late DriftPlaceRepository placeRepo;
  late DriftTripRepository tripRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'u1', placeRepo);
  });

  tearDown(() => db.close());

  testWidgets('Sync via my Google Drive runs in the background: no modal progress, a strip with Cancel',
      (tester) async {
    final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
        .write(const TripsCompanion(sharing: Value('group')));
    await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl1', name: 'Uji', lat: 34.9, lng: 135.8));
    final stop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl1', addedBy: 'u1');
    for (final id in ['f1', 'f2']) {
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(stop.id),
            localPath: Value('/phone/$id.jpg'),
          ));
    }

    // The first upload hangs until the test lets it go.
    final release = Completer<void>();
    var uploads = 0;
    final client = MockClient((req) async {
      if (req.method == 'GET') return http.Response(jsonEncode({'files': [{'id': 'folder'}]}), 200);
      if (req.url.path == '/upload/drive/v3/files') {
        uploads++;
        await release.future;
        return http.Response(jsonEncode({'id': 'drv_$uploads'}), 200);
      }
      return http.Response('{}', 200);
    });
    final drive = GoogleDriveFrameService(
      client: client,
      getToken: ({bool interactive = true}) async => 'tok',
      compress: (b) async => b,
      readFile: (path) async => utf8.encode(path),
    );
    final service = FakeTransferService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          placeRepositoryProvider.overrideWithValue(placeRepo),
          tripRepositoryProvider.overrideWithValue(tripRepo),
          currentUserIdProvider.overrideWithValue('u1'),
          myTripRoleProvider(trip.id).overrideWithValue(TripMemberRole.owner),
          tripMembersProvider(trip.id).overrideWith(
            (_) => Stream.value([
              TripMember(userId: 'u1', tripId: trip.id, role: TripMemberRole.owner, displayName: 'U1', joinedAt: DateTime(2026)),
            ]),
          ),
          googleDriveFrameServiceProvider.overrideWithValue(drive),
          // Its count checks files on disk, which a widget test can't wait for.
          pendingFrameDownloadCountProvider(trip.id).overrideWith((_) => Stream.value(0)),
          transferForegroundServiceProvider.overrideWithValue(service),
          transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
          appVisibleProvider.overrideWithValue(() => true),
        ],
        child: MaterialApp(theme: AppTheme.light, home: TripScreen(tripId: trip.id, initialTab: TripTab.members)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("2 frames on this phone aren't on Google Drive yet."), findsOneWidget);
    final sync = find.text('Sync via my Google Drive');
    await tester.ensureVisible(sync);
    await tester.tap(sync);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload & sync'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // the confirm dialog's exit

    // No dialog holds the screen: the progress is a strip in the card.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TransferJobStrip), findsOneWidget);
    expect(find.text('0 of 2'), findsOneWidget);
    expect(find.text('Uploading 2 frames to Google Drive in the background.'), findsOneWidget);
    expect(service.calls.where((c) => c.startsWith('start')), hasLength(1), reason: 'the foreground service is up');
    // The rest of the tab stays usable.
    expect(find.text('Share local frames'), findsOneWidget);

    final cancel = find.descendant(of: find.byType(TransferJobStrip), matching: find.text('Cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    expect(find.text('Cancelling…'), findsOneWidget);

    release.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(TransferJobStrip), findsNothing);
    expect(find.text('Upload cancelled.'), findsOneWidget);
    expect(uploads, 1, reason: 'stops after the frame in flight');
    expect(service.calls.last, 'stop');
    final f1 = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f1'))).getSingle();
    expect(f1.remoteUrl, isNotNull, reason: 'the frame that finished is kept');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the global indicator shows the running transfer with Cancel', (tester) async {
    final service = FakeTransferService();
    final gate = Completer<void>();
    final container = ProviderContainer(overrides: [
      transferForegroundServiceProvider.overrideWithValue(service),
      transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
      appVisibleProvider.overrideWithValue(() => true),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => TransferStatusOverlay(child: child!),
        home: const Scaffold(body: Text('Home')),
      ),
    ));
    expect(find.textContaining('Downloading frames'), findsNothing);

    container.read(frameTransferQueueProvider.notifier).enqueue(TransferJobSpec(
          kind: TransferKind.download,
          tripId: 't1',
          tripTitle: 'Kansai',
          run: (ctx) async {
            ctx.progress(30, 180);
            await gate.future;
            if (ctx.cancel.isCancelled) throw Exception('should be cancelled');
            return 'done';
          },
        ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Downloading frames · 30 of 180'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Cancelling…'), findsOneWidget);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Downloading frames'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
