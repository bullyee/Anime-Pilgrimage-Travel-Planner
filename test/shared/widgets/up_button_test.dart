import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/shared/widgets/up_button.dart';

/// My Trips, and a trip screen whose back arrow falls back to it, as the
/// app's router has them (both top-level, so a trip opened by `go` is alone).
GoRouter _router(String initialLocation, {bool guarded = false, VoidCallback? onBlocked}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/trips',
          builder: (context, state) => Scaffold(
            body: TextButton(onPressed: () => context.push('/trips/a'), child: const Text('My Trips')),
          ),
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) => PopScope(
            canPop: !guarded,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) onBlocked?.call();
            },
            child: Scaffold(
              appBar: AppBar(leading: UpButton.ifAlone(context, fallback: '/trips'), title: const Text('Trip')),
            ),
          ),
        ),
      ],
    );

void main() {
  testWidgets('a trip opened on its own, as after joining, goes back to My Trips', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('/trips/a')));
    await tester.pumpAndSettle();

    expect(find.byType(UpButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('My Trips'), findsOneWidget);
    expect(find.text('Trip'), findsNothing);
  });

  testWidgets('a trip opened from My Trips keeps the usual back arrow', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('/trips')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Trips'));
    await tester.pumpAndSettle();

    expect(find.byType(UpButton), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('My Trips'), findsOneWidget);
  });

  testWidgets("the screen's back guard runs before the fallback", (tester) async {
    var blocked = 0;
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _router('/trips/a', guarded: true, onBlocked: () => blocked++),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(blocked, 1);
    expect(find.text('Trip'), findsOneWidget);
  });

  testWidgets('without a router, the app bar is left as it is', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(appBar: AppBar(leading: UpButton.ifAlone(context, fallback: '/trips')))),
    ));

    expect(find.byType(UpButton), findsNothing);
  });
}
