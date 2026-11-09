import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/home_providers.dart';

/// A pin on Home's small map: [label] inside it, a check when [done], and a
/// ring when it's the one to go to next.
class MiniPin {
  final double lat;
  final double lng;
  final String label;
  final bool done;
  final bool next;

  const MiniPin({required this.lat, required this.lng, required this.label, this.done = false, this.next = false});
}

/// The small map in Home's top card: the pins, fitted, and nothing to drag.
/// Tapping it opens the big map.
class HomeMiniMap extends ConsumerWidget {
  final List<MiniPin> pins;
  final Color color;
  final Color doneColor;
  final VoidCallback onOpen;
  final String openLabel;

  const HomeMiniMap({
    super.key,
    required this.pins,
    required this.color,
    required this.doneColor,
    required this.onOpen,
    this.openLabel = 'Open map',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tiles = ref.watch(homeMapTilesProvider);
    final points = [for (final p in pins) LatLng(p.lat, p.lng)];
    final fit = points.length < 2
        ? null
        : CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(28), maxZoom: 16);

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
                      : FlutterMap(
                          key: ValueKey(Object.hashAll(points)),
                          options: MapOptions(
                            initialCenter: points.first,
                            initialZoom: 15,
                            initialCameraFit: fit,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                          children: [
                            if (tiles)
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.trip_planner',
                              ),
                            MarkerLayer(markers: [
                              for (final (i, pin) in pins.indexed)
                                Marker(
                                  point: points[i],
                                  width: pin.next ? 34 : 26,
                                  height: pin.next ? 34 : 26,
                                  child: _Pin(pin: pin, color: pin.done ? doneColor : color),
                                ),
                            ]),
                          ],
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

class _Pin extends StatelessWidget {
  final MiniPin pin;
  final Color color;

  const _Pin({required this.pin, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          if (pin.next) BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 4),
          const BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: pin.done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                pin.label,
                style: TextStyle(color: Colors.white, fontSize: pin.next ? 13 : 11, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
