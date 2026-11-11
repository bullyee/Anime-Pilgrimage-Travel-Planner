import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/providers/place_providers.dart';
import '../../poi/services/background_photo_save.dart' show galleryAlbum, rootMessengerKey;
import '../../sharing/providers/group_sharing_providers.dart';
import '../../trip/providers/trip_providers.dart';
import '../models/shot_series.dart';
import '../services/camera_overlay.dart';
import '../services/kept_shots.dart';
import '../services/shot_plan.dart';

/// What the shots route (`/shots`) carries in its query: a new series to
/// shoot for a place and its frames, starting on [frameIndex], or
/// [seriesId], a series to pick from again after Android killed the app.
class ShotSeriesArgs {
  final String? seriesId;
  final String? placeKey;
  final String? tripId;

  /// The spot's frames in its order, to switch between in the floating
  /// window; one for a single frame or a gallery reference, none for no
  /// reference.
  final List<SeriesFrame> frames;
  final int frameIndex;

  const ShotSeriesArgs({
    this.seriesId,
    this.placeKey,
    this.tripId,
    this.frames = const [],
    this.frameIndex = 0,
  });

  /// The router has decoded the values already, so they're used as they are
  /// (see `PhotoEditArgs.fromQuery`, #84). Each frame is a `ref` with its
  /// `refId` at the same position (empty for a gallery reference).
  static ShotSeriesArgs fromQuery(Map<String, List<String>> query) {
    String? one(String key) => query[key]?.firstOrNull;
    final paths = query['ref'] ?? const [];
    final ids = query['refId'] ?? const [];
    return ShotSeriesArgs(
      seriesId: one('series'),
      placeKey: one('place'),
      tripId: one('trip'),
      frames: [
        for (var i = 0; i < paths.length; i++)
          SeriesFrame(paths[i], imageId: i < ids.length && ids[i].isNotEmpty ? ids[i] : null),
      ],
      frameIndex: int.tryParse(one('frame') ?? '') ?? 0,
    );
  }

  String get location => Uri(path: '/shots', queryParameters: {
        if (seriesId != null) 'series': seriesId!,
        if (placeKey != null) 'place': placeKey!,
        if (tripId != null) 'trip': tripId!,
        if (frames.isNotEmpty) 'ref': [for (final f in frames) f.path],
        if (frames.isNotEmpty) 'refId': [for (final f in frames) f.imageId ?? ''],
        if (frameIndex != 0) 'frame': '$frameIndex',
      }).toString();
}

final shotSeriesStoreProvider = Provider<ShotSeriesStore>((ref) => ShotSeriesStore());

/// The window that floats the frames over the camera; tests replace it.
final referenceWindowProvider = Provider<ReferenceWindow>((ref) => const CameraOverlayWindow());

/// Several shots at one spot, then keep the ones you want (roadmap v0.3.0,
/// "Several shots, then pick").
///
/// The phone's camera app returns one photo per opening, so after each shot
/// the camera opens again with the frame still floating where the user left
/// it, and backing out of the camera ends the series. When the spot has
/// several frames, ‹ › in the window switch between them without leaving
/// the camera, and each shot remembers the frame showing when it came back.
/// The shots then show under the frame each was taken with; the ones the
/// user keeps are saved as shot, with no editing on the spot, and the rest
/// are deleted.
///
/// Keep records the picks with `recordShot`: the photos, filed under the
/// trip, and the day's visit. A shot changes nothing in the plan by itself.
/// For the people who can edit the trip, when the place is on a day of it a
/// "Mark done" tick under the shots says whether the stop is done (on the
/// day it's planned for), ticked already when every frame of the spot has a
/// photo; when it isn't on a day, "Add to Day N" offers to put it on the day
/// of the shot. Everyone sees the stop's progress ("2 of 5 frames").
class ShotSeriesScreen extends ConsumerStatefulWidget {
  const ShotSeriesScreen({super.key, required this.args, this.camera, this.gallery});

  final ShotSeriesArgs args;

  /// Opens the camera and returns the shot's path, or null when the user
  /// backs out. Defaults to the phone's camera app; tests replace it.
  final Future<String?> Function()? camera;

  /// Saves a kept shot to the phone's gallery. Defaults to the app's album
  /// on Android and iOS; tests replace it.
  final Future<void> Function(String path)? gallery;

  @override
  ConsumerState<ShotSeriesScreen> createState() => _ShotSeriesScreenState();
}

class _ShotSeriesScreenState extends ConsumerState<ShotSeriesScreen> {
  /// The series' shots and frames. While the camera is open, only the
  /// queued writes ([_queued]) replace it, so a write never drops a shot.
  ShotSeries? _series;
  final _kept = <String>{};

  /// The frame floating now, an index into the series' frames. The window
  /// reports each switch, which can come while a shot is being added, so it's
  /// kept apart and written into the series with every write.
  var _frameIndex = 0;

  final _pages = PageController();
  var _current = 0;
  var _shooting = false;
  var _saving = false;

  /// Whether the window has been shown for this series, so Take more brings
  /// it back where the user left it.
  var _shownOnce = false;

  /// Where the place stands in a trip on the day, for the ticks; loaded once
  /// per series, after the first shots.
  ShotPlan? _plan;
  String? _planFor;

  /// The user's answer to "Mark done"; until they touch it, the tick follows
  /// whether every frame has a shot among the kept ones.
  bool? _markDoneChoice;
  var _addToDay = false;

  /// The latest write of the series, so the next write or the series'
  /// deletion waits for it.
  Future<void> _writes = Future.value();

  ShotSeriesStore get _store => ref.read(shotSeriesStoreProvider);
  ReferenceWindow get _window => ref.read(referenceWindowProvider);

  /// The series as it should be on disk: with the frame showing and the
  /// picks.
  ShotSeries? get _latest => _series?.withFrameIndex(_frameIndex).withKept(_kept);

  /// Runs [op] after the writes before it, one at a time.
  Future<T> _queued<T>(Future<T> Function() op) {
    final done = _writes.then((_) => op());
    _writes = done.then<void>((_) {}, onError: (Object _) {
      // Only the picks or the frame are lost if Android kills the app; the
      // shots' files are safe.
    });
    return done;
  }

  /// Writes the series as it is now, after any write before it.
  void _persist() {
    _queued(() async {
      final series = _latest;
      if (series != null) await _store.save(series);
    });
  }

  /// The plan with the kept shots' frames counted as shot.
  ShotPlan? get _livePlan {
    final series = _series;
    final plan = _plan;
    if (series == null || plan == null) return plan;
    return plan.withShotFrames([
      for (final shot in series.shots)
        if (_kept.contains(shot.path)) series.frameOf(shot)?.imageId,
    ]);
  }

  bool get _markDone => _markDoneChoice ?? _livePlan?.suggestDone ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final args = widget.args;
    final id = args.seriesId;
    if (id != null) {
      final series = await _store.load(id);
      if (!mounted) return;
      if (series == null || series.shots.isEmpty) {
        if (series != null) await _store.discard(series.id);
        _leave();
        return;
      }
      // Back after Android killed the app: the picks so far, on the newest shot.
      setState(() {
        _series = series;
        _frameIndex = series.frameIndex;
        _kept.addAll(series.kept);
        _current = series.shots.length - 1;
        _preselect();
      });
      _showCurrent();
      _loadPlan();
      return;
    }
    final series = await _store.create(
      placeKey: args.placeKey,
      tripId: args.tripId,
      frames: args.frames,
      frameIndex: args.frameIndex,
    );
    if (!mounted) return;
    setState(() {
      _series = series;
      _frameIndex = series.frameIndex;
    });
    await _shoot();
  }

  Future<String?> _openCamera() async {
    final camera = widget.camera;
    if (camera != null) return camera();
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    return shot?.path;
  }

  /// Opens the camera again after every shot until the user backs out of it.
  Future<void> _shoot() async {
    if (_series == null || _shooting || _saving) return;
    setState(() => _shooting = true);
    await _writes;
    final start = _series;
    if (start == null || !mounted) return;
    final window = _window;
    var floating = false;
    StreamSubscription<int>? switches;
    if (start.frames.isNotEmpty && await window.canShow()) {
      // The window reports each switch; the frame is written at once, so a
      // shot Android hands back after killing the app still gets it.
      switches = window.frameChanges.listen((index) {
        final frames = _series?.frames.length ?? 0;
        if (index < 0 || index >= frames || index == _frameIndex) return;
        _frameIndex = index;
        _persist();
      });
      floating = await window.show(
        [for (final frame in start.frames) frame.path],
        index: _frameIndex,
        keepPlacement: _shownOnce,
      );
      _shownOnce = _shownOnce || floating;
    }
    String? error;
    try {
      while (mounted) {
        final path = await _openCamera();
        if (path == null) break;
        // Recorded with the frame showing as the camera hands the shot back.
        await _queued(() async => _series = await _store.addShot(_latest!, path));
        if (!mounted) break;
        setState(() => _current = _series!.shots.length - 1);
        _showCurrent();
      }
    } on PlatformException catch (e) {
      error = 'Camera unavailable: ${e.message ?? e.code}';
    } finally {
      // Not awaited: nothing waits on the cancel.
      unawaited(switches?.cancel());
      if (floating) await window.hide();
    }
    if (!mounted) return;
    final series = _series!;
    setState(() {
      _shooting = false;
      _preselect();
    });
    if (error != null) rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(error)));
    if (series.shots.isEmpty) {
      // Backed out without a shot: nothing to pick from.
      await _discardSeries(series.id);
      _leave();
      return;
    }
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final series = _series;
    final placeKey = series?.placeKey;
    if (series == null || placeKey == null || series.shots.isEmpty || _planFor == series.id) return;
    _planFor = series.id;
    try {
      final plan = await loadShotPlan(
        ref.read(databaseProvider),
        placeKey: placeKey,
        tripId: series.tripId,
        takenAt: series.shots.first.takenAt,
      );
      if (!mounted || plan == null) return;
      setState(() => _plan = plan);
    } catch (_) {
      // The shots still save without it; only the ticks are missing.
    }
  }

  /// Applies the ticks once the shots are saved; what changed, for the
  /// message.
  Future<String?> _applyPlan(ShotSeries series, String? placeName) async {
    final plan = _plan;
    final placeKey = series.placeKey;
    // Only the people who can edit the trip change its plan.
    if (plan == null || placeKey == null || !ref.read(canEditTripProvider(plan.trip.id))) return null;
    try {
      final change = await applyShotPlan(
        ref.read(tripRepositoryProvider),
        plan,
        placeKey: placeKey,
        userId: ref.read(currentUserIdProvider),
        markDone: _markDone,
        addToDay: _addToDay,
      );
      final name = placeName ?? plan.stop?.name ?? 'it';
      return switch (change) {
        ShotPlanChange.markedDone => 'Marked $name done.',
        ShotPlanChange.unmarked => 'Marked $name not done.',
        ShotPlanChange.added => 'Added $name to Day ${plan.shotDayNumber}.',
        ShotPlanChange.addedDone => 'Added $name to Day ${plan.shotDayNumber}, done.',
        null => null,
      };
    } catch (e) {
      return "Couldn't update ${plan.trip.title}: $e";
    }
  }

  /// A single shot is kept unless the user says otherwise; from several,
  /// the user picks.
  void _preselect() {
    final shots = _series?.shots ?? const [];
    if (shots.length == 1 && _kept.isEmpty) {
      _kept.add(shots.single.path);
      _saveKept();
    }
  }

  /// Writes the picks to the series on disk, one write after another.
  void _saveKept() => _persist();

  /// Deletes the series once any pending write of the picks is done, so that
  /// write can't bring its folder back.
  Future<void> _discardSeries(String id) async {
    await _writes;
    await _store.discard(id);
  }

  void _showCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      final target = _current;
      _pages.jumpToPage(target);
      // A jump past the pages laid out so far reports the last of those on
      // the way; the frame pane follows [_current], so set it back.
      if (_current != target) setState(() => _current = target);
    });
  }

  void _toggle(SeriesShot shot) {
    setState(() {
      if (!_kept.remove(shot.path)) _kept.add(shot.path);
    });
    _saveKept();
  }

  Future<void> Function(String path)? get _gallery {
    if (widget.gallery != null) return widget.gallery;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
    return (path) async {
      if (!await Gal.requestAccess(toAlbum: true)) throw StateError('no access to the gallery');
      await Gal.putImage(path, album: galleryAlbum);
    };
  }

  Future<void> _keep(String? placeName) async {
    final series = _latest;
    if (series == null || _kept.isEmpty || _saving || _shooting) return;
    setState(() => _saving = true);
    final kept = [
      for (final shot in series.shots)
        if (_kept.contains(shot.path)) shot,
    ];
    final result = await saveKeptShots(
      series: series,
      kept: kept,
      db: ref.read(databaseProvider),
      toGallery: _gallery,
    );
    final saved = series.placeKey == null ? result.toGallery : result.toPlace;
    if (saved < kept.length) {
      // Keep the series, so nothing is lost; the user can try again.
      if (!mounted) return;
      setState(() => _saving = false);
      final why = result.galleryError == null ? '' : ': ${result.galleryError}';
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Saved $saved of ${kept.length}$why. Try again.')),
      );
      return;
    }
    final planNote = await _applyPlan(series, placeName);
    await _discardSeries(series.id);
    final message = _savedMessage(result, kept.length, series.placeKey == null ? null : placeName ?? 'the place');
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(planNote == null ? message : "$message $planNote")),
    );
    if (mounted) _leave();
  }

  static String _savedMessage(KeptShotsResult result, int count, String? placeName) {
    final photos = count == 1 ? 'the photo' : '$count photos';
    if (placeName == null) return 'Saved $photos to the gallery.';
    if (result.galleryError != null) {
      return "Saved $photos to $placeName. Couldn't save to the gallery: ${result.galleryError}";
    }
    return result.toGallery == 0 ? 'Saved $photos to $placeName.' : 'Saved $photos to $placeName and the gallery.';
  }

  Future<void> _discard() async {
    final series = _series;
    if (_saving || _shooting) return;
    final count = series?.shots.length ?? 0;
    if (count > 0) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(count == 1 ? 'Discard this shot?' : 'Discard these $count shots?'),
          content: const Text('They are only kept here until you pick, so this deletes them.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
          ],
        ),
      );
      if (sure != true) return;
    }
    if (series != null) await _discardSeries(series.id);
    if (mounted) _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    final shots = series?.shots ?? const <SeriesShot>[];
    final placeKey = series?.placeKey ?? widget.args.placeKey;
    final placeName = placeKey == null ? null : ref.watch(placeDetailProvider(placeKey)).valueOrNull?.name;
    // The frame the shot showing was taken with.
    final shotFrame = series == null || shots.isEmpty ? null : series.frameOf(shots[_current.clamp(0, shots.length - 1)]);
    final frameNumber = shotFrame == null ? -1 : series!.frames.indexOf(shotFrame);
    final frameLabel = series != null && series.frames.length > 1 && frameNumber >= 0
        ? 'Frame ${frameNumber + 1} of ${series.frames.length}'
        : 'Frame';
    final base = Theme.of(context);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: base.colorScheme.primary, brightness: Brightness.dark),
    );
    final busy = _shooting || _saving;

    return Theme(
      data: theme,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _discard();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Discard',
              onPressed: busy ? null : _discard,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(placeName ?? 'Your shots', overflow: TextOverflow.ellipsis),
                Text(
                  _shooting
                      ? (shots.isEmpty ? 'Opening the camera…' : '${_count(shots.length)} · camera reopening…')
                      : shots.length > 1
                          ? '${_count(shots.length)} · tap the ones to keep'
                          : _count(shots.length),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          body: shots.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (shotFrame != null)
                      Expanded(
                        flex: 2,
                        child: _Pane(
                          key: const Key('shotFrame'),
                          label: frameLabel,
                          child: _Photo(key: ValueKey(shotFrame.path), path: shotFrame.path),
                        ),
                      ),
                    Expanded(
                      flex: 3,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: shots.length,
                        onPageChanged: (i) => setState(() => _current = i),
                        itemBuilder: (context, i) {
                          final shot = shots[i];
                          return _Pane(
                            label: 'Shot ${i + 1} of ${shots.length}',
                            onTap: busy ? null : () => _toggle(shot),
                            trailing: _KeepMark(kept: _kept.contains(shot.path), large: true),
                            child: _Photo(path: shot.path),
                          );
                        },
                      ),
                    ),
                    if (shots.length > 1)
                      _Strip(
                        shots: shots,
                        kept: _kept,
                        current: _current,
                        onTap: (i) {
                          setState(() => _current = i);
                          _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                        },
                      ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._planTicks(placeName),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy || series == null ? null : _shoot,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take more'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy || _kept.isEmpty ? null : () => _keep(placeName),
                          icon: _saving
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check),
                          label: Text(_kept.isEmpty ? 'Pick to keep' : 'Keep ${_kept.length}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The ticks for the trip, above the buttons: "Mark done" when the place
  /// is on a day, else "Add to Day N", with "Mark it done" once ticked. Only
  /// the people who can edit the trip get them; the others see the stop's
  /// progress.
  List<Widget> _planTicks(String? placeName) {
    final plan = _livePlan;
    if (plan == null || _shooting || (_series?.shots.isEmpty ?? true)) return const [];
    final name = placeName ?? plan.stop?.name ?? 'this place';
    final progress = plan.progress;
    if (!ref.watch(canEditTripProvider(plan.trip.id))) {
      if (plan.stop == null) return const [];
      return [
        ListTile(
          key: const Key('shotPlanProgress'),
          dense: true,
          leading: Icon(plan.done ? Icons.check_circle : Icons.photo_library_outlined, color: Colors.white70),
          title: Text([name, ?progress].join(' · '), overflow: TextOverflow.ellipsis),
          subtitle: Text(plan.trip.title, style: const TextStyle(color: Colors.white60)),
        ),
      ];
    }
    Widget tick(String key, String title, List<String?> about, bool value, void Function(bool) onChanged) {
      final subtitle = [
        for (final part in about)
          if (part != null) part,
      ].join(' · ');
      return CheckboxListTile(
        key: Key(key),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        onChanged: _saving ? null : (v) => setState(() => onChanged(v ?? false)),
        title: Text(title, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
      );
    }

    if (plan.canMarkDone) {
      final elsewhere =
          plan.itemDay != null && plan.itemDay != plan.shotDayNumber ? 'planned for Day ${plan.itemDay}' : null;
      return [
        tick('shotPlanDone', 'Mark $name done', [progress, elsewhere, plan.trip.title], _markDone, (v) => _markDoneChoice = v),
      ];
    }
    if (!plan.canAddToDay) return const [];
    return [
      tick(
        'shotPlanAdd',
        'Add $name to Day ${plan.shotDayNumber}',
        [plan.trip.title, plan.stop == null ? 'not in the trip yet' : 'not on a day yet'],
        _addToDay,
        (v) => _addToDay = v,
      ),
      if (_addToDay) tick('shotPlanDone', 'Mark it done', [progress], _markDone, (v) => _markDoneChoice = v),
    ];
  }

  static String _count(int n) => n == 1 ? '1 shot' : '$n shots';
}

/// A photo fitted into its pane, decoded at about the screen's width so a
/// series of 12 MP shots doesn't fill the memory.
class _Photo extends StatelessWidget {
  const _Photo({super.key, required this.path, this.fit = BoxFit.contain, this.width});

  final String path;
  final BoxFit fit;
  final int? width;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final decodeWidth = width ?? (media.size.width * media.devicePixelRatio).round();
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: decodeWidth,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) =>
          const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40)),
    );
  }
}

/// One of the two panes, the frame or a shot, with a small label.
class _Pane extends StatelessWidget {
  const _Pane({super.key, required this.label, required this.child, this.onTap, this.trailing});

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
            if (trailing != null) Positioned(right: 8, top: 8, child: trailing!),
          ],
        ),
      ),
    );
  }
}

/// A check in a circle: filled when the shot is kept, an empty ring when not.
class _KeepMark extends StatelessWidget {
  const _KeepMark({required this.kept, this.large = false});

  final bool kept;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = large ? 36.0 : 22.0;
    return Semantics(
      label: kept ? 'Kept' : 'Not kept',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kept ? scheme.primary : Colors.black38,
          border: Border.all(color: kept ? scheme.primary : Colors.white70, width: 2),
        ),
        child: kept ? Icon(Icons.check, size: size * 0.65, color: scheme.onPrimary) : null,
      ),
    );
  }
}

/// The shots as thumbnails, to jump between them and see which are kept.
class _Strip extends StatelessWidget {
  const _Strip({required this.shots, required this.kept, required this.current, required this.onTap});

  final List<SeriesShot> shots;
  final Set<String> kept;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: shots.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            width: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: i == current ? scheme.primary : Colors.transparent, width: 2),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _Photo(path: shots[i].path, fit: BoxFit.cover, width: 160),
                ),
                if (kept.contains(shots[i].path))
                  const Positioned(right: 3, top: 3, child: _KeepMark(kept: true)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
