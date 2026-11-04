import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('Security Isolation Tests (Adversarial Verification)', () {
    test('Guest user cannot see signed-in user trips in getTrips or watchTrips', () async {
      // Create trip owned by Alice
      final aliceRepo = DriftTripRepository(db, null, 'user_alice');
      await aliceRepo.createTrip(title: "Alice's Secret Trip", ownerId: 'user_alice');

      // Create trip owned by Guest
      final guestRepo = DriftTripRepository(db, null, 'guest_local_user');
      await guestRepo.createTrip(title: 'Guest Local Trip', ownerId: 'guest_local_user');

      // 1. Guest queries trips
      final guestTrips = await guestRepo.getTrips();
      expect(guestTrips.length, 1);
      expect(guestTrips.first.title, 'Guest Local Trip');

      // 2. Guest watches trips
      final guestStreamTrips = await guestRepo.watchTrips().first;
      expect(guestStreamTrips.length, 1);
      expect(guestStreamTrips.first.title, 'Guest Local Trip');

      // 3. Guest tries to directly getTrip Alice's trip
      final allTripsInDb = await (db.select(db.trips)).get();
      final aliceTripId = allTripsInDb.firstWhere((t) => t.ownerId == 'user_alice').id;
      final tripAttempt = await guestRepo.getTrip(aliceTripId);
      expect(tripAttempt, isNull, reason: 'Guest must be denied access to private trip of signed-in user');

      final streamAttempt = await guestRepo.watchTrip(aliceTripId).first;
      expect(streamAttempt, isNull, reason: 'Guest stream must emit null for private trip of signed-in user');

      // 4. Alice queries trips: sees her trip
      final aliceTrips = await aliceRepo.getTrips();
      expect(aliceTrips.any((t) => t.title == "Alice's Secret Trip"), isTrue);
    });
  });
}

