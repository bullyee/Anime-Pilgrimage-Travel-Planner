import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/map/map_pins.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/up_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/widgets/place_page_parts.dart' show FrameImage;
import '../../trip/models/trip_places_view.dart' show dayPalette;
import '../../trip/providers/trip_providers.dart';
import '../models/example_route.dart';
import '../providers/example_routes_providers.dart';
import '../services/example_route_service.dart';

/// A route frame as the app's frame widget takes it: its picture's link.
NewReferenceImage _frameOf(String key, RouteFrame f) =>
    NewReferenceImage(id: 'route:$key', remoteUrl: f.image, episode: f.episode, note: f.shot?.note, createdAt: DateTime(2026));

/// The list of example routes (`/t`): routes from our own pilgrimages, each
/// opening its page.
class ExampleRoutesScreen extends ConsumerWidget {
  const ExampleRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final routes = ref.watch(exampleRouteIndexProvider);
    return Scaffold(
      appBar: AppBar(leading: UpButton.ifAlone(context, fallback: '/trips'), title: Text(l10n.routesTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: routes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Problem(text: l10n.routesLoadFailed, onRetry: () => ref.invalidate(exampleRouteIndexProvider)),
            data: (list) => ListView(
              key: const Key('exampleRoutesList'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(l10n.routesIntro, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                if (list.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text(l10n.routesEmpty))),
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RouteCard(route: r, onTap: () => context.push('/t/${r.id}')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final ExampleRouteSummary route;
  final VoidCallback onTap;

  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final line = [if (route.anime.isNotEmpty) route.anime.join('、'), ?route.area].join(' · ');
    return Card(
      key: ValueKey('route:${route.id}'),
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 6,
              child: route.cover == null
                  ? ColoredBox(color: p.wisteriaSoft, child: Icon(Icons.route_outlined, color: p.wisteria, size: 40))
                  : FrameImage(frame: _frameOf(route.id, RouteFrame(image: route.cover)), cacheWidth: 900),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (line.isNotEmpty) Text(line, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(context.l10n.routeCounts(route.places, route.frames), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Problem({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: Text(context.l10n.routesRetry)),
              ],
            ],
          ),
        ),
      );
}

/// One example route (`/t/<id>`): its places on a map and by group, each
/// with its frames and where they're shot from, the credits, and **Copy
/// this route** into a private trip. Anyone can open it, signed in or not.
class ExampleRouteScreen extends ConsumerStatefulWidget {
  final String routeId;

  const ExampleRouteScreen({super.key, required this.routeId});

  @override
  ConsumerState<ExampleRouteScreen> createState() => _ExampleRouteScreenState();
}

class _ExampleRouteScreenState extends ConsumerState<ExampleRouteScreen> {
  bool _copying = false;
  String? _picked;

  Future<void> _copy(ExampleRoute route) async {
    setState(() => _copying = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final trip = await copyExampleRoute(
        db: ref.read(databaseProvider),
        repo: ref.read(tripRepositoryProvider),
        route: route,
        ownerId: ref.read(currentUserIdProvider),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.routeCopied)));
      context.go('/trips/${trip.id}');
    } catch (e) {
      if (mounted) setState(() => _copying = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.routeCopyFailed('$e'))));
    }
  }

  Future<void> _copyLink() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: exampleRouteLink(widget.routeId)));
    messenger.showSnackBar(SnackBar(content: Text(l10n.routeLinkCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final route = ref.watch(exampleRouteProvider(widget.routeId));
    return Scaffold(
      appBar: AppBar(
        leading: UpButton.ifAlone(context, fallback: '/t'),
        title: Text(route.valueOrNull?.title ?? l10n.routesTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(key: const Key('routeCopyLink'), tooltip: l10n.routeCopyLink, icon: const Icon(Icons.link), onPressed: _copyLink),
        ],
      ),
      body: route.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Problem(
          text: e is ExampleRouteFormatException ? l10n.routeNotFound : l10n.routesLoadFailed,
          onRetry: () => ref.invalidate(exampleRouteProvider(widget.routeId)),
        ),
        data: (r) => _body(context, r),
      ),
      bottomNavigationBar: route.valueOrNull == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                key: const Key('routeCopy'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _copying ? null : () => _copy(route.value!),
                icon: _copying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.content_copy_outlined),
                label: Text(_copying ? l10n.routeCopying : l10n.routeCopy),
              ),
            ),
    );
  }

  Widget _body(BuildContext context, ExampleRoute route) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = dayPalette(theme);
    final groups = route.groups.where((g) => g.places.isNotEmpty).toList();
    final line = [if (route.anime.isNotEmpty) route.anime.join('、'), ?route.area].join(' · ');
    final pins = [
      for (var gi = 0; gi < groups.length; gi++)
        for (var pi = 0; pi < groups[gi].places.length; pi++)
          MapPin(
            id: 'g$gi-p$pi',
            point: LatLng(groups[gi].places[pi].lat, groups[gi].places[pi].lng),
            name: groups[gi].places[pi].name,
            color: palette[gi % palette.length],
            label: '${pi + 1}',
            selected: _picked == 'g$gi-p$pi',
          ),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const Key('exampleRoute'),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (line.isNotEmpty) Text(line, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(l10n.routeCounts(route.placeCount, route.frameCount), style: theme.textTheme.bodySmall),
                  if (route.description case final d?) ...[
                    const SizedBox(height: 10),
                    Text(d, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            if (pins.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 240,
                    child: AppMap(
                      key: const Key('routeMap'),
                      pins: pins,
                      fitKey: route.id,
                      onPinTap: (pin) => setState(() => _picked = pin.id),
                    ),
                  ),
                ),
              ),
            for (var gi = 0; gi < groups.length; gi++) ...[
              _GroupHeader(title: groups[gi].title ?? l10n.placeDayN(gi + 1), color: palette[gi % palette.length], count: groups[gi].places.length),
              for (var pi = 0; pi < groups[gi].places.length; pi++)
                _PlaceTile(keyId: 'g$gi-p$pi', index: pi + 1, place: groups[gi].places[pi], color: palette[gi % palette.length]),
            ],
            if (route.credits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text(
                  [for (final c in route.credits) l10n.routeCredit(c.license == null ? c.name : '${c.name} (${c.license})')].join('\n'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int count;

  const _GroupHeader({required this.title, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          Text(context.l10n.routePlaceCount(count), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final String keyId;
  final int index;
  final RoutePlace place;
  final Color color;

  const _PlaceTile({required this.keyId, required this.index, required this.place, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    // The frames with a picture first, then the ones shown by their spot.
    final frames = [...place.pictured, ...place.frames.where((f) => f.image == null)];
    return Padding(
      key: ValueKey('routePlace:$keyId'),
      padding: const EdgeInsets.fromLTRB(16, 6, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 11, backgroundColor: color, child: Text('$index', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      if (place.about case final a?) Text(a, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (frames.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: frames.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = frames[i];
                  final caption = [?f.shot?.note, if (f.episode != null) context.l10n.routeEpisode(f.episode!)].join(' · ');
                  return SizedBox(
                    width: 176,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 176,
                            height: 99,
                            child: f.image == null
                                ? ColoredBox(
                                    color: p.wisteriaSoft,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.photo_camera_outlined, color: p.wisteria, size: 20),
                                          Text(context.l10n.routeNoPicture, style: theme.textTheme.labelSmall?.copyWith(color: p.wisteria)),
                                        ],
                                      ),
                                    ),
                                  )
                                : FrameImage(frame: _frameOf('$keyId-$i', f), cacheWidth: 400),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (caption.isNotEmpty)
                          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
