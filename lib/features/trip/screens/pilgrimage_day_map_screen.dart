import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/models/shooting_core_models.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../camera/services/pilgrimage_shooting_service.dart';
import '../../library/controllers/place_controller.dart';
import '../../library/models/frames.dart';
import '../../library/providers/place_providers.dart';
import '../../library/widgets/place_page_parts.dart';
import '../../planner/controllers/day_planner_controller.dart';
import '../../planner/models/planner_view.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/day_card.dart' show dayName;
import '../../sharing/providers/group_sharing_providers.dart';
import '../providers/trip_providers.dart';
import '../widgets/day_map_pins.dart';
import 'stop_screen.dart' show stopFrames;

/// Pilgrimage mode's main screen: the day's stops on a map with the user's
/// current position, visited stops marked, and instant photo/check-in actions.
class PilgrimageDayMapScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? initialDayId;

  const PilgrimageDayMapScreen({
    super.key,
    required this.tripId,
    this.initialDayId,
  });

  @override
  ConsumerState<PilgrimageDayMapScreen> createState() => _PilgrimageDayMapScreenState();
}

class _PilgrimageDayMapScreenState extends ConsumerState<PilgrimageDayMapScreen>
    with WidgetsBindingObserver {
  late final MapController _mapController;
  String? _selectedDayId;
  String? _selectedStopId;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  bool _locating = false;
  bool _togglingVisited = false;
  bool _launchingCamera = false;
  int _currentFrameIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _selectedDayId = widget.initialDayId;
    _startLocationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLocationService();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopLocationStream();
    }
  }

  void _stopLocationStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _startLocationService() async {
    if (_positionSub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        setState(() => _currentPosition = lastPos);
      }
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (pos) {
          if (mounted) setState(() => _currentPosition = pos);
        },
        onError: (_) {
          // Rule 3: Mandatory stream error handler to prevent unhandled background exceptions.
        },
      );
    } catch (_) {
      // Graceful fallback on environments or desktop where geolocation isn't available.
    }
  }

  Future<void> _centerOnMe() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location service is turned off on this device.')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null && mounted) {
        setState(() => _currentPosition = pos);
        _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't obtain GPS location.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't obtain GPS location: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Clear of the header at the top and a stop's card at the bottom.
  static const _fitPadding = EdgeInsets.only(top: 200, bottom: 280, left: 40, right: 40);

  void _fitStops(List<PlannerItem> items) {
    final points = [for (final b in planBlocks(items)) blockPoint(b)];
    if (points.isEmpty) {
      if (_currentPosition != null) {
        _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 16);
      }
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: _fitPadding,
        maxZoom: 16,
      ),
    );
  }

  /// Picks [item] and brings its pin into view above the card. A group's pin
  /// picks its first stop not visited yet.
  void _selectStop(PlannerItem item, {bool move = true}) {
    setState(() {
      _selectedStopId = item.stop.id;
      _currentFrameIndex = 0;
    });
    if (!move) return;
    final zoom = _mapController.camera.zoom < 15 ? 16.0 : _mapController.camera.zoom;
    // The pin sits 120 px above the middle, clear of the card.
    _mapController.move(LatLng(item.stop.lat, item.stop.lng), zoom, offset: const Offset(0, -120));
  }

  /// Stops on one spot that zooming can't part: pick one from a list.
  Future<void> _pickPin(List<PlannerItem> items, List<MapPin> pins) async {
    final picked = await showModalBottomSheet<MapPin>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final pin in pins)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: pin.done ? pinDoneColor : pin.color,
                  foregroundColor: Colors.white,
                  child: pin.done ? const Icon(Icons.check, size: 18) : Text(pin.label ?? ''),
                ),
                title: Text(pin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: pin.count > 1 ? Text('${pin.count} stops') : null,
                onTap: () => Navigator.pop(context, pin),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _selectPin(items, picked);
  }

  void _selectPin(List<PlannerItem> items, MapPin pin) {
    final block = blockOfStop(items, pin.id);
    if (block == null) return;
    _selectStop(block.items.firstWhere((it) => !it.done, orElse: () => block.first));
  }

  Future<void> _toggleVisited(PlannerItem item) async {
    if (_togglingVisited) return;
    final canEdit = ref.read(canEditTripProvider(widget.tripId));
    if (!canEdit) return;

    final currentUid = ref.read(currentUserIdProvider);
    final trip = ref.read(tripDetailProvider(widget.tripId)).valueOrNull;
    if (trip != null && trip.sharing == 'group' && currentUid == guestUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to make changes to a shared trip.')),
        );
      }
      return;
    }

    _togglingVisited = true;
    try {
      final newDone = !item.done;
      final planner = ref.read(dayPlannerControllerProvider.notifier);
      final place = ref.read(placeControllerProvider.notifier);
      final result = await planner.setVisited(item.item.id, newDone);
      if (result is Failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((result as Failure).error)));
        }
        return;
      }

      final hasPlace = ref.read(placeDetailProvider(item.stop.placeKey)).valueOrNull != null;
      if (hasPlace) {
        if (newDone) {
          await place.addVisitToday(item.stop.placeKey, tripId: widget.tripId);
        } else {
          await place.removeVisitToday(item.stop.placeKey, tripId: widget.tripId);
        }
      }

      if (mounted) {
        final message = !hasPlace
            ? (newDone ? 'Marked visited for the trip.' : 'No longer marked visited.')
            : (newDone ? 'Marked visited for the trip, and added to your visits.' : 'No longer marked visited.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _togglingVisited = false;
    }
  }

  /// The camera on [frames]' [index], with the stop's other frames to switch to.
  Future<void> _shootWithStop(Stop stop, List<NewReferenceImage> frames, int index) async {
    if (_launchingCamera) return;
    _launchingCamera = true;
    try {
      _stopLocationStream();
      try {
        await shootWithFrames(
          context,
          ref,
          placeKey: stop.placeKey,
          tripId: widget.tripId,
          frames: frames,
          index: index,
        );
      } finally {
        if (mounted) _startLocationService();
      }
    } finally {
      _launchingCamera = false;
    }
  }

  Future<void> _openPhotoViewer(String path, String title) async {
    _stopLocationStream();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewer(path: path, title: title, actions: const []),
        ),
      );
    } finally {
      if (mounted) _startLocationService();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final viewAsync = ref.watch(plannerViewProvider(widget.tripId));

    return Scaffold(
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load trip: $e")),
        data: (trip) {
          if (trip == null || trip.deletedAt != null) {
            return const Center(child: Text('This trip is not available.'));
          }
          return viewAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Couldn't load plan: $e")),
            data: (view) => view == null
                ? const Center(child: Text('This trip has no plan yet.'))
                : _buildBody(context, trip, view),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Trip trip, PlannerView view) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final allDays = view.datedDays.isNotEmpty ? view.datedDays : view.days;

    // Pick active day if not selected yet.
    if (_selectedDayId == null && allDays.isNotEmpty) {
      final today = normalizeDateOnly(DateTime.now());
      final todayDay = allDays.where((d) => d.date == today).firstOrNull;
      _selectedDayId = todayDay?.day.id ?? allDays.first.day.id;
    }

    final activeDay = view.dayById(_selectedDayId ?? '') ?? (allDays.isNotEmpty ? allDays.first : null);
    final items = activeDay?.items ?? const <PlannerItem>[];
    final doneCount = items.where((it) => it.done).length;
    final totalCount = items.length;
    final leftCount = totalCount - doneCount;

    final selectedItem = _selectedStopId == null
        ? null
        : items.where((it) => it.stop.id == _selectedStopId).firstOrNull;

    return Stack(
      children: [
        // 1. Fullscreen Interactive Map
        AppMap(
          controller: _mapController,
          pins: dayMapPins(items, color: p.wisteria, selectedStopId: _selectedStopId),
          fitPadding: _fitPadding,
          // The stop's card says its name.
          nameUnderSelected: false,
          center: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(35.6812, 139.7671),
          onPinTap: (pin) => _selectPin(items, pin),
          onClusterOpen: (pins) => _pickPin(items, pins),
          onTap: (_) {
            if (_selectedStopId != null) setState(() => _selectedStopId = null);
          },
          underPins: [
            if (items.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [for (final b in planBlocks(items)) blockPoint(b)],
                    color: p.wisteria.withValues(alpha: 0.65),
                    strokeWidth: 4,
                    pattern: StrokePattern.dashed(segments: const [9, 7]),
                  ),
                ],
              ),
          ],
          overPins: [
            if (_currentPosition != null)
              Marker(
                key: const ValueKey('me'),
                point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                width: 36,
                height: 36,
                child: _buildUserLocationMarker(context),
              ),
          ],
        ),

        // 2. Top Header Overlay (Back Button, Title, Day Selector, Progress Pill)
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopHeader(context, trip, allDays, doneCount, totalCount, leftCount),
            ],
          ),
        ),

        // 3. Floating Action Controls (Fit Route, GPS Center)
        Positioned(
          right: 16,
          bottom: selectedItem != null ? 310 : 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (items.isNotEmpty)
                FloatingActionButton.small(
                  heroTag: 'fab_fit_stops',
                  tooltip: 'Fit route on map',
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurface,
                  onPressed: () => _fitStops(items),
                  child: const Icon(Icons.route_outlined),
                ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'fab_center_me',
                tooltip: 'Center on my location',
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: _locating ? p.tea : theme.colorScheme.onSurface,
                onPressed: _locating ? null : _centerOnMe,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
        ),

        // 4. Bottom Selected Stop Card
        if (selectedItem != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _buildStopBottomCard(context, selectedItem, items),
          ),

        // 5. Empty Day State Overlay
        if (items.isEmpty)
          Center(
            child: Card(
              color: theme.colorScheme.surface.withValues(alpha: 0.94),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'No stops on this day',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add stops from the plan or pick another day to view its pilgrimage map.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserLocationMarker(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    Trip trip,
    List<PlannerDay> allDays,
    int doneCount,
    int totalCount,
    int leftCount,
  ) {
    final theme = Theme.of(context);
    final p = theme.trip;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AppBar Row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  tooltip: 'Back',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              trip.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              totalCount == 0
                                  ? 'No stops'
                                  : (leftCount == 0
                                      ? '🎉 All $totalCount visited!'
                                      : '$doneCount of $totalCount visited · $leftCount left'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: leftCount == 0 ? p.tea : theme.colorScheme.onSurfaceVariant,
                                fontWeight: leftCount == 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (allDays.length > 1)
                        Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Horizontal Days Strip if multiple days
          if (allDays.length > 1) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: allDays.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final day = allDays[i];
                  final isSelected = day.day.id == _selectedDayId;
                  final isToday = day.date == normalizeDateOnly(DateTime.now());
                  return ChoiceChip(
                    label: Text(
                      isToday ? '${dayName(day)} (Today)' : dayName(day),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: isToday ? p.tea : theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
                    elevation: isSelected ? 2 : 0,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedDayId = day.day.id;
                          _selectedStopId = null;
                        });
                        _fitStops(day.items);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStopBottomCard(BuildContext context, PlannerItem item, List<PlannerItem> dayItems) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final stop = item.stop;
    final canEdit = ref.watch(canEditTripProvider(widget.tripId));

    // Load stop frames
    final place = ref.watch(placeDetailProvider(stop.placeKey)).valueOrNull;
    final frames = stopFrames(
      place: place == null ? const [] : ref.watch(placeReferenceImagesProvider(stop.placeKey)).valueOrNull ?? const [],
      stop: ref.watch(stopReferenceImagesProvider(stop.id)).valueOrNull ?? const [],
    );
    if (_currentFrameIndex >= frames.length) _currentFrameIndex = 0;
    final currentFrame = frames.isEmpty ? null : frames[_currentFrameIndex];

    // Load photos already taken on this place/stop
    final photos = ref.watch(placePhotosProvider(stop.placeKey)).valueOrNull ?? const <Photo>[];
    final stopPhotos = photos.where((p) => p.tripId == widget.tripId || p.tripId == null).toList();

    // Calculate distance and bearing if current position is known
    SpotBearingInfo? bearingInfo;
    if (_currentPosition != null) {
      bearingInfo = PilgrimageShootingService.calculateBearingInfo(
        userLat: _currentPosition!.latitude,
        userLng: _currentPosition!.longitude,
        spotLat: stop.lat,
        spotLng: stop.lng,
      );
    }

    // A group is one pin; its card steps through the group's stops.
    final block = blockOfStop(dayItems, stop.id);
    final group = block != null && block.isGroup ? block : null;
    final at = group?.items.indexWhere((it) => it.stop.id == stop.id) ?? -1;

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group != null)
              Row(
                key: const Key('dayMapGroupStrip'),
                children: [
                  Icon(Icons.layers_outlined, size: 16, color: p.wisteria),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${group.group} · ${at + 1} of ${group.items.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: p.wisteria, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous stop in the group',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: at > 0 ? () => _selectStop(group.items[at - 1], move: false) : null,
                  ),
                  IconButton(
                    tooltip: 'Next stop in the group',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: at < group.items.length - 1 ? () => _selectStop(group.items[at + 1], move: false) : null,
                  ),
                ],
              ),
            // Top Row: Title, Distance/Bearing, and Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (bearingInfo != null) ...[
                            Icon(Icons.near_me_outlined, size: 14, color: p.tea),
                            const SizedBox(width: 4),
                            Text(
                              bearingInfo.description(preferClock: false),
                              style: theme.textTheme.bodySmall?.copyWith(color: p.tea, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (item.done)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: p.teaSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Visited',
                                style: TextStyle(fontSize: 11, color: p.tea, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedStopId = null),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Frame Preview & Kept Photos Strip (Centerpiece)
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  // Main Reference Frame
                  Expanded(
                    flex: 5,
                    child: currentFrame == null
                        ? Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.photo_outlined, size: 36, color: Colors.grey),
                            ),
                          )
                        : GestureDetector(
                            onTap: frames.length > 1
                                ? () {
                                    setState(() {
                                      _currentFrameIndex = (_currentFrameIndex + 1) % frames.length;
                                    });
                                  }
                                : null,
                            onHorizontalDragEnd: frames.length > 1
                                ? (details) {
                                    final v = details.primaryVelocity;
                                    if (v == null || v == 0) return;
                                    if (v < 0) {
                                      setState(() {
                                        _currentFrameIndex = (_currentFrameIndex + 1) % frames.length;
                                      });
                                    } else {
                                      setState(() {
                                        _currentFrameIndex = (_currentFrameIndex - 1 + frames.length) % frames.length;
                                      });
                                    }
                                  }
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FrameImage(frame: currentFrame, cacheWidth: 720),
                                  if (frames.length > 1)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${_currentFrameIndex + 1}/${frames.length}',
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  // If user has captured shots for this spot, display them next to the frame
                  if (stopPhotos.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stopPhotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final photo = stopPhotos[idx];
                          return GestureDetector(
                            onTap: () => _openPhotoViewer(photo.localPath, stop.name),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Image.file(
                                  File(photo.localPath),
                                  fit: BoxFit.cover,
                                  cacheWidth: 320,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons Row: Take photo, Mark visited, Details
            Row(
              children: [
                if (animeCameraSupported) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shootWithStop(stop, frames, _currentFrameIndex),
                      icon: const Icon(Icons.photo_camera, size: 18),
                      label: const Text('Take photo'),
                    ),
                  ),
                  if (canEdit) const SizedBox(width: 8),
                ],
                if (canEdit) ...[
                  if (!animeCameraSupported)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleVisited(item),
                        icon: Icon(
                          item.done ? Icons.check_circle : Icons.check_circle_outline,
                          size: 18,
                          color: item.done ? p.tea : null,
                        ),
                        label: Text(
                          item.done ? 'Visited' : 'Mark visited',
                          style: TextStyle(color: item.done ? p.tea : null),
                        ),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _toggleVisited(item),
                      icon: Icon(
                        item.done ? Icons.check_circle : Icons.check_circle_outline,
                        size: 18,
                        color: item.done ? p.tea : null,
                      ),
                      label: Text(
                        item.done ? 'Visited' : 'Mark visited',
                        style: TextStyle(color: item.done ? p.tea : null),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  tooltip: 'Stop details',
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () async {
                    _stopLocationStream();
                    try {
                      await context.push('/trips/${widget.tripId}/stops/${stop.id}');
                    } finally {
                      if (mounted) _startLocationService();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
