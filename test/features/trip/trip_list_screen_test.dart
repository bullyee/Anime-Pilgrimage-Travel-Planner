import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_list_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpList(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(path: '/trips', builder: (_, _) => const TripListScreen()),
        GoRoute(
          path: '/trips/:tripId',
          builder: (_, state) => Scaffold(body: Text('overview of ${state.pathParameters['tripId']}')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('with no trips it says so and offers to make one', (tester) async {
    await pumpList(tester);
    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('a new trip is created from the form and opened', (tester) async {
    await pumpList(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New trip'));
    await tester.pumpAndSettle();

    // A name is required.
    await tester.tap(find.byKey(const Key('tripFormSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Give the trip a name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('tripTitleField')), 'Kyoto pilgrimage');
    await tester.tap(find.byTooltip('One more day'));
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tripFormSubmit')));
    await tester.pumpAndSettle();

    final trips = await DriftTripRepository(db).getTrips();
    expect(trips.single.title, 'Kyoto pilgrimage');
    expect(trips.single.dayCount, 4);
    expect(find.text('overview of ${trips.single.id}'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('trips come under their sections, with the year only when it is not this year', (tester) async {
    final repo = DriftTripRepository(db);
    await repo.createTrip(title: 'Someday', ownerId: 'u1', dayCount: 2);
    await repo.createTrip(title: 'Long ago', ownerId: 'u1', startDate: '2020-03-01', dayCount: 2);
    await repo.createTrip(title: 'Next year', ownerId: 'u1', startDate: '${DateTime.now().year + 1}-04-29', dayCount: 5);

    await pumpList(tester);
    const shown = {'COMING UP', 'Next year', 'NO DATES YET', 'Someday', 'FINISHED', 'Long ago'};
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>();
    expect(texts.where(shown.contains), ['COMING UP', 'Next year', 'NO DATES YET', 'Someday', 'FINISHED', 'Long ago']);
    expect(find.text('${DateTime.now().year + 1}'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.textContaining(' days'), findsNothing, reason: 'cards leave out how long a trip is');
    expect(find.text('Finished'), findsNothing, reason: 'the section says it; the card has no status chip');
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('the filter shows the shared or the private trips', (tester) async {
    final repo = DriftTripRepository(db);
    final shared = await repo.createTrip(title: 'Kansai with friends', ownerId: 'u1', dayCount: 2);
    await repo.createTrip(title: 'Solo walk', ownerId: 'u1');
    await (db.update(db.trips)..where((t) => t.id.equals(shared.id))).write(const TripsCompanion(sharing: Value('group')));

    await pumpList(tester);
    expect(find.text('Kansai with friends'), findsOneWidget);
    expect(find.text('Solo walk'), findsOneWidget);
    expect(find.text('Shared'), findsOneWidget, reason: 'the shared trip says so');

    await tester.tap(find.text('Shared 1'));
    await tester.pumpAndSettle();
    expect(find.text('Kansai with friends'), findsOneWidget);
    expect(find.text('Solo walk'), findsNothing);

    await tester.tap(find.text('Private 1'));
    await tester.pumpAndSettle();
    expect(find.text('Kansai with friends'), findsNothing);
    expect(find.text('Solo walk'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('the shared filter says where shared trips will show up while there are none', (tester) async {
    await DriftTripRepository(db).createTrip(title: 'Solo walk', ownerId: 'u1');
    await pumpList(tester);
    await tester.tap(find.text('Shared 0'));
    await tester.pumpAndSettle();
    expect(find.text('No shared trips yet'), findsOneWidget);
    expect(find.text('Solo walk'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget, reason: 'a new trip can still be made');
    await disposeApp(tester);
  });
}
