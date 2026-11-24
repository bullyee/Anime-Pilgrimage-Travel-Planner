import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/platform_media.dart';
import '../../library/widgets/place_page_parts.dart' show framePath;
import '../../poi/services/background_photo_save.dart';
import '../../trip/providers/trip_providers.dart';
import '../providers/photos_providers.dart';
import '../services/share_image.dart';

/// The share image for [pairs] (picked on Photos → Pairs): a preview, its
/// title (the trip's and the month by default), grid or stacked, Save
/// (to the phone's gallery, the editor's way: [BackgroundPhotoSaves]) and
/// Share (the system's share sheet).
class ShareImageScreen extends ConsumerStatefulWidget {
  final List<PhotoEntry> pairs;

  const ShareImageScreen({super.key, required this.pairs});

  @override
  ConsumerState<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends ConsumerState<ShareImageScreen> {
  final _title = TextEditingController();
  bool _titleTouched = false;
  ShareImageLayout _layout = ShareImageLayout.grid;
  List<SharePair>? _pairs;
  Uint8List? _bytes;
  Object? _error;
  Timer? _debounce;
  int _generation = 0;

  /// The render [_bytes] came from, behind [_generation] while a newer one
  /// (a new title or layout) is still drawing.
  int _bytesGeneration = -1;
  Future<void>? _rendering;

  /// Save or Share is under way.
  bool _exporting = false;

  /// The trip most of the pairs are filed under, for the title.
  late final String? _tripId = () {
    final counts = <String, int>{};
    for (final e in widget.pairs) {
      if (e.photo.tripId case final id?) counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }();

  @override
  void initState() {
    super.initState();
    // It reads the strings, which aren't there before the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    for (final pair in _pairs ?? const <SharePair>[]) {
      pair.frame.dispose();
      pair.photo.dispose();
    }
    super.dispose();
  }

  String _defaultTitle(String? tripTitle) {
    final newest = widget.pairs.map((e) => e.time).reduce((a, b) => a.isAfter(b) ? a : b);
    return defaultShareTitle(tripTitle: tripTitle, fallback: context.l10n.shareImageDefaultTitle, newest: newest);
  }

  static Future<ui.Image?> _decode(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(await readMediaBytes(path), targetWidth: 1280);
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// Reads every pair's frame and photo once; a pair missing either is
  /// left out.
  Future<void> _load() async {
    final placeFallback = context.l10n.photosPlaceGone;
    final pairs = <SharePair>[];
    var kept = false;
    try {
      for (final e in widget.pairs) {
        // Left while decoding: ref can't be used any more.
        if (!mounted) return;
        final framePathOf = await framePath(ref, e.frame!);
        final frame = framePathOf == null ? null : await _decode(framePathOf);
        final photo = await _decode(e.photo.localPath);
        if (frame != null && photo != null) {
          pairs.add(SharePair(frame: frame, photo: photo, caption: pairCaption(e, placeFallback: placeFallback)));
        } else {
          frame?.dispose();
          photo?.dispose();
        }
      }
      if (!mounted) return;
      kept = true;
      setState(() => _pairs = pairs);
    } finally {
      if (!kept) {
        for (final pair in pairs) {
          pair.frame.dispose();
          pair.photo.dispose();
        }
      }
    }
    _render();
  }

  Future<void> _render() => _rendering = _draw();

  Future<void> _draw() async {
    final pairs = _pairs;
    if (pairs == null) return;
    final generation = ++_generation;
    final l10n = context.l10n;
    try {
      if (pairs.isEmpty) throw StateError(l10n.shareImageNothing);
      final bytes = await renderShareImage(
        pairs,
        title: _title.text.trim(),
        subtitle: l10n.shareImageSubtitle(pairs.length),
        layout: _layout,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _bytes = bytes;
          _bytesGeneration = generation;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    }
  }

  void _onTitle(String _) {
    _titleTouched = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _render);
  }

  /// The title as a file name, at most 200 bytes (file systems take 255,
  /// and a CJK character is three).
  String get _fileName {
    var name = _title.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    while (utf8.encode(name).length > 200) {
      name = name.characters.skipLast(1).toString();
    }
    return '${name.isEmpty ? 'share' : name}.jpg';
  }

  /// The image as it is now: a title still being typed or a layout still
  /// drawing is waited for, so the export isn't the one before.
  Future<Uint8List?> _current() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      await _render();
    }
    while (mounted && _bytesGeneration != _generation && _rendering != null) {
      final rendering = _rendering!;
      await rendering;
      if (identical(rendering, _rendering)) break;
    }
    return _bytesGeneration == _generation ? _bytes : null;
  }

  Future<void> _save() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _current();
      if (bytes == null || !mounted) return;
      ref.read(backgroundPhotoSavesProvider.notifier).save(toGallery: true, render: () async => bytes);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _share() async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final bytes = await _current();
      if (bytes == null) return;
      final XFile file;
      if (kIsWeb) {
        file = XFile.fromData(bytes, name: _fileName, mimeType: 'image/jpeg');
      } else {
        // A folder per share, so one still being read isn't overwritten.
        final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share_images', '${DateTime.now().microsecondsSinceEpoch}'));
        await dir.create(recursive: true);
        final out = File(p.join(dir.path, _fileName));
        await out.writeAsBytes(bytes, flush: true);
        file = XFile(out.path, mimeType: 'image/jpeg');
      }
      await SharePlus.instance.share(ShareParams(files: [file], text: _title.text.trim(), downloadFallbackEnabled: true));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareImageFailed('$e'))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tripId = _tripId;
    final trip = tripId == null ? null : ref.watch(tripDetailProvider(tripId));
    if (!_titleTouched && (trip == null || !trip.isLoading)) {
      final title = _defaultTitle(trip?.valueOrNull?.title);
      if (_title.text != title) {
        // Not while building: the field listens to the controller.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _titleTouched || _title.text == title) return;
          _title.text = title;
          _render();
        });
      }
    }
    final ready = _bytes != null && !_exporting;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shareImageTitle),
            Text(l10n.shareImagePairs(widget.pairs.length), style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('shareImageShare'),
            tooltip: l10n.shareImageShare,
            onPressed: ready ? _share : null,
            icon: const Icon(Icons.share_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              key: const Key('shareImageSave'),
              onPressed: ready ? _save : null,
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.shareImageSave),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF0E1311),
                child: Center(
                  child: _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.shareImageFailed('$_error'), style: const TextStyle(color: Colors.white70)),
                        )
                      : _bytes == null
                          ? const CircularProgressIndicator()
                          : InteractiveViewer(
                              maxScale: 4,
                              child: Image.memory(_bytes!, key: const Key('shareImagePreview'), fit: BoxFit.contain, gaplessPlayback: true),
                            ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<ShareImageLayout>(
                    key: const Key('shareImageLayout'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ShareImageLayout.grid, icon: const Icon(Icons.grid_view), label: Text(l10n.shareImageGrid)),
                      ButtonSegment(value: ShareImageLayout.stacked, icon: const Icon(Icons.view_agenda_outlined), label: Text(l10n.shareImageStacked)),
                    ],
                    selected: {_layout},
                    onSelectionChanged: (v) {
                      setState(() => _layout = v.first);
                      _render();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('shareImageTitleField'),
                    controller: _title,
                    decoration: InputDecoration(labelText: l10n.shareImageTitleField, isDense: true),
                    onChanged: _onTitle,
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
