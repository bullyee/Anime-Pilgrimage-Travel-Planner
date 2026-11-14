import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'map_pins.dart';

export 'map_pins.dart';

/// Whether maps load their tiles. Tests turn it off so nothing goes online.
final mapTilesProvider = Provider<bool>((ref) => true);

const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const mapUserAgentPackage = 'com.example.trip_planner';

/// The grey of a visited stop.
const pinDoneColor = Color(0xFF9AA0A6);

/// Pins near each other merge below this zoom. At it and above, only pins on
/// top of each other (within [overlapRadius]) still merge, since zooming in
/// further can't part them.
const clusterUntilZoom = 17.0;

/// The most OSM's tiles go to; past it they'd only blur.
const mapMaxZoom = 19.0;

/// Logical pixels between pins that count as on top of each other.
const overlapRadius = 14.0;

/// Keeps the map tiles you've seen on the phone (flutter_map's built-in cache),
/// in the app's support folder so Android doesn't clear it, up to 300 MB.
///
/// A tile counts as fresh for 14 days whatever the server says, so a place you
/// looked at while planning still shows on the day without a connection, and
/// the same tile isn't fetched again each time a map opens. OSM's tile policy
/// asks apps to cache; this never downloads tiles you didn't look at.
///
/// Call once before the first map is built; later calls do nothing until
/// [clearMapTileCache] has run.
Future<void> setUpMapTileCache() async {
  if (kIsWeb) return;
  try {
    final dir = await mapTileCacheDirectory();
    if (dir == null) return;
    mapTileCache.value = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: dir,
      maxCacheSize: 300 * 1024 * 1024,
      overrideFreshAge: const Duration(days: 14),
    );
  } catch (_) {
    // No support folder (an odd platform): tiles aren't kept.
  }
}

/// Where [setUpMapTileCache] keeps the tiles; null on the web.
Future<String?> mapTileCacheDirectory() async {
  if (kIsWeb) return null;
  return p.join((await getApplicationSupportDirectory()).path, 'map_tiles');
}

/// Deletes the kept tiles (Settings → Clear map tiles) and starts an empty
/// cache. Maps on screen switch to the new cache by themselves.
Future<void> clearMapTileCache() async {
  final old = mapTileCache.value;
  // Maps let go of the old cache before it's deleted under them.
  mapTileCache.value = null;
  if (old is BuiltInMapCachingProvider) {
    try {
      await old.destroy(deleteCache: true);
    } catch (_) {
      // No tiles were kept yet, so there was no folder to delete.
    }
  }
  await setUpMapTileCache();
}

/// Set by [setUpMapTileCache]; without it (tests, web) tiles aren't kept, and
/// flutter_map never looks for its own cache folder.
final mapTileCache = ValueNotifier<MapCachingProvider?>(null);

/// The OpenStreetMap tiles every map uses.
class AppTileLayer extends StatefulWidget {
  const AppTileLayer({super.key});

  @override
  State<AppTileLayer> createState() => _AppTileLayerState();
}

class _AppTileLayerState extends State<AppTileLayer> {
  // One per layer: TileLayer disposes its provider when it goes.
  late var _provider = _newProvider();

  NetworkTileProvider _newProvider() =>
      NetworkTileProvider(cachingProvider: mapTileCache.value ?? const DisabledMapCachingProvider());

  @override
  void initState() {
    super.initState();
    mapTileCache.addListener(_cacheChanged);
  }

  @override
  void dispose() {
    mapTileCache.removeListener(_cacheChanged);
    super.dispose();
  }

  // A new cache needs a new provider, and a new TileLayer (by its key) so the
  // old one disposes the old provider.
  void _cacheChanged() => setState(() => _provider = _newProvider());

  @override
  Widget build(BuildContext context) => TileLayer(
        key: ObjectKey(_provider),
        urlTemplate: osmTileUrl,
        userAgentPackageName: mapUserAgentPackage,
        tileProvider: _provider,
        // Tiles from the cache appear at once instead of fading in over the
        // old zoom's tiles.
        tileDisplay: const TileDisplay.instantaneous(),
      );
}

/// The one map widget behind every map in the app: the day map, the library's,
/// a place's, Home's and the new spot picker.
///
/// - The camera fits [pins] when the map opens, and again when [fitKey]
///   changes. The map itself is never rebuilt from scratch for new pins, so it
///   doesn't flash or jump back.
/// - Pins near each other merge into a bubble below [clusterUntilZoom] when
///   [cluster] is on; tapping one zooms in to its pins, or calls
///   [onClusterOpen] when they're all at one spot.
/// - Each pin's marker is keyed by its [MapPin.id].
class AppMap extends ConsumerStatefulWidget {
  final List<MapPin> pins;
  final MapController? controller;
  final bool interactive;
  final bool cluster;

  /// Space to keep clear around the pins when fitting (cards, headers).
  final EdgeInsets fitPadding;
  final double fitMaxZoom;

  /// Where to look when there are no pins, and at what zoom.
  final LatLng? center;
  final double zoom;

  /// Fits the camera to [pins] again whenever it changes (a new day, a new
  /// filter). Leave null to fit only when the map opens.
  final Object? fitKey;

  final ValueChanged<MapPin>? onPinTap;

  /// Called with a cluster's pins when zooming in can't split them.
  final ValueChanged<List<MapPin>>? onClusterOpen;
  final ValueChanged<LatLng>? onTap;
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;

  /// Layers drawn over the tiles and under the pins (a route).
  final List<Widget> underPins;

  /// Markers drawn over the pins, never clustered (your location).
  final List<Marker> overPins;

  /// The "© OpenStreetMap contributors" corner; small maps print their own.
  final bool attribution;

  /// Shows the selected pin's name under it. Off where a card already says it.
  final bool nameUnderSelected;
  final Color? background;

  const AppMap({
    super.key,
    this.pins = const [],
    this.controller,
    this.interactive = true,
    this.cluster = true,
    this.fitPadding = const EdgeInsets.all(48),
    this.fitMaxZoom = 16,
    this.center,
    this.zoom = 15,
    this.fitKey,
    this.onPinTap,
    this.onClusterOpen,
    this.onTap,
    this.onPositionChanged,
    this.underPins = const [],
    this.overPins = const [],
    this.attribution = true,
    this.nameUnderSelected = true,
    this.background,
  });

  @override
  ConsumerState<AppMap> createState() => _AppMapState();
}

class _AppMapState extends ConsumerState<AppMap> {
  MapController? _own;
  bool _ready = false;

  MapController get _controller => widget.controller ?? (_own ??= MapController());

  @override
  void didUpdateWidget(AppMap old) {
    super.didUpdateWidget(old);
    if (old.controller == null && widget.controller != null) {
      _own?.dispose();
      _own = null;
    }
    if (widget.fitKey != old.fitKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fit();
      });
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// Shows every pin, or centres on the only one.
  void fit() {
    if (!_ready) return;
    final points = [for (final p in widget.pins) p.point];
    final cameraFit = fitPoints(points, padding: widget.fitPadding, maxZoom: widget.fitMaxZoom);
    if (cameraFit != null) {
      _controller.fitCamera(cameraFit);
    } else if (points.length == 1) {
      _controller.move(points.single, widget.fitMaxZoom);
    } else if (widget.center != null) {
      _controller.move(widget.center!, widget.zoom);
    }
  }

  void _openCluster(PinCluster c) {
    final points = [for (final p in c.pins) p.point];
    final bounds = LatLngBounds.fromPoints(points);
    final tiny = (bounds.north - bounds.south).abs() < 0.0002 && (bounds.east - bounds.west).abs() < 0.0002;
    if (tiny || _controller.camera.zoom >= clusterUntilZoom - 0.01) {
      if (widget.onClusterOpen != null) {
        widget.onClusterOpen!(c.pins);
      } else {
        widget.onPinTap?.call(c.first);
      }
      return;
    }
    _controller.fitCamera(CameraFit.coordinates(
      coordinates: points,
      padding: widget.fitPadding,
      maxZoom: clusterUntilZoom,
      // At least one level in, but never past where pins stop merging, or
      // clamp() throws (min > max) between zoom 16 and 17.
      minZoom: math.min(_controller.camera.zoom + 1, clusterUntilZoom),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = ref.watch(mapTilesProvider);
    final points = [for (final p in widget.pins) p.point];
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: points.firstOrNull ?? widget.center ?? const LatLng(35.6812, 139.7671),
        initialZoom: points.length == 1 ? widget.fitMaxZoom : widget.zoom,
        maxZoom: mapMaxZoom,
        initialCameraFit: fitPoints(points, padding: widget.fitPadding, maxZoom: widget.fitMaxZoom),
        backgroundColor: widget.background ?? theme.colorScheme.surfaceContainerHighest,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onMapReady: () => _ready = true,
        onTap: widget.onTap == null ? null : (_, at) => widget.onTap!(at),
        onPositionChanged: widget.onPositionChanged,
      ),
      children: [
        if (tiles) const AppTileLayer(),
        ...widget.underPins,
        _PinLayer(
          pins: widget.pins,
          cluster: widget.cluster,
          nameUnderSelected: widget.nameUnderSelected,
          onPinTap: widget.onPinTap,
          onClusterTap: _openCluster,
        ),
        if (widget.overPins.isNotEmpty) MarkerLayer(markers: widget.overPins),
        if (tiles && widget.attribution) const _Attribution(),
      ],
    );
  }
}

/// The pins, clustered for the camera's whole zoom level. The clusters are
/// worked out again only when the pins or the zoom level change, not on every
/// frame of a pan.
class _PinLayer extends StatefulWidget {
  final List<MapPin> pins;
  final bool cluster;
  final bool nameUnderSelected;
  final ValueChanged<MapPin>? onPinTap;
  final ValueChanged<PinCluster> onClusterTap;

  const _PinLayer({
    required this.pins,
    required this.cluster,
    required this.nameUnderSelected,
    required this.onPinTap,
    required this.onClusterTap,
  });

  @override
  State<_PinLayer> createState() => _PinLayerState();
}

class _PinLayerState extends State<_PinLayer> {
  List<MapPin>? _pins;
  double? _level;
  List<PinCluster> _clusters = const [];

  List<PinCluster> _clustersAt(double zoom) {
    final level = widget.cluster ? zoom.floorToDouble() : double.infinity;
    if (!identical(_pins, widget.pins) || _level != level) {
      _pins = widget.pins;
      _level = level;
      _clusters = level.isInfinite
          ? [for (final p in widget.pins) PinCluster([p], p.point)]
          : clusterPins(widget.pins, zoom: level, radius: level >= clusterUntilZoom ? overlapRadius : 36);
    }
    return _clusters;
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final clusters = _clustersAt(camera.zoom);
    // Bubbles first, then pins, then the next one, then the selected one, so
    // the pins that matter are drawn on top.
    int rank(PinCluster c) => !c.single ? 0 : (c.first.selected ? 3 : (c.first.next ? 2 : 1));
    final ordered = [
      for (var r = 0; r <= 3; r++)
        for (final c in clusters) if (rank(c) == r) c,
    ];
    return MarkerLayer(
      markers: [
        for (final c in ordered)
          if (c.single)
            pinMarker(c.first, onTap: widget.onPinTap, withName: widget.nameUnderSelected)
          else clusterMarker(c, onTap: widget.onClusterTap),
      ],
    );
  }
}

/// The diameter of [pin]'s dot.
double pinSize(MapPin pin) => pin.selected
    ? 40
    : pin.next
        ? 34
        : pin.label != null
            ? 30
            : 24;

/// [pin] as a marker whose dot is centred on its point. A selected pin carries
/// its name underneath.
Marker pinMarker(MapPin pin, {ValueChanged<MapPin>? onTap, bool withName = true}) {
  final size = pinSize(pin);
  // Room for the count badge, which pokes out of the top right.
  final box = size + 12;
  final named = pin.selected && withName;
  final height = named ? box + 26 : box;
  return Marker(
    key: ValueKey('pin:${pin.id}'),
    point: pin.point,
    width: named ? 180 : box,
    height: height,
    // Puts the dot's centre, box / 2 from the top, on the point.
    alignment: Alignment(0, 1 - box / height),
    child: PinDot(pin: pin, withName: named, onTap: onTap == null ? null : () => onTap(pin)),
  );
}

Marker clusterMarker(PinCluster cluster, {required ValueChanged<PinCluster> onTap}) {
  final size = clusterSize(cluster);
  return Marker(
    key: ValueKey('cluster:${cluster.first.id}'),
    point: cluster.point,
    width: size + 12,
    height: size + 12,
    child: ClusterBubble(cluster: cluster, onTap: () => onTap(cluster)),
  );
}

double clusterSize(PinCluster c) => 32 + math.min(16, math.log(c.count) / math.ln2 * 3);

/// A pin: a coloured dot with a white rim, its number or a check inside, a ring
/// when it's next or selected, and a badge with how many stops it stands for.
/// Drawn with plain boxes, no glyph shadows or animations, so nothing lingers
/// on screen while the map moves.
class PinDot extends StatelessWidget {
  final MapPin pin;
  final VoidCallback? onTap;

  /// Its name in a tag underneath.
  final bool withName;

  const PinDot({super.key, required this.pin, this.onTap, this.withName = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = pinSize(pin);
    final color = pin.done ? pinDoneColor : pin.color;
    final dot = SizedBox(
      width: size + 12,
      height: size + 12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: pin.selected ? 3 : 2.5),
              boxShadow: [
                if (pin.selected || pin.next) BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 4),
                const BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            alignment: Alignment.center,
            child: pin.done
                ? Icon(Icons.check, size: size * 0.5, color: Colors.white)
                : pin.label != null
                    ? Text(
                        pin.label!,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: pin.selected ? 15 : (pin.next ? 13 : 12),
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      )
                    : Container(
                        width: size * 0.28,
                        height: size * 0.28,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
          ),
          if (pin.count > 1)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${pin.count}',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 10, fontWeight: FontWeight.w800, height: 1),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: pin.count > 1 ? '${pin.name}, ${pin.count} stops' : pin.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: withName
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot,
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                    child: Text(
                      pin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            : dot,
      ),
    );
  }
}

/// "© OpenStreetMap contributors" in a corner, as OSM's licence asks.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '© OpenStreetMap contributors',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ),
      ),
    );
  }
}

/// Several pins in one bubble: their numbers ("3–5") or a count.
class ClusterBubble extends StatelessWidget {
  final PinCluster cluster;
  final VoidCallback onTap;

  const ClusterBubble({super.key, required this.cluster, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = clusterSize(cluster);
    final color = cluster.allDone ? pinDoneColor : (cluster.sharedColor ?? const Color(0xFF455A64));
    final label = cluster.label;
    return Semantics(
      button: true,
      label: '${cluster.count} stops here: ${cluster.pins.map((p) => p.name).take(5).join(', ')}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), spreadRadius: 5),
                const BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A colour per anime, so a library map tells works apart at a glance. Stable
/// across runs (FNV-1a of the label's id, not `hashCode`).
Color animeColor(String? animeId, {required Color none}) {
  if (animeId == null || animeId.isEmpty) return none;
  var h = 0x811c9dc5;
  for (final c in animeId.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return animePalette[h % animePalette.length];
}

/// Readable on OSM's light tiles under a white rim.
const animePalette = [
  Color(0xFF7E57C2),
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF00897B),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
  Color(0xFF8D6E00),
];
