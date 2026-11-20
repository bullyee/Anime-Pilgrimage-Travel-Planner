import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/widgets/place_page_parts.dart';
import 'package:trip_planner/shared/theme/app_theme.dart';

const _tinyPngDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

NewReferenceImage _frame(String id, {String? episode}) => NewReferenceImage(
      id: id,
      placeKey: 'uji',
      localPath: _tinyPngDataUrl,
      episode: episode,
      createdAt: DateTime(2026),
    );

class _HeroHost extends StatefulWidget {
  final List<NewReferenceImage> frames;

  const _HeroHost({required this.frames});

  @override
  State<_HeroHost> createState() => _HeroHostState();
}

class _HeroHostState extends State<_HeroHost> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FrameHero(
          frames: widget.frames,
          index: _index,
          onPage: (i) => setState(() => _index = i),
          onOpen: (_) {},
        ),
      ),
    );
  }
}

class _DynamicHeroHarness extends StatefulWidget {
  final ValueNotifier<List<NewReferenceImage>> frames;
  final int initialIndex;

  const _DynamicHeroHarness({required this.frames, this.initialIndex = 0});

  @override
  State<_DynamicHeroHarness> createState() => _DynamicHeroHarnessState();
}

class _DynamicHeroHarnessState extends State<_DynamicHeroHarness> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<NewReferenceImage>>(
        valueListenable: widget.frames,
        builder: (_, list, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FrameHero(
              frames: list,
              index: _index,
              onPage: (i) => setState(() => _index = i),
              onOpen: (_) {},
            ),
          ),
        ),
      );
}

void main() {
  final frames = [
    _frame('f1', episode: '1'),
    _frame('f2', episode: '2'),
    _frame('f3', episode: '3'),
  ];

  testWidgets('desktop shows chevron buttons, clickable dots, and supports mouse drag', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(child: _HeroHost(frames: frames)));
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byTooltip('Previous frame'), findsNothing);
    expect(find.byTooltip('Next frame'), findsOneWidget);

    await tester.tap(find.byTooltip('Next frame'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byTooltip('Previous frame'), findsOneWidget);
    expect(find.byTooltip('Next frame'), findsOneWidget);

    await tester.tap(find.byTooltip('Next frame'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.byTooltip('Next frame'), findsNothing);

    await tester.tap(find.byTooltip('Previous frame'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    // Click indicator dot to jump directly to Frame 1.
    await tester.tap(find.bySemanticsLabel('Frame 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    // Mouse drag navigates cleanly between frames (two moves so touch slop is crossed then dragged).
    final center = tester.getCenter(find.byType(PageView));
    final drag = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(-30, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-380, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('phone hides overlay chevron buttons while touch swipe and indicator dots work', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3; // 360x800 logical phone
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(child: _HeroHost(frames: frames)));
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byTooltip('Previous frame'), findsNothing);
    expect(find.byTooltip('Next frame'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Frame 3'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('narrow desktop window (< 600dp) still shows frame chevron buttons', (tester) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(ProviderScope(child: _HeroHost(frames: frames)));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Next frame'), findsOneWidget);
      await tester.tap(find.byTooltip('Next frame'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('clamps safely via didUpdateWidget when frames shrink below the current index', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final list = ValueNotifier<List<NewReferenceImage>>(frames);
    addTearDown(list.dispose);

    await tester.pumpWidget(ProviderScope(child: _DynamicHeroHarness(frames: list, initialIndex: 2)));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    list.value = frames.take(2).toList();
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
