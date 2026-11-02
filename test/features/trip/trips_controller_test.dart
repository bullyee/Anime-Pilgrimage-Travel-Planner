import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/utils/app_result.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/trip/controllers/trips_controller.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('u1'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TripsController controller() => container.read(tripsControllerProvider.notifier);

  test('creating a trip makes its days and owns it', () async {
    final result = await controller().createTrip(
      title: '  Kyoto pilgrimage ',
      startDate: DateTime(2027, 4, 29),
      dayCount: 5,
    );
    final trip = (result as Success<Trip>).value;
    expect(trip.title, 'Kyoto pilgrimage');
    expect(trip.ownerId, 'u1');
    expect(trip.startDate, '2027-04-29');
    expect(trip.dayCount, 5);
    final days = await container.read(tripRepositoryProvider).getDaysForTrip(trip.id);
    expect(days, hasLength(5));
  });

  test('a trip needs a name and 1 to 60 days', () async {
    expect(await controller().createTrip(title: '  ', dayCount: 3), isA<Failure<Trip>>());
    expect(await controller().createTrip(title: 'x', dayCount: 0), isA<Failure<Trip>>());
    expect(await controller().createTrip(title: 'x', dayCount: 61), isA<Failure<Trip>>());
    expect(await container.read(tripRepositoryProvider).getTrips(), isEmpty);
  });

  test('editing renames the trip and sets or clears the start date', () async {
    final trip = ((await controller().createTrip(title: 'Old', dayCount: 2)) as Success<Trip>).value;
    expect(await controller().updateTrip(tripId: trip.id, title: 'New', startDate: DateTime(2027, 5, 1)),
        isA<Success<void>>());
    var stored = await container.read(tripRepositoryProvider).getTrip(trip.id);
    expect(stored!.title, 'New');
    expect(stored.startDate, '2027-05-01');

    await controller().updateTrip(tripId: trip.id, title: 'New', startDate: null);
    stored = await container.read(tripRepositoryProvider).getTrip(trip.id);
    expect(stored!.startDate, isNull);
  });

  test('a start date that would put a pinned day too early is refused', () async {
    final repo = container.read(tripRepositoryProvider);
    final trip = ((await controller().createTrip(
      title: 'Golden Week',
      startDate: DateTime(2027, 4, 29),
      dayCount: 3,
    )) as Success<Trip>).value;
    final days = await repo.getDaysForTrip(trip.id);
    await repo.pinDayBlockDate(days[2].id, '2027-05-03');

    // Day 3 is pinned to May 3, so the trip can't start on May 2 or later.
    final result = await controller().updateTrip(tripId: trip.id, title: 'Golden Week', startDate: DateTime(2027, 5, 2));
    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).error, contains('Day 3'));
    expect((await repo.getTrip(trip.id))!.startDate, '2027-04-29');

    expect(await controller().updateTrip(tripId: trip.id, title: 'Golden Week', startDate: DateTime(2027, 4, 30)),
        isA<Success<void>>());
  });

  test('a deleted trip leaves the list', () async {
    final trip = ((await controller().createTrip(title: 'Gone', dayCount: 1)) as Success<Trip>).value;
    expect(await controller().deleteTrip(trip.id), isA<Success<void>>());
    expect(await container.read(tripRepositoryProvider).getTrips(), isEmpty);
  });
}
