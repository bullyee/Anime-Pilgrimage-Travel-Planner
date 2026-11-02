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

  testWidgets('trips show their dates and come in order', (tester) async {
    final repo = DriftTripRepository(db);
    await repo.createTrip(title: 'Someday', ownerId: 'u1', dayCount: 2);
    await repo.createTrip(title: 'Long ago', ownerId: 'u1', startDate: '2020-03-01', dayCount: 2);
    await repo.createTrip(title: 'Next year', ownerId: 'u1', startDate: '${DateTime.now().year + 1}-04-29', dayCount: 5);

    await pumpList(tester);
    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((s) => s == 'Someday' || s == 'Long ago' || s == 'Next year')
        .toList();
    expect(titles, ['Next year', 'Someday', 'Long ago']);
    expect(find.text('Apr 29 – May 3, ${DateTime.now().year + 1} · 5 days'), findsOneWidget);
    expect(find.text('No dates yet · 2 days'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await disposeApp(tester);
  });
}
