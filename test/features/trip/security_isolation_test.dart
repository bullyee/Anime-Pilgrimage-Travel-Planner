import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/stop_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('Local Phone Persistence & Shared Auth Guard Tests', () {
    test('Signed-out guest can still see and watch local trips created while signed in', () async {
      // 1. User signs in as Alice and creates a trip on this device
      final aliceRepo = DriftTripRepository(db, null, 'user_alice');
      final trip = await aliceRepo.createTrip(title: "Alice's Japan Trip", ownerId: 'user_alice');

      // 2. User signs out -> app session becomes guest_local_user
      final guestRepo = DriftTripRepository(db, null, 'guest_local_user');

      // 3. The phone must keep showing its local trips after sign-out
      final guestTrips = await guestRepo.getTrips();
      expect(guestTrips.length, 1);
      expect(guestTrips.first.title, "Alice's Japan Trip");

      final guestStreamTrips = await guestRepo.watchTrips().first;
      expect(guestStreamTrips.length, 1);
      expect(guestStreamTrips.first.title, "Alice's Japan Trip");

      final directTrip = await guestRepo.getTrip(trip.id);
      expect(directTrip, isNotNull);
      expect(directTrip!.id, trip.id);

      final directStreamTrip = await guestRepo.watchTrip(trip.id).first;
      expect(directStreamTrip, isNotNull);
      expect(directStreamTrip!.id, trip.id);
    });

    testWidgets('StopScreen shows sign-in required SnackBar when guest attempts to edit shared group trip', (tester) async {
      // Insert a shared group trip and a stop
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_group_1',
              title: 'Shared Group Trip',
              ownerId: 'user_alice',
              sharing: const Value('group'),
            ),
          );

      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_1',
              tripId: 'trip_group_1',
              placeKey: 'place_uji_bridge',
              name: 'Uji Bridge',
              lat: 34.8935,
              lng: 135.8075,
              addedBy: 'user_alice',
            ),
          );

      // Pump StopScreen with unauthenticated (guest) user
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWithValue('guest_local_user'),
            tripRepositoryProvider.overrideWithValue(DriftTripRepository(db, null, 'guest_local_user')),
          ],
          child: const MaterialApp(
            home: StopScreen(tripId: 'trip_group_1', stopId: 'stop_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Edit button in AppBar and tap it
      expect(find.byTooltip('Edit'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      // Verify sign-in guard blocked mutation and showed SnackBar
      expect(find.text('Please sign in to edit a shared trip.'), findsOneWidget);

      // Verify edit fields are NOT present
      expect(find.text('Save changes'), findsNothing);

      await disposeApp(tester);
    });
  });
}
