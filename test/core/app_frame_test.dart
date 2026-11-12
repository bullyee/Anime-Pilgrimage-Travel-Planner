import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/router/app_frame.dart';
import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart';

/// A tab's page with a counter, to see whether it keeps its state.
class _Counter extends StatefulWidget {
  final String name;
  const _Counter(this.name);

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.name} page')),
        body: Column(children: [
          Text('${widget.name}: $n'),
          TextButton(onPressed: () => setState(() => n++), child: Text('add to ${widget.name}')),
          TextButton(onPressed: () => context.push('/detail'), child: Text('open from ${widget.name}')),
        ]),
      );
}

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppFrame(shell: shell),
          branches: [
            for (final (path, name) in [('/', 'home'), ('/trips', 'trips'), ('/library', 'library'), ('/photos', 'photos')])
              StatefulShellBranch(routes: [GoRoute(path: path, builder: (_, _) => _Counter(name))]),
          ],
        ),
        GoRoute(path: '/detail', builder: (_, _) => const Scaffold(body: Text('detail page'))),
      ],
    );

void main() {
  tearDown(() => debugAnimeCameraSupportedOverride = null);

  Future<GoRouter> pump(WidgetTester tester, {bool camera = true}) async {
    debugAnimeCameraSupportedOverride = camera;
    final router = _router();
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the bar has the four tabs with Shoot in the middle', (tester) async {
    await pump(tester);
    for (final label in ['Home', 'Trips', 'Library', 'Photos']) {
      expect(find.byKey(Key('appTab:${label.toLowerCase()}')), findsOneWidget);
    }
    expect(find.byTooltip('Shoot'), findsOneWidget);
    final trips = tester.getCenter(find.byKey(const Key('appTab:trips'))).dx;
    final library = tester.getCenter(find.byKey(const Key('appTab:library'))).dx;
    final shoot = tester.getCenter(find.byTooltip('Shoot')).dx;
    expect(shoot, greaterThan(trips));
    expect(shoot, lessThan(library));
  });

  testWidgets('no Shoot where there is no camera', (tester) async {
    await pump(tester, camera: false);
    expect(find.byTooltip('Shoot'), findsNothing);
    expect(find.byKey(const Key('appTab:photos')), findsOneWidget);
  });

  testWidgets('each tab keeps where it was', (tester) async {
    await pump(tester);
    await tester.tap(find.text('add to home'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('appTab:trips')));
    await tester.pumpAndSettle();
    expect(find.text('trips page'), findsOneWidget);
    await tester.tap(find.text('add to trips'));
    await tester.tap(find.text('add to trips'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('appTab:home')));
    await tester.pumpAndSettle();
    expect(find.text('home: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('appTab:trips')));
    await tester.pumpAndSettle();
    expect(find.text('trips: 2'), findsOneWidget);
  });

  testWidgets('a page opens full screen over the bar, and back returns to its tab', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.byKey(const Key('appTab:library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open from library'));
    await tester.pumpAndSettle();
    expect(find.text('detail page'), findsOneWidget);
    expect(find.byKey(const Key('appTab:home')), findsNothing, reason: 'the bar is under the page');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('library page'), findsOneWidget);
    expect(find.byKey(const Key('appTab:home')), findsOneWidget);
  });

  testWidgets('back on another tab goes to Home first', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('appTab:photos')));
    await tester.pumpAndSettle();
    expect(find.text('photos page'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('going to a tab by its path switches the tab', (tester) async {
    final router = await pump(tester);
    router.go('/photos');
    await tester.pumpAndSettle();
    expect(find.text('photos page'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(const Key('appTab:photos'))), containsSemantics(isSelected: true));
    expect(tester.getSemantics(find.byKey(const Key('appTab:home'))), containsSemantics(isSelected: false));
  });
}
