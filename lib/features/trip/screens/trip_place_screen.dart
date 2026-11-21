import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/up_button.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../library/widgets/place_page_parts.dart';
import '../models/place_spots.dart';
import '../models/stop_group.dart';
import '../providers/trip_place_providers.dart';
import '../providers/trip_providers.dart';
import '../providers/trip_stop_providers.dart';

/// A place of a trip: a stop, its frames grouped into spots (where in the
/// place each is shot from), shown on a small map and in a list nearest
/// first, each spot with its frames and the user's photos of them. A group
/// of stops not folded into one yet shows as one place too, each stop's
/// frames as its spots. Reached by any of its stops, and a stop folded into
/// another opens the one it went into.
class TripPlaceScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String stopId;

  const TripPlaceScreen({super.key, required this.tripId, required this.stopId});

  @override
  ConsumerState<TripPlaceScreen> createState() => _TripPlaceScreenState();
}

/// What the place's page knows about one spot.
class _Spot {
  final PlaceSpot spot;
  final Map<String, Photo> shot;

  /// The user's photos at the spot's stop's place, for a spot without frames.
  final List<Photo> photos;

  const _Spot({required this.spot, required this.shot, required this.photos});

  String get key => spot.key;
  Stop get stop => spot.stop;
  String get label => spot.label;
  List<NewReferenceImage> get frames => spot.frames;

  bool get isShot => spotShot(shown: frames, shot: shot, photos: photos);
}

class _TripPlaceScreenState extends ConsumerState<TripPlaceScreen> with WidgetsBindingObserver {
  final _map = MapController();
  Position? _position;
  StreamSubscription<Position>? _positionSub;
  bool _onlyUnshot = false;
  String? _selected;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLocation();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopLocation();
    }
  }

  void _stopLocation() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Follows the user's position when the device allows it; the page works
  /// without it, in list order.
  Future<void> _startLocation() async {
    if (_positionSub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) setState(() => _position = last);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen(
        (pos) {
          if (mounted) setState(() => _position = pos);
        },
        onError: (_) {},
      );
    } catch (_) {
      // No geolocation here (desktop, tests): the list stays in its order.
    }
  }

  Future<void> _shoot(_Spot spot, int index) async {
    if (_launching || !animeCameraSupported) return;
    _launching = true;
    _stopLocation();
    try {
      await shootWithFrames(context, ref, placeKey: spot.stop.placeKey, tripId: widget.tripId, frames: spot.frames, index: index);
    } finally {
      _launching = false;
      if (mounted) _startLocation();
    }
  }

  void _openStop(Stop stop) => context.push('/trips/${widget.tripId}/stops/${stop.id}');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final entries = ref.watch(tripStopEntriesProvider(widget.tripId));
    var members = placeEntries(entries.valueOrNull ?? const [], widget.stopId);
    if (members.isEmpty) {
      // Folded into another stop (here or on another member's phone).
      final into = ref.watch(stopDetailProvider(widget.stopId)).valueOrNull?.mergedInto;
      if (into != null) members = placeEntries(entries.valueOrNull ?? const [], into);
    }
    final group = members.isEmpty ? null : stopGroup(members.first.stop);
    final l10n = context.l10n;
    final title = group ?? (members.isEmpty ? l10n.placeTitleFallback : members.single.stop.name);

    Widget scaffold(Widget body, {String? subtitle}) => Scaffold(
          appBar: AppBar(
            leading: UpButton.ifAlone(context, fallback: '/trips/${widget.tripId}'),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            actions: [
              if (members.length == 1)
                IconButton(
                  key: const Key('placeDetails'),
                  tooltip: l10n.placeDetails,
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _openStop(members.single.stop),
                ),
            ],
          ),
          body: body,
        );

    if (entries.isLoading && !entries.hasValue) return scaffold(const Center(child: CircularProgressIndicator()));
    if (members.isEmpty) return scaffold(Center(child: Text(l10n.placeGone)));

    final own = ref.watch(tripFramesProvider(widget.tripId)).valueOrNull ?? const <NewReferenceImage>[];
    final library = ref.watch(tripLibraryFramesProvider(widget.tripId)).valueOrNull ?? const <NewReferenceImage>[];
    final photos = ref.watch(tripPhotosProvider(widget.tripId)).valueOrNull ?? const <Photo>[];
    final ownByStop = <String, List<NewReferenceImage>>{};
    for (final f in own) {
      if (f.stopId case final id?) ownByStop.putIfAbsent(id, () => []).add(f);
    }
    final libraryByPlace = <String, List<NewReferenceImage>>{};
    for (final f in library) {
      if (f.placeKey case final key?) libraryByPlace.putIfAbsent(key, () => []).add(f);
    }
    final all = [...own, ...library];
    final spots = [
      for (final spot in placeSpots(
        stops: [for (final e in members) e.stop],
        group: group,
        framesOf: (stop) => placeFramesOf(own: ownByStop[stop.id] ?? const [], library: libraryByPlace[stop.placeKey] ?? const []),
      ))
        _Spot(
          spot: spot,
          shot: shotFrames(shown: spot.frames, all: all, photos: photos),
          photos: [for (final ph in photos) if (ph.placeKey == spot.stop.placeKey) ph],
        ),
    ];
    final shotCount = spots.where((s) => s.isShot).length;
    final unshot = spots.length - shotCount;
    final pos = _position;
    var shown = byDistance(spots, (s) => s.spot.point, lat: pos?.latitude, lng: pos?.longitude);
    if (_onlyUnshot) shown = [for (final s in shown) if (!s.isShot) s];
    if (_selected != null) {
      final sel = shown.where((s) => s.key == _selected).firstOrNull;
      if (sel != null) shown = [sel, for (final s in shown) if (s != sel) s];
    }

    final subtitle = '${l10n.placeSpotCount(spots.length)} · ${l10n.placeShotCount(shotCount)}';
    return scaffold(
      subtitle: subtitle,
      Column(
        children: [
          SizedBox(
            height: 220,
            child: AppMap(
              key: const Key('placeMap'),
              controller: _map,
              fitMaxZoom: 19,
              fitPadding: const EdgeInsets.all(40),
              nameUnderSelected: true,
              pins: [
                for (final s in spots)
                  MapPin(
                    id: s.key,
                    point: s.spot.point,
                    name: s.label,
                    color: p.tea,
                    done: s.isShot,
                    selected: s.key == _selected,
                  ),
              ],
              center: spots.first.spot.point,
              onPinTap: (pin) => setState(() => _selected = _selected == pin.id ? null : pin.id),
              onTap: (_) {
                if (_selected != null) setState(() => _selected = null);
              },
              overPins: [
                if (pos != null)
                  Marker(
                    key: const ValueKey('me'),
                    point: LatLng(pos.latitude, pos.longitude),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F7FD1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: const Color(0xFF2F7FD1).withValues(alpha: 0.3), spreadRadius: 5)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.placeFilterAll(spots.length)),
                  selected: !_onlyUnshot,
                  onSelected: (_) => setState(() => _onlyUnshot = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('placeUnshotChip'),
                  label: Text(l10n.placeFilterNotShot(unshot)),
                  selected: _onlyUnshot,
                  onSelected: (_) => setState(() => _onlyUnshot = true),
                ),
                const Spacer(),
                if (pos != null)
                  Text(l10n.placeNearestFirst, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(_onlyUnshot ? l10n.placeAllShot : l10n.placeNoSpots))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final s = shown[i];
                      final metres = pos == null ? null : metresBetween(pos.latitude, pos.longitude, s.spot.lat, s.spot.lng);
                      return _SpotTile(
                        key: ValueKey('spot-${s.key}'),
                        spot: s,
                        selected: s.key == _selected,
                        // A spot placed only by its stop is about there.
                        distance: metres == null ? null : '${s.spot.estimated ? '~' : ''}${distanceText(metres)}',
                        onOpen: () => _openStop(s.stop),
                        onFrame: animeCameraSupported ? (index) => _shoot(s, index) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A spot in the place's list: its note or short name, how far it is, and a
/// strip of its frames, each replaced by the user's photo once shot.
class _SpotTile extends StatelessWidget {
  final _Spot spot;
  final bool selected;
  final String? distance;
  final VoidCallback onOpen;

  /// Opens the camera on a frame; null where there's no camera.
  final ValueChanged<int>? onFrame;

  const _SpotTile({super.key, required this.spot, required this.selected, required this.distance, required this.onOpen, required this.onFrame});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final l10n = context.l10n;
    final status = spot.isShot ? l10n.placeSpotShot : l10n.placeSpotNotShot;
    final line = [?distance, status, if (spot.frames.isNotEmpty) l10n.placeFrameCount(spot.frames.length)].join(' · ');
    return Material(
      color: selected ? p.teaSoft : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: spot.isShot ? p.tea : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (spot.frames.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: spot.frames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final frame = spot.frames[i];
                      final photo = spot.shot[frame.id];
                      return _FrameCell(
                        frame: frame,
                        photo: photo,
                        onTap: onFrame == null ? null : () => onFrame!(i),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One frame of a spot, or the user's photo of it once shot, with the frame
/// small in the corner so the two can be compared.
class _FrameCell extends StatelessWidget {
  final NewReferenceImage frame;
  final Photo? photo;
  final VoidCallback? onTap;

  const _FrameCell({required this.frame, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shot = photo;
    return Semantics(
      button: onTap != null,
      label: shot == null ? context.l10n.placeFrameNotShotLabel : context.l10n.placeFrameShotLabel,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 106,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (shot == null)
                  FrameImage(frame: frame, cacheWidth: 320)
                else
                  PlatformImage(
                    shot.localPath,
                    fit: BoxFit.cover,
                    cacheWidth: 320,
                    errorBuilder: (_, _, _) => FrameImage(frame: frame, cacheWidth: 320),
                  ),
                if (shot != null)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    width: 36,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(3)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: FrameImage(frame: frame, cacheWidth: 120)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
