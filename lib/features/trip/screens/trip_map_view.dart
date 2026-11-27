import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../library/widgets/place_page_parts.dart' show FrameImage;
import '../models/place_spots.dart';
import '../models/trip_places_view.dart';
import '../widgets/position_follower.dart';
import 'trip_place_screen.dart' show FrameCell, sectionDate, sectionTitle;

/// Past this zoom a place's pin parts into its spots' pins.
const spotPinZoom = 16.5;

/// A place as the trip map shows it: with what it holds, the section it's
/// in and that section's colour.
class TripMapPlace {
  final TripPlace place;
  final PlaceContent content;
  final PlacesSection section;
  final Color color;

  const TripMapPlace({required this.place, required this.content, required this.section, required this.color});

  String get id => place.id;

  /// Where its pin goes: its (first) stop's position.
  LatLng get point => LatLng(place.stop.lat, place.stop.lng);
}

/// A place's name drawn on the map once it has parted into its spots; not
/// tappable.
class TripMapLabel {
  final String placeId;
  final String name;
  final LatLng point;
  final Color color;

  const TripMapLabel({required this.placeId, required this.name, required this.point, required this.color});
}

/// What a pin stands for: a place, or one of its spots.
typedef TripMapTarget = ({String placeId, String? spotKey});

/// The trip map's markers for [places].
class TripMapMarkers {
  final List<MapPin> pins;

  /// The places' names, only with spot pins.
  final List<TripMapLabel> labels;

  /// What each pin stands for, by its id.
  final Map<String, TripMapTarget> targets;

  const TripMapMarkers({required this.pins, required this.labels, required this.targets});
}

/// The pins of [places]: one per place, showing [face]'s picture of it, its
/// frame count and its section's colour; or, with [spots] (zoomed in past
/// [spotPinZoom]), one per spot of each place, done when the spot is shot,
/// plus each place's name as a label. [selectedPlace] / [selectedSpot] mark
/// the picked one.
TripMapMarkers tripMapMarkers(
  List<TripMapPlace> places, {
  required bool spots,
  String? selectedPlace,
  String? selectedSpot,
  Widget? Function(TripMapPlace place)? face,
}) {
  final pins = <MapPin>[];
  final labels = <TripMapLabel>[];
  final targets = <String, TripMapTarget>{};
  for (final p in places) {
    if (!spots) {
      final id = 'place:${p.id}';
      targets[id] = (placeId: p.id, spotKey: null);
      pins.add(MapPin(
        id: id,
        point: p.point,
        name: p.place.name,
        color: p.color,
        face: face?.call(p),
        badge: p.content.frameCount,
        selected: selectedPlace == p.id && selectedSpot == null,
      ));
      continue;
    }
    labels.add(TripMapLabel(placeId: p.id, name: p.place.name, point: p.point, color: p.color));
    for (final s in p.content.spots) {
      final id = 'spot:${p.id}:${s.key}';
      targets[id] = (placeId: p.id, spotKey: s.key);
      pins.add(MapPin(
        id: id,
        point: s.point,
        name: s.label,
        color: p.color,
        done: p.content.isShot(s),
        estimated: s.estimated,
        selected: selectedPlace == p.id && selectedSpot == s.key,
      ));
    }
  }
  return TripMapMarkers(pins: pins, labels: labels, targets: targets);
}

/// [view]'s places for the map, each once, in list order, with their
/// section and its colour ([sectionColor]); only [dayId]'s when given.
List<TripMapPlace> tripMapPlaces(
  TripPlacesView view,
  Map<String, PlaceContent> contents,
  Color Function(PlacesSection section) colorOf, {
  String? dayId,
}) {
  final seen = <String>{};
  return [
    for (final s in view.sections)
      if (dayId == null || s.dayId == dayId)
        for (final p in s.places)
          if (contents[p.id] case final content? when seen.add(p.id))
            TripMapPlace(place: p, content: content, section: s, color: colorOf(s)),
  ];
}

/// The Places tab as a map: each place a pin with its first frame (or the
/// latest photo shot there) in its day's colour and its frame count; zoomed
/// in, the places part into their spots. Chips pick a day, which fits the
/// map to its places and draws its route in their order. Tapping a pin
/// shows a card with the place (or spot), its frames, Open place and Shoot
/// here; a crowd of pins zooming can't part lists them.
class TripMapView extends ConsumerStatefulWidget {
  final String tripId;
  final TripPlacesView view;
  final Map<String, PlaceContent> contents;

  /// The Places tab's, so the map shows where the user is; it's started
  /// when the map opens.
  final PositionFollower follower;

  const TripMapView({super.key, required this.tripId, required this.view, required this.contents, required this.follower});

  @override
  ConsumerState<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<TripMapView> {
  /// The day picked with the chips; null for all of them.
  String? _day;
  bool _spots = false;
  String? _place;
  String? _spot;

  /// The pins of a crowd that zooming in can't part.
  List<TripMapTarget>? _crowd;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    widget.follower.start();
  }

  void _onCamera(MapCamera camera, bool _) {
    final spots = camera.zoom >= spotPinZoom;
    if (spots == _spots) return;
    void apply() {
      if (mounted && spots != _spots) setState(() => _spots = spots);
    }

    // The map can report its camera while it's being laid out.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  void _select(TripMapTarget t) => setState(() {
        _place = t.placeId;
        _spot = t.spotKey;
        _crowd = null;
      });

  void _clear() {
    if (_place != null || _crowd != null) {
      setState(() {
        _place = null;
        _spot = null;
        _crowd = null;
      });
    }
  }

  void _open(TripMapPlace p) => context.push('/trips/${widget.tripId}/places/${p.id}');

  /// Opens the camera on [spot]'s frames, or the place's next spot to shoot.
  Future<void> _shoot(TripMapPlace p, PlaceSpot? spot) async {
    final content = p.content;
    final pos = widget.follower.position;
    final target = spot ?? nextToShoot(content, lat: pos?.latitude, lng: pos?.longitude)?.spot ?? content.spots.firstOrNull;
    if (target == null || _launching || !animeCameraSupported) return;
    final start = target.frames.indexWhere((f) => !content.shot.containsKey(f.id));
    _launching = true;
    widget.follower.pause();
    try {
      await shootWithFrames(
        context,
        ref,
        placeKey: target.stop.placeKey,
        tripId: widget.tripId,
        frames: target.frames,
        index: start < 0 ? 0 : start,
      );
    } finally {
      _launching = false;
      widget.follower.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final view = widget.view;
    Color colorOf(PlacesSection s) => sectionColor(theme, view, s);
    if (_day != null && !view.days.any((d) => d.dayId == _day)) _day = null;
    final places = tripMapPlaces(view, widget.contents, colorOf, dayId: _day);
    final byId = {for (final p in places) p.id: p};
    if (_place != null && !byId.containsKey(_place)) {
      _place = null;
      _spot = null;
    }
    final markers = tripMapMarkers(
      places,
      spots: _spots,
      selectedPlace: _place,
      selectedSpot: _spot,
      face: (p) => _PlaceFace(content: p.content),
    );
    final pos = widget.follower.position;
    final day = _day == null ? null : view.days.firstWhere((d) => d.dayId == _day);
    final route = [for (final p in places) p.point];

    Widget? card;
    if (_crowd case final crowd?) {
      card = _CrowdCard(
        targets: crowd,
        places: byId,
        onPick: _select,
        onClose: _clear,
      );
    } else if (_place case final id?) {
      final p = byId[id]!;
      final spot = _spot == null ? null : p.content.spots.where((s) => s.key == _spot).firstOrNull;
      card = _PlaceCard(
        key: ValueKey('mapCard-$id-${_spot ?? ''}'),
        place: p,
        spot: spot,
        lat: pos?.latitude,
        lng: pos?.longitude,
        onOpen: () => _open(p),
        onShoot: animeCameraSupported ? () => _shoot(p, spot) : null,
        onClose: _clear,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AppMap(
            key: const Key('tripMap'),
            pins: markers.pins,
            fitKey: _day ?? '',
            fitPadding: const EdgeInsets.fromLTRB(48, 72, 48, 48),
            center: places.firstOrNull?.point,
            nameUnderSelected: false,
            onPinTap: (pin) {
              final t = markers.targets[pin.id];
              if (t != null) _select(t);
            },
            onClusterOpen: (pins) => setState(() {
              _crowd = [for (final pin in pins) ?markers.targets[pin.id]];
              _place = null;
              _spot = null;
            }),
            onTap: (_) => _clear(),
            onPositionChanged: _onCamera,
            underPins: [
              if (day != null && route.length >= 2)
                PolylineLayer(
                  key: const Key('dayRoute'),
                  polylines: [
                    Polyline(
                      points: route,
                      color: colorOf(day).withValues(alpha: 0.75),
                      strokeWidth: 4,
                      pattern: StrokePattern.dashed(segments: const [9, 7]),
                    ),
                  ],
                ),
              if (markers.labels.isNotEmpty)
                IgnorePointer(
                  child: MarkerLayer(
                    markers: [
                      for (final label in markers.labels)
                        Marker(
                          key: ValueKey('label:${label.placeId}'),
                          point: label.point,
                          width: 200,
                          height: 26,
                          // Above the place's spot, out of its pins' way.
                          alignment: const Alignment(0, -2.4),
                          child: Center(child: _PlaceLabel(label: label)),
                        ),
                    ],
                  ),
                ),
            ],
            overPins: [
              if (pos != null)
                Marker(
                  key: const ValueKey('me'),
                  point: LatLng(pos.latitude, pos.longitude),
                  width: 20,
                  height: 20,
                  child: Semantics(
                    label: l10n.mapYourLocation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F7FD1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: const Color(0xFF2F7FD1).withValues(alpha: 0.22), spreadRadius: 7)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 8,
          child: SizedBox(
            height: 40,
            child: Semantics(
              label: l10n.mapDays,
              container: true,
              child: ListView(
                key: const Key('mapDayChips'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DayFilterChip(
                    key: const Key('mapDay-all'),
                    label: l10n.mapAllDays,
                    selected: _day == null,
                    onTap: () => setState(() {
                      _day = null;
                      _crowd = null;
                    }),
                  ),
                  for (final s in view.days)
                    _DayFilterChip(
                      key: ValueKey('mapDay-${s.dayId}'),
                      label: _dayChipLabel(context, s),
                      color: colorOf(s),
                      selected: _day == s.dayId,
                      onTap: () => setState(() {
                        _day = s.dayId;
                        _crowd = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (places.isEmpty)
          Center(
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.mapNoPlaces)),
            ),
          ),
        if (card != null) Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: card)),
      ],
    );
  }
}

/// "Jun 19 Uji", or just the name for a day without a date.
String _dayChipLabel(BuildContext context, PlacesSection s) {
  final title = sectionTitle(context, s);
  final date = s.day?.date;
  if (date == null) return title;
  return '${MaterialLocalizations.of(context).formatShortMonthDay(DateTime(date.year, date.month, date.day))} $title';
}

/// A place's picture on its pin: the latest photo shot there, else its first
/// frame.
class _PlaceFace extends StatelessWidget {
  final PlaceContent content;

  const _PlaceFace({required this.content});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).trip;
    final frame = content.firstFrame;
    final latest = content.latestShot;
    final empty = ColoredBox(color: p.wisteriaSoft, child: Icon(Icons.place_outlined, size: 18, color: p.wisteria));
    Widget frameImage() => frame == null ? empty : FrameImage(frame: frame, cacheWidth: 160);
    if (latest != null) {
      return PlatformImage(latest.localPath, fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, _, _) => frameImage());
    }
    return frameImage();
  }
}

class _PlaceLabel extends StatelessWidget {
  final TripMapLabel label;

  const _PlaceLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: label.color, width: 1.5),
      ),
      child: Text(
        label.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DayFilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _DayFilterChip({super.key, required this.label, this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          avatar: color == null ? null : Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          backgroundColor: Theme.of(context).colorScheme.surface,
          onSelected: (_) => onTap(),
        ),
      );
}

/// The card a rounded panel at the map's foot shows.
class _MapCard extends StatelessWidget {
  final Widget child;

  const _MapCard({required this.child});

  @override
  Widget build(BuildContext context) => Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );
}

/// The picked place, or one of its spots: its name, day, counts and
/// distance, a strip of its frames (the user's photo for a shot one), Open
/// place and Shoot here.
class _PlaceCard extends StatelessWidget {
  final TripMapPlace place;
  final PlaceSpot? spot;
  final double? lat;
  final double? lng;
  final VoidCallback onOpen;
  final VoidCallback? onShoot;
  final VoidCallback onClose;

  const _PlaceCard({
    super.key,
    required this.place,
    required this.spot,
    required this.lat,
    required this.lng,
    required this.onOpen,
    required this.onShoot,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final content = place.content;
    final spot = this.spot;
    final frames = spot?.frames ?? content.frames;
    final distance = spot == null
        ? content.distanceFrom(lat, lng)
        : (lat == null || lng == null ? null : metresBetween(lat!, lng!, spot.lat, spot.lng));
    final section = place.section;
    final date = sectionDate(context, section);
    final counts = [
      if (spot == null) l10n.placeSpotCount(content.spots.length),
      l10n.placeFrameCount(frames.length),
      if (distance != null) distanceText(distance),
    ].join(' · ');
    return _MapCard(
      child: Column(
        key: const Key('mapPlaceCard'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: place.place.name),
                        if (spot != null)
                          TextSpan(text: ' › ${spot.label}', style: TextStyle(color: muted, fontWeight: FontWeight.w500)),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: date == null ? sectionTitle(context, section) : '${sectionTitle(context, section)} · $date',
                          style: TextStyle(color: place.color, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' · $counts', style: TextStyle(color: muted)),
                      ]),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: l10n.mapClose, onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          if (frames.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: ListView.separated(
                key: const Key('mapFrameStrip'),
                scrollDirection: Axis.horizontal,
                itemCount: frames.length > 12 ? 12 : frames.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => FrameCell(
                  frame: frames[i],
                  photo: content.shot[frames[i].id],
                  width: 104,
                  height: 58,
                  onTap: onOpen,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(key: const Key('mapOpenPlace'), onPressed: onOpen, child: Text(l10n.mapOpenPlace)),
              ),
              if (onShoot != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('mapShootHere'),
                    onPressed: onShoot,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.mapShootHere),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Pins too close to part, as a list to pick from.
class _CrowdCard extends StatelessWidget {
  final List<TripMapTarget> targets;
  final Map<String, TripMapPlace> places;
  final ValueChanged<TripMapTarget> onPick;
  final VoidCallback onClose;

  const _CrowdCard({required this.targets, required this.places, required this.onPick, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final placeCount = {for (final t in targets) t.placeId}.length;
    final spotsOnly = targets.every((t) => t.spotKey != null);
    return _MapCard(
      child: Column(
        key: const Key('mapCrowdCard'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spotsOnly ? l10n.placeSpotCount(targets.length) : l10n.mapPlaceCount(placeCount),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(l10n.mapCrowded, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ],
                ),
              ),
              IconButton(tooltip: l10n.mapClose, onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in targets)
                  if (places[t.placeId] case final p?) _crowdRow(context, t, p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _crowdRow(BuildContext context, TripMapTarget t, TripMapPlace p) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spot = t.spotKey == null ? null : p.content.spots.where((s) => s.key == t.spotKey).firstOrNull;
    final frames = spot?.frames ?? p.content.frames;
    final frame = frames.firstOrNull;
    return InkWell(
      key: ValueKey('crowd-${t.placeId}-${t.spotKey ?? ''}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => onPick(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            FrameCell(frame: frame, photo: frame == null ? null : p.content.shot[frame.id], width: 64, height: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot == null ? p.place.name : '${p.place.name} › ${spot.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [if (spot == null) l10n.placeSpotCount(p.content.spots.length), l10n.placeFrameCount(frames.length)].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
