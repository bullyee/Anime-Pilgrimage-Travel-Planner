import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/database_provider.dart';
import '../../library/providers/place_providers.dart';
import '../../poi/services/background_photo_save.dart' show galleryAlbum, rootMessengerKey;
import '../models/shot_series.dart';
import '../services/camera_overlay.dart';
import '../services/kept_shots.dart';

/// What the shots route (`/shots`) carries in its query: a new series to
/// shoot for a place and frame, or [seriesId], a series to pick from again
/// after Android killed the app.
class ShotSeriesArgs {
  final String? seriesId;
  final String? placeKey;
  final String? tripId;
  final String? referencePath;
  final String? referenceImageId;

  const ShotSeriesArgs({
    this.seriesId,
    this.placeKey,
    this.tripId,
    this.referencePath,
    this.referenceImageId,
  });

  /// The router has decoded the values already, so they're used as they are
  /// (see `PhotoEditArgs.fromQuery`, #84).
  static ShotSeriesArgs fromQuery(Map<String, String> query) => ShotSeriesArgs(
        seriesId: query['series'],
        placeKey: query['place'],
        tripId: query['trip'],
        referencePath: query['ref'],
        referenceImageId: query['refId'],
      );

  String get location => Uri(path: '/shots', queryParameters: {
        if (seriesId != null) 'series': seriesId!,
        if (placeKey != null) 'place': placeKey!,
        if (tripId != null) 'trip': tripId!,
        if (referencePath != null) 'ref': referencePath!,
        if (referenceImageId != null) 'refId': referenceImageId!,
      }).toString();
}

final shotSeriesStoreProvider = Provider<ShotSeriesStore>((ref) => ShotSeriesStore());

/// Several shots against one frame, then keep the ones you want (roadmap
/// v0.3.0, "Several shots, then pick").
///
/// The phone's camera app returns one photo per opening, so after each shot
/// the camera opens again with the frame still floating where the user left
/// it, and backing out of the camera ends the series. The shots then show
/// under the frame; the ones the user keeps are saved as shot, with no
/// editing on the spot, and the rest are deleted.
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
  ShotSeries? _series;
  final _kept = <String>{};
  final _pages = PageController();
  var _current = 0;
  var _shooting = false;
  var _saving = false;

  /// The latest write of the picks, so the next write or the series' deletion
  /// waits for it.
  Future<void> _writes = Future.value();

  ShotSeriesStore get _store => ref.read(shotSeriesStoreProvider);

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
        _kept.addAll(series.kept);
        _current = series.shots.length - 1;
        _preselect();
      });
      _showCurrent();
      return;
    }
    final series = await _store.create(
      placeKey: args.placeKey,
      tripId: args.tripId,
      referencePath: args.referencePath,
      referenceImageId: args.referenceImageId,
    );
    if (!mounted) return;
    setState(() => _series = series);
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
    var series = start;
    var floating = false;
    final reference = series.referencePath;
    if (reference != null && await CameraOverlay.canDrawOverlays()) {
      floating = await CameraOverlay.show(reference);
    }
    String? error;
    try {
      while (mounted) {
        final path = await _openCamera();
        if (path == null) break;
        series = await _store.addShot(series, path);
        if (!mounted) break;
        final updated = series;
        setState(() {
          _series = updated;
          _current = updated.shots.length - 1;
        });
        _showCurrent();
      }
    } on PlatformException catch (e) {
      error = 'Camera unavailable: ${e.message ?? e.code}';
    } finally {
      if (floating) await CameraOverlay.hide();
    }
    if (!mounted) return;
    setState(() {
      _shooting = false;
      _preselect();
    });
    if (error != null) rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(error)));
    if (series.shots.isEmpty) {
      // Backed out without a shot: nothing to pick from.
      await _discardSeries(series.id);
      _leave();
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
  void _saveKept() {
    final series = _series?.withKept(_kept);
    if (series == null) return;
    _series = series;
    _writes = _writes.then((_) => _store.saveKept(series, series.kept)).then<void>((_) {}, onError: (Object _) {
      // Only the picks are lost if Android kills the app; the shots are safe.
    });
  }

  /// Deletes the series once any pending write of the picks is done, so that
  /// write can't bring its folder back.
  Future<void> _discardSeries(String id) async {
    await _writes;
    await _store.discard(id);
  }

  void _showCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(_current);
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
    final series = _series;
    if (series == null || _kept.isEmpty || _saving || _shooting) return;
    setState(() => _saving = true);
    final kept = [
      for (final shot in series.shots)
        if (_kept.contains(shot.path)) shot,
    ];
    final result = await saveKeptShots(
      series: series,
      kept: kept,
      places: ref.read(placeRepositoryProvider),
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
    await _discardSeries(series.id);
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(_savedMessage(result, kept.length, series.placeKey == null ? null : placeName ?? 'the place'))),
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
    final reference = series?.referencePath ?? widget.args.referencePath;
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
                    if (reference != null)
                      Expanded(
                        flex: 2,
                        child: _Pane(label: 'Frame', child: _Photo(path: reference)),
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
            child: Padding(
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
          ),
        ),
      ),
    );
  }

  static String _count(int n) => n == 1 ? '1 shot' : '$n shots';
}

/// A photo fitted into its pane, decoded at about the screen's width so a
/// series of 12 MP shots doesn't fill the memory.
class _Photo extends StatelessWidget {
  const _Photo({required this.path, this.fit = BoxFit.contain, this.width});

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
  const _Pane({required this.label, required this.child, this.onTap, this.trailing});

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
