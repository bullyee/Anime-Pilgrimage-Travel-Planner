import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/platform_media.dart';
import '../../../shared/theme/app_theme.dart';
import '../../camera/providers/shooting_core_providers.dart';
import '../../camera/services/anime_camera_launcher.dart' show editPhotoFromGallery;
import '../../camera/screens/photos_to_edit_screen.dart';
import '../../trip/providers/trip_providers.dart';
import '../providers/photos_providers.dart';

/// What the Photos tab shows.
enum PhotosFilter {
  all,

  /// The photos kept on the spot and not edited yet (was its own screen).
  toEdit;

  static PhotosFilter fromQuery(String? value) => value == 'edit' ? toEdit : all;
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
class PhotosScreen extends ConsumerStatefulWidget {
  final PhotosFilter filter;

  const PhotosScreen({super.key, this.filter = PhotosFilter.all});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  _GroupBy _groupBy = _GroupBy.day;

  /// The filter lives in the location (`/photos?filter=edit`), so Home's
  /// "N photos to edit" always lands on To edit.
  PhotosFilter get _filter => widget.filter;

  void _show(PhotosFilter filter) {
    if (filter != _filter) context.go(filter == PhotosFilter.toEdit ? '/photos?filter=edit' : '/photos');
  }

  Widget _filters() {
    final toEdit = ref.watch(photosToEditStreamProvider).valueOrNull?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('photosFilterAll'),
            label: const Text('All'),
            selected: _filter == PhotosFilter.all,
            onSelected: (_) => _show(PhotosFilter.all),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('photosFilterToEdit'),
            label: Text(toEdit == 0 ? 'To edit' : 'To edit · $toEdit'),
            selected: _filter == PhotosFilter.toEdit,
            onSelected: (_) => _show(PhotosFilter.toEdit),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_filter == PhotosFilter.toEdit) {
      return PhotosToEditScreen(title: 'Photos', header: _filters());
    }
    final photos = ref.watch(allPhotosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos'),
        actions: [
          IconButton(
            tooltip: 'Edit a photo from the gallery',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => editPhotoFromGallery(context, ref),
          ),
          PopupMenuButton<_GroupBy>(
            tooltip: 'Group by',
            icon: const Icon(Icons.sort),
            initialValue: _groupBy,
            onSelected: (v) => setState(() => _groupBy = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _GroupBy.day, child: Text('By day')),
              PopupMenuItem(value: _GroupBy.place, child: Text('By place')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: photos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Couldn't load the photos: $e")),
              data: (entries) => entries.isEmpty ? const _Empty() : _grid(context, entries),
            ),
          ),
        ],
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
                text: place?.name ?? 'A place no longer in your library',
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

class _Empty extends StatelessWidget {
  const _Empty();

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
            Text('No photos yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'The photos you take with Shoot, or from a place or a stop, show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
