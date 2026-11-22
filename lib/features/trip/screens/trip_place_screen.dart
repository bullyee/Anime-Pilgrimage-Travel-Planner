import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/up_button.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../camera/services/photo_edit_route.dart';
import '../../camera/services/picked_shot.dart';
import '../../library/models/frames.dart' show frameCaption;
import '../../library/widgets/place_page_parts.dart';
import '../../planner/controllers/day_planner_controller.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/planner_sheets.dart' show reportResult;
import '../../sharing/providers/group_sharing_providers.dart';
import '../controllers/trip_stops_controller.dart';
import '../models/place_spots.dart';
import '../models/stop_group.dart';
import '../models/trip_places_view.dart';
import '../providers/trip_place_providers.dart';
import '../providers/trip_providers.dart';
import '../providers/trip_stop_providers.dart';
import '../widgets/position_follower.dart';

/// How near a spot is to count as Nearby, in metres.
const nearbyMetres = 60.0;

/// A place of a trip: its frames in a carousel, the day it's on, its spots
/// (where in the place each frame is shot from) on a small map and in a
/// list, each with its frames or the user's photos of them, and the trip's
/// note on it. Start shooting goes through the frames not shot yet, nearest
/// spot first. People who can edit the trip move it to another day, name and
/// place its spots and write the note; viewers see the same without the
/// controls.
///
/// A group of stops not folded into one yet shows as one place too, each
/// stop's frames as its spots. Reached by any of its stops, and a stop
/// folded into another opens the one it went into.
class TripPlaceScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String stopId;

  const TripPlaceScreen({super.key, required this.tripId, required this.stopId});

  @override
  ConsumerState<TripPlaceScreen> createState() => _TripPlaceScreenState();
}

enum _Filter { all, unshot, nearby }

class _TripPlaceScreenState extends ConsumerState<TripPlaceScreen> {
  final _map = MapController();
  final _follower = PositionFollower();
  final _heroPages = PageController();
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  late final TripStopsController _stops = ref.read(tripStopsControllerProvider.notifier);

  _Filter _filter = _Filter.all;
  String? _selected;

  /// The spot being placed with the crosshair.
  String? _placing;
  int _hero = 0;
  bool _launching = false;

  /// The place's shot count when the camera last opened; a higher count
  /// since offers the next frame.
  int? _shotBefore;

  Timer? _noteSave;
  String? _noteStopId;

  /// The note as last saved or loaded.
  String? _noteSaved;

  @override
  void initState() {
    super.initState();
    _follower.addListener(_onPosition);
    _follower.start();
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _saveNote();
    });
  }

  @override
  void dispose() {
    _saveNote();
    _follower.removeListener(_onPosition);
    _follower.dispose();
    _heroPages.dispose();
    _note.dispose();
    _noteFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onPosition() {
    if (mounted) setState(() {});
  }

  void _onNoteChanged(String _) {
    _noteSave?.cancel();
    _noteSave = Timer(const Duration(milliseconds: 800), _saveNote);
  }

  void _saveNote() {
    _noteSave?.cancel();
    _noteSave = null;
    final stopId = _noteStopId;
    if (stopId == null) return;
    final text = _note.text;
    if (text.trim() == (_noteSaved ?? '').trim()) return;
    _noteSaved = text;
    _stops.setNote(stopId, text);
  }

  /// Shows [stop]'s note in the field, unless the user is typing in it.
  void _loadNote(Stop stop) {
    final remote = stop.note ?? '';
    if (_noteStopId == stop.id && (remote == (_noteSaved ?? '') || _noteFocus.hasFocus || _noteSave != null)) return;
    _noteStopId = stop.id;
    _noteSaved = remote;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _note.text != remote) _note.text = remote;
    });
  }

  void _report(AppResult<dynamic> result, String ok) => reportResult(context, result, ok: ok);

  Future<void> _shoot(String placeKey, List<NewReferenceImage> frames, int index, int shotNow) async {
    if (_launching || !animeCameraSupported) return;
    _launching = true;
    _follower.pause();
    try {
      await shootWithFrames(context, ref, placeKey: placeKey, tripId: widget.tripId, frames: frames, index: index);
    } finally {
      _launching = false;
      _follower.resume();
      if (mounted) setState(() => _shotBefore = shotNow);
    }
  }

  void _openStop(Stop stop) => context.push('/trips/${widget.tripId}/stops/${stop.id}');

  void _select(PlaceSpot spot) {
    setState(() => _selected = _selected == spot.key ? null : spot.key);
    if (_selected == null) return;
    try {
      _map.move(spot.point, math.max(_map.camera.zoom, 17));
    } catch (_) {
      // The map isn't laid out yet.
    }
  }

  /// A frame full screen, with Take photo, and the user's photo of it.
  Future<void> _openFrame(PlaceContent place, PlaceSpot spot, int index) async {
    final l10n = context.l10n;
    final frame = spot.frames[index];
    final photo = place.shot[frame.id];
    final path = await framePath(ref, frame);
    if (!mounted) return;
    void shoot() => _shoot(spot.stop.placeKey, spot.frames, index, place.shotCount);
    if (path == null) {
      shoot();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (viewerContext) => ImageViewer(
        path: path,
        title: frameCaption(frame) ?? spot.label,
        actions: [
          if (photo != null)
            ViewerAction(l10n.placeCompare, () {
              Navigator.pop(viewerContext);
              context.push('/photo/${photo.id}');
            }),
          ViewerAction(l10n.placePickFromGallery, () {
            Navigator.pop(viewerContext);
            _pickFromGallery(spot.stop.placeKey, frame);
          }),
          if (animeCameraSupported)
            ViewerAction(l10n.placeTakePhoto, () {
              Navigator.pop(viewerContext);
              shoot();
            }, primary: true),
        ],
      ),
    ));
  }

  /// A photo from the gallery as the user's shot of [frame], so it counts
  /// as shot: saved as the camera's kept shots are ([recordPickedShot]),
  /// without editing. The web keeps no files, so there it goes to the
  /// editor with the frame, whose save files it the same way.
  Future<void> _pickFromGallery(String placeKey, NewReferenceImage frame) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placePickFailed(e.message ?? e.code))));
      return;
    }
    if (picked == null || !mounted) return;
    if (kIsWeb) {
      final reference = await framePath(ref, frame);
      router.push(PhotoEditArgs(
        path: picked.path,
        placeKey: placeKey,
        tripId: widget.tripId,
        referencePath: reference,
        referenceImageId: reference == null ? null : frame.id,
      ).location);
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!await isReadableImage(bytes)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placePickEmpty)));
      return;
    }
    try {
      final result = await recordPickedShot(
        ref.read(databaseProvider),
        path: picked.path,
        bytes: bytes,
        placeKey: placeKey,
        tripId: widget.tripId,
        frameId: frame.id,
      );
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.placePickedSaved),
        persist: false,
        action: SnackBarAction(label: l10n.placeCompare, onPressed: () => router.push('/photo/${result.photo.id}')),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placePickFailed('$e'))));
    }
  }

  Future<void> _moveSheet(TripPlacesView view, TripPlace place, PlacesSection from) async {
    final l10n = context.l10n;
    final to = await showModalBottomSheet<PlacesSection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l10n.placeMoveTitle(place.name), style: theme.textTheme.titleLarge),
                ),
                for (final s in view.sections)
                  ListTile(
                    key: ValueKey('moveTo-${s.dayId ?? 'unsorted'}'),
                    leading: _DayDot(color: sectionColor(theme, view, s)),
                    title: Text(sectionTitle(sheetContext, s)),
                    subtitle: Text([
                      if (!s.isUnsorted) sectionDate(sheetContext, s) ?? l10n.placeNoDate,
                      l10n.placeCountInDay(s.places.length),
                    ].join(' · ')),
                    trailing: s.dayId == from.dayId ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheetContext, s),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (to == null || to.dayId == from.dayId || !mounted) return;
    final planner = ref.read(dayPlannerControllerProvider.notifier);
    final AppResult<void> result;
    if (to.isUnsorted) {
      result = await planner.unscheduleItems(place.itemIds);
    } else if (from.isUnsorted) {
      result = await planner.scheduleStops(tripId: widget.tripId, stopIds: [for (final s in place.stops) s.id], dayId: to.dayId!);
    } else {
      result = await planner.moveItems(itemIds: place.itemIds, toDayId: to.dayId!);
    }
    if (mounted) _report(result, l10n.placeMovedTo(sectionTitle(context, to)));
  }

  Future<void> _spotSheet(PlaceContent place, PlaceSpot spot) async {
    final initial = spot.frames.map((f) => f.note?.trim() ?? '').firstWhere((n) => n.isNotEmpty, orElse: () => '');
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SpotSheet(spot: spot, note: initial, canShoot: animeCameraSupported && place.hasUnshot(spot)),
    );
    if (picked == null) return;
    final (action, text) = picked;
    if (!mounted) return;
    switch (action) {
      case 'note':
        final result = await _stops.setFrameNote(spot.frames, text);
        if (result is Failure && mounted) _report(result, '');
      case 'place':
        setState(() {
          _placing = spot.key;
          _selected = spot.key;
        });
        try {
          _map.move(spot.point, math.max(_map.camera.zoom, 18));
        } catch (_) {}
      case 'shoot':
        final frames = [for (final f in spot.frames) if (!place.shot.containsKey(f.id)) f];
        await _shoot(spot.stop.placeKey, frames, 0, place.shotCount);
    }
  }

  Future<void> _setHere(PlaceSpot spot) async {
    final l10n = context.l10n;
    final center = _map.camera.center;
    final result = await _stops.setFrameShot(spot.frames, lat: center.latitude, lng: center.longitude);
    if (!mounted) return;
    setState(() => _placing = null);
    _report(result, l10n.placePositionSaved);
  }

  Future<void> _merge(TripPlacesView view, Stop stop) async {
    final l10n = context.l10n;
    final others = [for (final p in view.all) if (p.group == null && p.stop.id != stop.id) p];
    final other = await showModalBottomSheet<TripPlace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(l10n.placeMergePick(stop.name), style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              for (final p in others)
                ListTile(title: Text(p.name), subtitle: p.stop.address == null ? null : Text(p.stop.address!), onTap: () => Navigator.pop(sheetContext, p)),
            ],
          ),
        ),
      ),
    );
    if (other == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.placeMergeConfirm(other.name, stop.name)),
        content: Text(l10n.placeMergeBody(other.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.placeCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.placeMergeAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _stops.mergeStops(keepId: stop.id, stopIds: [stop.id, other.stop.id]);
    if (mounted) _report(result, l10n.placeMerged(other.name));
  }

  void _openInMaps(double lat, double lng) =>
      launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(tripStopEntriesProvider(widget.tripId));
    var members = placeEntries(entries.valueOrNull ?? const [], widget.stopId);
    if (members.isEmpty) {
      // Folded into another stop (here or on another member's phone).
      final into = ref.watch(stopDetailProvider(widget.stopId)).valueOrNull?.mergedInto;
      if (into != null) members = placeEntries(entries.valueOrNull ?? const [], into);
    }
    Widget bare(Widget body) => Scaffold(
          appBar: AppBar(leading: UpButton.ifAlone(context, fallback: '/trips/${widget.tripId}'), title: Text(l10n.placeTitleFallback)),
          body: body,
        );
    if (entries.isLoading && !entries.hasValue) return bare(const Center(child: CircularProgressIndicator()));
    if (members.isEmpty) return bare(Center(child: Text(l10n.placeGone)));

    final stops = [for (final e in members) e.stop];
    final anchor = stops.first;
    final group = stopGroup(anchor);
    final title = group ?? anchor.name;
    final index = TripFrameIndex(
      own: ref.watch(tripFramesProvider(widget.tripId)).valueOrNull ?? const [],
      library: ref.watch(tripLibraryFramesProvider(widget.tripId)).valueOrNull ?? const [],
      photos: ref.watch(tripPhotosProvider(widget.tripId)).valueOrNull ?? const [],
    );
    final place = index.place(stops, group: group);
    final canEdit = ref.watch(canEditTripProvider(widget.tripId));
    final planner = ref.watch(plannerViewProvider(widget.tripId)).valueOrNull;
    final view = planner == null ? null : buildTripPlacesView(planner);
    final section = view?.sectionOf(anchor.id);
    final tripPlace = section?.places.firstWhere((p) => p.stops.any((s) => s.id == anchor.id));
    final labels = [
      for (final l in ref.watch(stopLabelsProvider(anchor.id)).valueOrNull ?? const <Label>[])
        if (l.kind == 'anime') l,
    ];
    if (stops.length == 1) _loadNote(anchor);

    final pos = _follower.position;
    final lat = pos?.latitude;
    final lng = pos?.longitude;
    double? metresTo(PlaceSpot s) => lat == null || lng == null ? null : metresBetween(lat, lng, s.lat, s.lng);
    final frames = place.frames;
    if (_hero >= frames.length) _hero = math.max(0, frames.length - 1);

    final ordered = byDistance(place.spots, (s) => s.point, lat: lat, lng: lng);
    final unshotSpots = place.spots.where(place.hasUnshot).length;
    final nearby = place.spots.where((s) => (metresTo(s) ?? double.infinity) <= nearbyMetres).length;
    var shown = switch (_filter) {
      _Filter.all => ordered,
      _Filter.unshot => [for (final s in ordered) if (place.hasUnshot(s)) s],
      _Filter.nearby => [for (final s in ordered) if ((metresTo(s) ?? double.infinity) <= nearbyMetres) s],
    };
    if (_selected case final key?) {
      final sel = shown.where((s) => s.key == key).firstOrNull;
      if (sel != null) shown = [sel, for (final s in shown) if (s != sel) s];
    }
    final placing = _placing == null ? null : place.spots.where((s) => s.key == _placing).firstOrNull;
    final next = _shotBefore != null && place.shotCount > _shotBefore! ? nextToShoot(place, lat: lat, lng: lng) : null;
    final queue = shootingQueue(place, lat: lat, lng: lng);

    final theme = Theme.of(context);
    final p = theme.trip;
    final muted = theme.colorScheme.onSurfaceVariant;
    final distance = place.distanceFrom(lat, lng);

    final hero = _Hero(
      frames: frames,
      index: _hero,
      controller: _heroPages,
      captionOf: (f) => frameCaption(f) ?? place.spots.firstWhere((s) => s.frames.contains(f)).label,
      onPage: (i) => setState(() => _hero = i),
      onOpen: (i) {
        final f = frames[i];
        final spot = place.spots.firstWhere((s) => s.frames.contains(f));
        _openFrame(place, spot, spot.frames.indexOf(f));
      },
      back: () => goUp(context, '/trips/${widget.tripId}'),
      menu: PopupMenuButton<String>(
        key: const Key('placeMenu'),
        tooltip: l10n.placeMenu,
        icon: const Icon(Icons.more_vert, color: Colors.white),
        style: IconButton.styleFrom(backgroundColor: Colors.black38),
        onSelected: (v) {
          if (v == 'details') _openStop(anchor);
          if (v == 'maps') _openInMaps(anchor.lat, anchor.lng);
          if (v == 'merge' && view != null) _merge(view, anchor);
        },
        itemBuilder: (_) => [
          if (stops.length == 1) PopupMenuItem(key: const Key('placeDetails'), value: 'details', child: Text(l10n.placeDetails)),
          PopupMenuItem(value: 'maps', child: Text(l10n.placeOpenInMaps)),
          if (canEdit && stops.length == 1 && view != null && view.all.length > 1)
            PopupMenuItem(key: const Key('placeMerge'), value: 'merge', child: Text(l10n.placeMerge)),
        ],
      ),
    );

    final header = Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (section != null && view != null && tripPlace != null)
                _DayChip(
                  section: section,
                  color: sectionColor(theme, view, section),
                  onTap: canEdit ? () => _moveSheet(view, tripPlace, section) : null,
                ),
              for (final l in labels)
                Chip(
                  label: Text(l.name),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: p.wisteriaSoft,
                  side: BorderSide.none,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(color: p.wisteria),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            key: const Key('placeMeta'),
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              children: [
                TextSpan(text: '${l10n.placeSpotCount(place.spots.length)} · ${l10n.placeFrameCount(place.frameCount)}'),
                if (place.shotCount > 0) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(text: l10n.placeShotCount(place.shotCount), style: TextStyle(color: p.tea, fontWeight: FontWeight.w700)),
                ],
                if (distance != null) TextSpan(text: ' · ${l10n.placeDistanceAway(distanceText(distance))}'),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => _openInMaps(anchor.lat, anchor.lng),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l10n.placeOpenInMaps),
            ),
          ),
        ],
      ),
    );

    final map = SizedBox(
      height: 230,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            AppMap(
              key: const Key('placeMap'),
              controller: _map,
              fitMaxZoom: 19,
              fitPadding: const EdgeInsets.all(40),
              nameUnderSelected: true,
              pins: [
                for (final s in place.spots)
                  MapPin(
                    id: s.key,
                    point: s.point,
                    name: s.label,
                    color: p.tea,
                    done: place.isShot(s),
                    estimated: s.estimated,
                    selected: s.key == _selected,
                  ),
              ],
              center: place.spots.firstOrNull?.point ?? LatLng(anchor.lat, anchor.lng),
              onPinTap: placing != null
                  ? null
                  : (pin) {
                      final s = place.spots.where((x) => x.key == pin.id).firstOrNull;
                      if (s != null) setState(() => _selected = _selected == s.key ? null : s.key);
                    },
              onTap: (_) {
                if (_selected != null && placing == null) setState(() => _selected = null);
              },
              overPins: [
                if (lat != null && lng != null)
                  Marker(
                    key: const ValueKey('me'),
                    point: LatLng(lat, lng),
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
            if (placing != null)
              IgnorePointer(child: Center(child: Icon(Icons.gps_not_fixed, size: 36, color: p.vermilion))),
          ],
        ),
      ),
    );

    Widget chip(_Filter f, String label, {Key? key}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(key: key, label: Text(label), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
        );

    final spotsSection = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: l10n.placeSpotsHeading, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            TextSpan(text: '  ${l10n.placeSpotsHint}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ])),
          const SizedBox(height: 10),
          map,
          if (placing != null)
            Container(
              key: const Key('placingBanner'),
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(color: p.vermilionSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.placePlacing(placing.label), style: theme.textTheme.bodySmall?.copyWith(color: p.vermilion))),
                  TextButton(onPressed: () => setState(() => _placing = null), child: Text(l10n.placeCancel)),
                  FilledButton(key: const Key('placeSetHere'), onPressed: () => _setHere(placing), child: Text(l10n.placeSetHere)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(_Filter.all, l10n.placeFilterAll(place.spots.length)),
                chip(_Filter.unshot, l10n.placeFilterNotShot(unshotSpots), key: const Key('placeUnshotChip')),
                if (lat != null) chip(_Filter.nearby, l10n.placeFilterNearby(nearby), key: const Key('placeNearbyChip')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                switch (_filter) {
                  _Filter.unshot => l10n.placeAllShot,
                  _Filter.nearby => l10n.placeNoneNearby,
                  _Filter.all => l10n.placeNoSpots,
                },
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
          for (final s in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SpotCard(
                key: ValueKey('spot-${s.key}'),
                spot: s,
                place: place,
                selected: s.key == _selected,
                way: () {
                  final m = metresTo(s);
                  if (m == null) return null;
                  final dir = l10n.placeCompass(compassTo(lat!, lng!, s.lat, s.lng).name);
                  return l10n.placeSpotWay(dir, '${s.estimated ? '~' : ''}${distanceText(m)}');
                }(),
                onSelect: () => _select(s),
                onMenu: canEdit && s.frames.isNotEmpty ? () => _spotSheet(place, s) : null,
                onFrame: (i) => _openFrame(place, s, i),
              ),
            ),
        ],
      ),
    );

    final notes = stops.length != 1 || (!canEdit && (anchor.note?.trim().isEmpty ?? true))
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.placeNotesHeading, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (canEdit)
                  TextField(
                    key: const Key('placeNotes'),
                    controller: _note,
                    focusNode: _noteFocus,
                    minLines: 3,
                    maxLines: 10,
                    maxLength: maxTripNoteLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: l10n.placeNotesHint),
                    onChanged: _onNoteChanged,
                  )
                else
                  Text(anchor.note!.trim(), key: const Key('placeNotesText'), style: theme.textTheme.bodyMedium),
              ],
            ),
          );

    final bottom = <Widget>[
      if (next != null)
        _NextCard(
          label: next.metres == null
              ? l10n.placeNextHere(next.spot.label)
              : l10n.placeNext(next.spot.label, '${next.spot.estimated ? '~' : ''}${distanceText(next.metres!)}'),
          frame: next.frame,
          onShoot: animeCameraSupported ? () => _shoot(next.spot.stop.placeKey, queue, 0, place.shotCount) : null,
          onClose: () => setState(() => _shotBefore = null),
        ),
      if (queue.isNotEmpty && animeCameraSupported)
        FilledButton.icon(
          key: const Key('placeStartShooting'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => _shoot(anchor.placeKey, queue, 0, place.shotCount),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.placeStartShooting(queue.length)),
        )
      else if (queue.isEmpty && place.frameCount > 0)
        FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => context.go('/photos'),
          child: Text(l10n.placeSeePhotos),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const Key('placePage'),
              padding: const EdgeInsets.only(bottom: 32),
              children: [hero, header, spotsSection, notes],
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottom.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: bottom,
                ),
              ),
            ),
    );
  }
}

/// A spot's options: its note, its position, and shooting it. Pops with
/// the action ('note', 'place' or 'shoot') and the note typed.
class _SpotSheet extends StatefulWidget {
  final PlaceSpot spot;
  final String note;
  final bool canShoot;

  const _SpotSheet({required this.spot, required this.note, required this.canShoot});

  @override
  State<_SpotSheet> createState() => _SpotSheetState();
}

class _SpotSheetState extends State<_SpotSheet> {
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pop(String action) => Navigator.pop(context, (action, _note.text));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.spot.label, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                key: const Key('spotNoteField'),
                controller: _note,
                maxLength: maxFrameNoteLength,
                decoration: InputDecoration(labelText: l10n.placeSpotNoteLabel, hintText: l10n.placeSpotNoteHint),
                onSubmitted: (_) => _pop('note'),
              ),
              FilledButton.tonal(key: const Key('spotNoteSave'), onPressed: () => _pop('note'), child: Text(l10n.placeSaveNote)),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('spotSetPosition'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location),
                title: Text(l10n.placeSetPosition),
                subtitle: widget.spot.estimated ? Text(l10n.placeSetPositionEstimated) : null,
                onTap: () => _pop('place'),
              ),
              if (widget.canShoot)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(l10n.placeShootSpot),
                  onTap: () => _pop('shoot'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's name: the day's title, else "Day 3"; Unsorted for the
/// places on no day.
String sectionTitle(BuildContext context, PlacesSection s) {
  final l10n = context.l10n;
  final day = s.day;
  if (day == null) return l10n.placeDayUnsorted;
  return dayTitleOf(day) ?? l10n.placeDayN(day.index + 1);
}

/// A section's date, as the locale writes it ("Fri, Jun 19"), when it has one.
String? sectionDate(BuildContext context, PlacesSection s) {
  final date = s.day?.date;
  if (date == null) return null;
  return MaterialLocalizations.of(context).formatMediumDate(DateTime(date.year, date.month, date.day));
}

/// The dot that marks a section: its day's colour ([dayColors]), slate for
/// Unsorted.
class _DayDot extends StatelessWidget {
  final Color color;

  const _DayDot({required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// The place's day, which opens the sheet to move it for people who can.
class _DayChip extends StatelessWidget {
  final PlacesSection section;
  final Color color;
  final VoidCallback? onTap;

  const _DayChip({required this.section, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = sectionDate(context, section);
    final name = sectionTitle(context, section);
    final text = date == null ? name : '$name · $date';
    final label = Text(text);
    final dot = _DayDot(color: color);
    return Semantics(
      label: context.l10n.placeDayChip(text),
      excludeSemantics: true,
      button: onTap != null,
      child: onTap == null
          ? Chip(key: const Key('placeDayChip'), avatar: dot, label: label, visualDensity: VisualDensity.compact)
          : ActionChip(
              key: const Key('placeDayChip'),
              avatar: dot,
              label: Row(mainAxisSize: MainAxisSize.min, children: [label, const Icon(Icons.arrow_drop_down, size: 18)]),
              visualDensity: VisualDensity.compact,
              onPressed: onTap,
            ),
    );
  }
}

/// The place's frames, one at a time, with a back button and the menu.
class _Hero extends StatelessWidget {
  final List<NewReferenceImage> frames;
  final int index;
  final PageController controller;
  final String Function(NewReferenceImage frame) captionOf;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onOpen;
  final VoidCallback back;
  final Widget menu;

  const _Hero({
    required this.frames,
    required this.index,
    required this.controller,
    required this.captionOf,
    required this.onPage,
    required this.onOpen,
    required this.back,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final l10n = context.l10n;
    final maxHeight = math.min(380.0, MediaQuery.sizeOf(context).height * 0.42);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxHeight * 16 / 9),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (frames.isEmpty)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.teaSoft, p.wisteriaSoft]),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.movie_filter_outlined, size: 40, color: p.wisteria),
                        const SizedBox(height: 6),
                        Text(l10n.placeNoFrames, style: theme.textTheme.titleSmall),
                      ],
                    ),
                  )
                else
                  PageView.builder(
                    controller: controller,
                    itemCount: frames.length,
                    onPageChanged: onPage,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => onOpen(i),
                      child: FrameImage(frame: frames[i], cacheWidth: 1280, semanticLabel: captionOf(frames[i])),
                    ),
                  ),
                if (frames.isNotEmpty) ...[
                  Positioned(left: 10, bottom: 10, right: 80, child: Align(alignment: Alignment.centerLeft, child: PageChip(captionOf(frames[index])))),
                  Positioned(right: 10, bottom: 10, child: PageChip('${index + 1} / ${frames.length}')),
                ],
                Positioned(
                  left: 6,
                  top: 6,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    style: IconButton.styleFrom(backgroundColor: Colors.black38),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: back,
                  ),
                ),
                Positioned(right: 6, top: 6, child: menu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A spot: its note (or short name), which way and how far, whether its
/// position is a guess, and its frames, each replaced by the user's photo
/// once shot.
class _SpotCard extends StatelessWidget {
  final PlaceSpot spot;
  final PlaceContent place;
  final bool selected;

  /// "NE 40 m", when the user's position is known.
  final String? way;
  final VoidCallback onSelect;

  /// The spot's menu; null for viewers and spots without frames.
  final VoidCallback? onMenu;
  final ValueChanged<int> onFrame;

  const _SpotCard({
    super.key,
    required this.spot,
    required this.place,
    required this.selected,
    required this.way,
    required this.onSelect,
    required this.onMenu,
    required this.onFrame,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    final shot = place.isShot(spot);
    final shotHere = place.shotIn(spot);
    final info = [
      ?way,
      if (spot.frames.isNotEmpty) l10n.placeFrameCount(spot.frames.length),
      if (shotHere > 0) l10n.placeShotCount(shotHere),
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? p.tea : theme.colorScheme.outlineVariant, width: selected ? 2 : 1),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelect,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    child: Row(
                      children: [
                        _SpotDot(shot: shot, estimated: spot.estimated),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(spot.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (info.isNotEmpty) Text(info, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                                  if (spot.estimated)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(11)),
                                      child: Text(l10n.placeEstimated, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onMenu != null)
                IconButton(
                  key: ValueKey('spotMenu-${spot.key}'),
                  tooltip: l10n.placeSpotOptions(spot.label),
                  icon: const Icon(Icons.more_horiz),
                  onPressed: onMenu,
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (spot.frames.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.placeSpotNoFrames, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            )
          else
            SizedBox(
              height: 65,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: spot.frames.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) => FrameCell(
                  frame: spot.frames[i],
                  photo: place.shot[spot.frames[i].id],
                  onTap: () => onFrame(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A spot's mark, as its pin on the map: filled once shot, dashed while its
/// position is a guess.
class _SpotDot extends StatelessWidget {
  final bool shot;
  final bool estimated;

  const _SpotDot({required this.shot, required this.estimated});

  @override
  Widget build(BuildContext context) {
    final tea = Theme.of(context).trip.tea;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: shot ? tea : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: tea, width: 3, style: BorderStyle.solid),
      ),
      child: estimated && !shot
          ? Center(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: tea, shape: BoxShape.circle)))
          : null,
    );
  }
}

/// After a shoot: the next frame not shot yet, nearest spot first.
class _NextCard extends StatelessWidget {
  final String label;
  final NewReferenceImage frame;
  final VoidCallback? onShoot;
  final VoidCallback onClose;

  const _NextCard({required this.label, required this.frame, required this.onShoot, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Material(
      key: const Key('placeNextCard'),
      color: p.teaSoft,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 72, height: 40, child: FrameImage(frame: frame, cacheWidth: 240)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            if (onShoot != null) TextButton(onPressed: onShoot, child: Text(context.l10n.placeShoot)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// One frame of a spot, or the user's photo of it once shot, with the frame
/// small in the corner so the two can be compared. Also the Places tab's
/// thumbnail.
class FrameCell extends StatelessWidget {
  final NewReferenceImage? frame;
  final Photo? photo;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const FrameCell({super.key, required this.frame, required this.photo, this.onTap, this.width = 116, this.height = 65});

  @override
  Widget build(BuildContext context) {
    final shot = photo;
    final frame = this.frame;
    final p = Theme.of(context).trip;
    final empty = ColoredBox(color: p.wisteriaSoft, child: Icon(Icons.place_outlined, color: p.wisteria));
    return Semantics(
      button: onTap != null,
      label: shot == null ? context.l10n.placeFrameNotShotLabel : context.l10n.placeFrameShotLabel,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (shot != null)
                  PlatformImage(
                    shot.localPath,
                    fit: BoxFit.cover,
                    cacheWidth: 320,
                    errorBuilder: (_, _, _) => frame == null ? empty : FrameImage(frame: frame, cacheWidth: 320),
                  )
                else if (frame != null)
                  FrameImage(frame: frame, cacheWidth: 320)
                else
                  empty,
                if (shot != null && frame != null)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    width: width * 0.34,
                    height: width * 0.34 * 9 / 16,
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
