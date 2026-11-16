import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/theme/app_theme.dart';
import '../../library/providers/place_providers.dart';
import '../../library/widgets/place_page_parts.dart' show framePath;
import '../../trip/providers/trip_providers.dart';
import '../models/shooting_core_models.dart';
import '../providers/shooting_core_providers.dart';
import '../services/photo_edit_route.dart';

/// When a photo to edit was taken, as the list sorts and groups it.
DateTime photoTime(Photo photo) => photo.takenAt ?? photo.createdAt;

/// The photos to edit split by the day they were taken, newest day first,
/// keeping the order within a day.
List<(DateTime, List<PhotoToEditItem>)> groupPhotosByDay(List<PhotoToEditItem> items) {
  final groups = <DateTime, List<PhotoToEditItem>>{};
  for (final item in items) {
    final t = photoTime(item.photo);
    groups.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(item);
  }
  return [for (final e in groups.entries) (e.key, e.value)]..sort((a, b) => b.$1.compareTo(a.$1));
}

/// Photos to edit (roadmap v0.3.0): the photos kept on the spot as they were
/// shot, waiting to be edited at home. Tapping one opens the editor; once an
/// edit of it is saved it leaves the list. "Keep as it is" takes a photo off
/// the list without editing; a long press selects several to keep at once.
///
/// Since v0.4.0 it's the Photos tab's **To edit** filter, which passes its
/// [title] and its filter chips as [header].
class PhotosToEditScreen extends ConsumerStatefulWidget {
  final String title;
  final Widget? header;

  const PhotosToEditScreen({super.key, this.title = 'Photos to edit', this.header});

  @override
  ConsumerState<PhotosToEditScreen> createState() => _PhotosToEditScreenState();
}

class _PhotosToEditScreenState extends ConsumerState<PhotosToEditScreen> {
  final _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _edit(PhotoToEditItem item) async {
    final photo = item.photo;
    final frame = item.referenceFrame;
    final reference = frame == null ? null : await framePath(ref, frame);
    if (!mounted) return;
    context.push(
      PhotoEditArgs(
        path: photo.localPath,
        placeKey: photo.placeKey,
        tripId: photo.tripId,
        photoId: photo.id,
        referencePath: reference,
        referenceImageId: reference == null ? null : frame?.id,
      ).location,
    );
  }

  /// Takes [ids] off the list without editing them, with Undo.
  Future<void> _keepAsIs(List<String> ids) async {
    final db = ref.read(databaseProvider);
    final service = ref.read(pilgrimageShootingServiceProvider);
    final places = ref.read(placeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    for (final id in ids) {
      await service.markPhotoAsKeptAsIs(db, id);
    }
    if (!mounted) return;
    setState(() => _selected.removeAll(ids));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ids.length == 1 ? 'Kept as it is.' : 'Kept ${ids.length} photos as they are.'),
          // Goes by itself: with an action it would stay until dismissed.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final id in ids) {
                await places.updatePhoto(PhotosCompanion(id: Value(id), keepAsIs: const Value(false)));
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosToEditStreamProvider);
    final items = photos.valueOrNull ?? const <PhotoToEditItem>[];
    // Photos that left the list (edited elsewhere) can't stay selected.
    _selected.retainWhere((id) => items.any((i) => i.photo.id == id));

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('${_selected.length} selected'),
                actions: [
                  TextButton.icon(
                    key: const Key('photosToEditKeepSelected'),
                    onPressed: () => _keepAsIs(_selected.toList()),
                    icon: const Icon(Icons.done_all),
                    label: Text(_selected.length == 1 ? 'Keep as it is' : 'Keep as they are'),
                  ),
                ],
              )
            : AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            ?widget.header,
            Expanded(
              child: photos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Couldn't load the photos: $e")),
                data: (items) => items.isEmpty ? const _Empty() : _list(context, items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<PhotoToEditItem> items) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    String dayName(DateTime day) {
      final d = DateTime(today.year, today.month, today.day).difference(day).inDays;
      if (d == 0) return 'Today';
      if (d == 1) return 'Yesterday';
      return DateFormat(day.year == today.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(day);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Kept on the spot as they were shot. Edit them here, or keep them as they are.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            for (final (day, group) in groupPhotosByDay(items)) ...[
              _DayHeader(day: dayName(day), tripId: _sameTrip(group)),
              for (final item in group)
                _PhotoTile(
                  key: ValueKey('photoToEdit:${item.photo.id}'),
                  item: item,
                  selecting: _selecting,
                  selected: _selected.contains(item.photo.id),
                  onTap: () => _selecting ? _toggle(item.photo.id) : _edit(item),
                  onLongPress: () => _toggle(item.photo.id),
                  onKeep: () => _keepAsIs([item.photo.id]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// The trip every photo of [group] is filed under, if they share one.
  static String? _sameTrip(List<PhotoToEditItem> group) {
    final trips = group.map((i) => i.photo.tripId).toSet();
    return trips.length == 1 ? trips.single : null;
  }
}

class _DayHeader extends ConsumerWidget {
  final String day;
  final String? tripId;

  const _DayHeader({required this.day, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tripId = this.tripId;
    final trip = tripId == null ? null : ref.watch(tripDetailProvider(tripId)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        [day, if (trip != null && trip.deletedAt == null) trip.title].join(' · '),
        style: theme.textTheme.titleSmall?.copyWith(color: theme.trip.tea, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoToEditItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onKeep;

  const _PhotoTile({
    super.key,
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final photo = item.photo;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: PlatformImage(
          photo.localPath,
          fit: BoxFit.cover,
          cacheWidth: 216,
          errorBuilder: (_, _, _) => ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
    return ListTile(
      selected: selected,
      selectedTileColor: p.teaSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 8,
      leading: Stack(
        children: [
          thumb,
          if (selecting)
            Positioned(
              right: 2,
              top: 2,
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? p.tea : Colors.white,
                size: 22,
              ),
            ),
        ],
      ),
      title: Text(item.place?.name ?? 'A photo', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [DateFormat.Hm().format(photoTime(photo)), if (item.referenceFrame != null) 'with its frame'].join(' · '),
      ),
      trailing: selecting
          ? null
          : IconButton(tooltip: 'Keep as it is', icon: const Icon(Icons.done), onPressed: onKeep),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: p.tea),
            const SizedBox(height: 12),
            Text('Nothing to edit', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Photos you keep on the spot wait here until you edit them or keep them as they are.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
