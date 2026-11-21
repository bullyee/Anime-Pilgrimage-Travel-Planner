import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/theme/app_theme.dart';
import '../../camera/providers/shooting_core_providers.dart';
import '../../camera/services/anime_camera_launcher.dart' show editPhotoFromGallery;
import '../../camera/screens/photos_to_edit_screen.dart';
import '../../library/widgets/place_page_parts.dart' show FrameImage;
import '../../trip/providers/trip_providers.dart';
import '../providers/photos_providers.dart';
import '../services/share_image.dart';
import 'share_image_screen.dart';

/// What the Photos tab shows.
enum PhotosFilter {
  all,

  /// The photos kept on the spot and not edited yet (was its own screen).
  toEdit,

  /// The photos shot against a frame, each under its frame, to pick a few
  /// for a share image.
  pairs;

  static PhotosFilter fromQuery(String? value) => switch (value) {
        'edit' => toEdit,
        'pairs' => pairs,
        _ => all,
      };

  String get location => switch (this) {
        all => '/photos',
        toEdit => '/photos?filter=edit',
        pairs => '/photos?filter=pairs',
      };
}

enum _GroupBy { day, place }

/// "Today", "Yesterday", "Sun, Nov 8", or with the year when it isn't this one.
String photoDayName(DateTime day, DateTime now) {
  final d = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (d == 0) return 'Today';
  if (d == 1) return 'Yesterday';
  return DateFormat(day.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(day);
}

/// The Photos tab (roadmap v0.4.0): every photo you've taken, newest first,
/// by day (with the trip) or by place; each opens next to its frame. **To
/// edit** is a filter here. Photos stay filed under their place, so the place
/// page still shows them: this is another way in.
///
/// **Pairs** shows the photos shot against a frame under their frames, with
/// the place and spot, newest first; Share image picks up to
/// [shareImageMax] of them for one image ([ShareImageScreen]).
class PhotosScreen extends ConsumerStatefulWidget {
  final PhotosFilter filter;

  const PhotosScreen({super.key, this.filter = PhotosFilter.all});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  _GroupBy _groupBy = _GroupBy.day;

  /// The pairs picked for a share image, in the order picked; null when not
  /// picking.
  List<String>? _picks;

  /// The filter lives in the location (`/photos?filter=edit`), so Home's
  /// "N photos to edit" always lands on To edit.
  PhotosFilter get _filter => widget.filter;

  @override
  void didUpdateWidget(PhotosScreen old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) _picks = null;
  }

  void _show(PhotosFilter filter) {
    if (filter != _filter) context.go(filter.location);
  }

  Widget _filters() {
    final l10n = context.l10n;
    final toEdit = ref.watch(photosToEditStreamProvider).valueOrNull?.length ?? 0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('photosFilterAll'),
            label: Text(l10n.photosFilterAll),
            selected: _filter == PhotosFilter.all,
            onSelected: (_) => _show(PhotosFilter.all),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('photosFilterToEdit'),
            label: Text(toEdit == 0 ? l10n.photosFilterToEdit : l10n.photosFilterToEditCount(toEdit)),
            selected: _filter == PhotosFilter.toEdit,
            onSelected: (_) => _show(PhotosFilter.toEdit),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('photosFilterPairs'),
            label: Text(l10n.photosFilterPairs),
            selected: _filter == PhotosFilter.pairs,
            onSelected: (_) => _show(PhotosFilter.pairs),
          ),
        ],
      ),
    );
  }

  void _togglePick(PhotoEntry entry) {
    final picks = _picks;
    if (picks == null) return;
    final next = toggleSharePick(picks, entry.photo.id);
    if (next.refused) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.photosShareMax(shareImageMax))));
      return;
    }
    setState(() => _picks = next.selected);
  }

  void _makeImage(List<PhotoEntry> pairs) {
    final picks = _picks;
    if (picks == null || picks.isEmpty) return;
    final byId = {for (final e in pairs) e.photo.id: e};
    final picked = [for (final id in picks) ?byId[id]];
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShareImageScreen(pairs: picked)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_filter == PhotosFilter.toEdit) {
      return PhotosToEditScreen(title: l10n.navPhotos, header: _filters());
    }
    final photos = ref.watch(allPhotosProvider);
    final pairsMode = _filter == PhotosFilter.pairs;
    final pairs = pairsMode ? shotPairs(photos.valueOrNull ?? const []) : const <PhotoEntry>[];
    if (_picks != null) _picks = [for (final id in _picks!) if (pairs.any((e) => e.photo.id == id)) id];
    final picks = _picks;
    return PopScope(
      canPop: picks == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _picks = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navPhotos),
          actions: [
            if (pairsMode)
              picks == null
                  ? TextButton.icon(
                      key: const Key('photosShareImage'),
                      onPressed: pairs.isEmpty ? null : () => setState(() => _picks = const []),
                      icon: const Icon(Icons.collections_outlined),
                      label: Text(l10n.photosShareImage),
                    )
                  : TextButton(
                      key: const Key('photosShareCancel'),
                      onPressed: () => setState(() => _picks = null),
                      child: Text(l10n.commonCancel),
                    )
            else ...[
              IconButton(
                tooltip: l10n.photosEditFromGallery,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: () => editPhotoFromGallery(context, ref),
              ),
              PopupMenuButton<_GroupBy>(
                tooltip: l10n.photosGroupBy,
                icon: const Icon(Icons.sort),
                initialValue: _groupBy,
                onSelected: (v) => setState(() => _groupBy = v),
                itemBuilder: (context) => [
                  PopupMenuItem(value: _GroupBy.day, child: Text(l10n.photosByDay)),
                  PopupMenuItem(value: _GroupBy.place, child: Text(l10n.photosByPlace)),
                ],
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            _filters(),
            Expanded(
              child: photos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(l10n.photosLoadFailed('$e'))),
                data: (entries) => pairsMode
                    ? (pairs.isEmpty ? _Empty(title: l10n.photosEmptyTitle, body: l10n.photosPairsEmpty) : _pairsGrid(pairs))
                    : entries.isEmpty
                        ? _Empty(title: l10n.photosEmptyTitle, body: l10n.photosEmptyBody)
                        : _grid(context, entries),
              ),
            ),
          ],
        ),
        bottomNavigationBar: picks == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    key: const Key('photosShareMake'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: picks.isEmpty ? null : () => _makeImage(pairs),
                    child: Text(l10n.photosShareMake(picks.length)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _pairsGrid(List<PhotoEntry> pairs) {
    final picks = _picks;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 600 ? 3 : 2;
            const gap = 10.0;
            final tile = (c.maxWidth - 24 - (cols - 1) * gap) / cols;
            return GridView.builder(
              key: const Key('photosPairs'),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: gap,
                mainAxisExtent: math.max(1, tile * 9 / 16 * 2 + 2 + 46),
              ),
              itemCount: pairs.length,
              itemBuilder: (context, i) {
                final entry = pairs[i];
                return _PairCard(
                  entry: entry,
                  picked: picks?.contains(entry.photo.id),
                  onTap: picks != null ? () => _togglePick(entry) : () => context.push('/photo/${Uri.encodeComponent(entry.photo.id)}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<PhotoEntry> entries) {
    final now = DateTime.now();
    final sections = switch (_groupBy) {
      _GroupBy.day => [
          for (final (day, group) in groupEntriesByDay(entries))
            (_DayHeader(key: ValueKey('day:$day'), day: photoDayName(day, now), group: group) as Widget, group),
        ],
      _GroupBy.place => [
          for (final (place, group) in groupEntriesByPlace(entries))
            (
              _Header(
                key: ValueKey('place:${group.first.photo.placeKey}'),
                text: place?.name ?? context.l10n.photosPlaceGone,
                count: group.length,
              ) as Widget,
              group,
            ),
        ],
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: CustomScrollView(
          slivers: [
            for (final (header, group) in sections) ...[
              SliverToBoxAdapter(child: header),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: group.length,
                  itemBuilder: (context, i) => _Tile(entry: group[i]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final int count;

  const _Header({super.key, required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(color: theme.trip.tea, fontWeight: FontWeight.w700),
            ),
          ),
          Text('$count', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A day's header, with the trip when all its photos are filed under one.
class _DayHeader extends ConsumerWidget {
  final String day;
  final List<PhotoEntry> group;

  const _DayHeader({super.key, required this.day, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = group.map((e) => e.photo.tripId).toSet();
    final tripId = trips.length == 1 ? trips.single : null;
    final trip = tripId == null ? null : ref.watch(tripDetailProvider(tripId)).valueOrNull;
    return _Header(
      text: [day, if (trip != null && trip.deletedAt == null) trip.title].join(' · '),
      count: group.length,
    );
  }
}

class _Tile extends StatelessWidget {
  final PhotoEntry entry;

  const _Tile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = entry.photo;
    final label = [
      entry.place?.name ?? 'A photo',
      DateFormat('MMM d, HH:mm').format(entry.time),
      if (entry.isEdit) 'edited',
      if (entry.toEdit) 'to edit',
    ].join(', ');
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('photo:${photo.id}'),
        onTap: () => context.push('/photo/${Uri.encodeComponent(photo.id)}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlatformImage(
                photo.localPath,
                fit: BoxFit.cover,
                cacheWidth: 320,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (entry.isEdit || entry.toEdit)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    child: Icon(entry.isEdit ? Icons.auto_fix_high : Icons.edit_outlined, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A photo under the frame it was shot against, with the place and spot;
/// a tick in the corner while picking pairs for a share image.
class _PairCard extends StatelessWidget {
  final PhotoEntry entry;

  /// Whether it's picked, while picking; null otherwise.
  final bool? picked;
  final VoidCallback onTap;

  const _PairCard({required this.entry, required this.picked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final caption = pairCaption(entry, placeFallback: context.l10n.photosPlaceGone);
    final cut = caption.indexOf(' › ');
    final place = cut < 0 ? caption : caption.substring(0, cut);
    final spot = cut < 0 ? null : caption.substring(cut + 3);
    final broken = ColoredBox(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined));
    final on = picked ?? false;
    return Semantics(
      button: true,
      selected: picked,
      label: caption,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('pair:${entry.photo.id}'),
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: AspectRatio(aspectRatio: 16 / 9, child: FrameImage(frame: entry.frame!, cacheWidth: 400)),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: PlatformImage(entry.photo.localPath, fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, _, _) => broken),
                  ),
                ),
                const SizedBox(height: 4),
                Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                if (spot != null)
                  Text(spot, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ),
            if (picked != null)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: on ? theme.trip.tea : Colors.black38,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: on ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String body;

  const _Empty({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: theme.trip.tea),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
