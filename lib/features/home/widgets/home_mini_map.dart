import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/map/app_map.dart';

/// The small map in Home's top card: the pins, fitted, clustered when they
/// crowd, and nothing to drag. Tapping it opens the big map. Built on the same
/// [AppMap] as the day map, so its pins look the same.
class HomeMiniMap extends ConsumerWidget {
  final List<MapPin> pins;
  final VoidCallback onOpen;
  final String openLabel;

  const HomeMiniMap({
    super.key,
    required this.pins,
    required this.onOpen,
    this.openLabel = 'Open map',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tiles = ref.watch(mapTilesProvider);
    final points = [for (final p in pins) p.point];

    return Semantics(
      button: true,
      label: openLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 168,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: points.isEmpty
                      ? ColoredBox(color: theme.colorScheme.surfaceContainerHighest)
                      : AppMap(
                          pins: pins,
                          interactive: false,
                          attribution: false,
                          fitPadding: const EdgeInsets.all(28),
                          // New pins (another day, a stop added) fit the map again.
                          fitKey: Object.hashAll(points),
                        ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onOpen),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 1))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(openLabel, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (tiles && points.isNotEmpty)
                Positioned(
                  left: 6,
                  bottom: 4,
                  child: IgnorePointer(
                    child: Text('© OpenStreetMap',
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: const Color(0xFF3C4043))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
