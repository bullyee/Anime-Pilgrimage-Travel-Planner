import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../library/providers/library_providers.dart';
import '../../library/widgets/spot_thumb.dart';
import '../providers/home_providers.dart';

/// Library places near the phone, the same on every day: a trip is one card
/// on Home, not the whole of it. Home never asks for location by itself;
/// until the app may use it, this is a button that asks.
class NearYou extends ConsumerWidget {
  const NearYou({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final where = ref.watch(homeWhereProvider).valueOrNull;
    final entries = ref.watch(libraryEntriesProvider).valueOrNull;
    if (where == null || entries == null || !entries.any((e) => e.isSaved)) return const SizedBox.shrink();

    final header = Row(
      children: [
        Expanded(child: Text('Near you', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => context.push('/library'), child: const Text('Library')),
      ],
    );

    if (!where.allowed) {
      return Column(
        key: const Key('homeNearYou'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          OutlinedButton.icon(
            onPressed: () => allowHomeLocation(ref),
            icon: Icon(Icons.near_me_outlined, color: p.tea),
            label: const Text('Show library places near me'),
          ),
        ],
      );
    }
    final at = where.at;
    if (at == null) return const SizedBox.shrink();
    final near = nearbyPlaces(entries, at);

    return Column(
      key: const Key('homeNearYou'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (near.isEmpty)
          Text('Nothing from your library within 3 km.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          for (final n in near)
            ListTile(
              key: ValueKey('homeNear:${n.entry.place.placeKey}'),
              contentPadding: EdgeInsets.zero,
              leading: SpotThumb(
                placeKey: n.entry.place.placeKey,
                size: 52,
                fallback: CircleAvatar(
                  radius: 26,
                  backgroundColor: p.wisteriaSoft,
                  child: Icon(Icons.place_outlined, color: p.wisteria),
                ),
              ),
              title: Text(n.entry.place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [formatMeters(n.meters), ...n.entry.labelsOf('anime').take(1).map((l) => l.name)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: animeCameraSupported
                  ? IconButton(
                      tooltip: 'Take photo here',
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: () => openAnimeCamera(context, ref, placeKey: n.entry.place.placeKey),
                    )
                  : null,
              onTap: () => context.push('/library/places/${Uri.encodeComponent(n.entry.place.placeKey)}'),
            ),
      ],
    );
  }
}
