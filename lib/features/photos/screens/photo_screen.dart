import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/platform_media.dart';
import '../../../shared/theme/app_theme.dart';
import '../../camera/services/photo_edit_route.dart';
import '../../library/widgets/place_page_parts.dart' show FrameImage, framePath;
import '../../trip/providers/trip_providers.dart';
import '../providers/photos_providers.dart';

/// One photo next to the frame it was taken against (Photos tab, v0.4.0):
/// side by side when there's room, one above the other on a phone held
/// upright. **Edit** opens the editor on it; the place's name opens the place.
class PhotoScreen extends ConsumerWidget {
  final String photoId;

  const PhotoScreen({super.key, required this.photoId});

  Future<void> _edit(BuildContext context, WidgetRef ref, PhotoEntry entry) async {
    final frame = entry.frame;
    final reference = frame == null ? null : await framePath(ref, frame);
    if (!context.mounted) return;
    final photo = entry.photo;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(photoEntryProvider(photoId));
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.valueOrNull?.place?.name ?? 'Photo', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: entry.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load the photo: $e")),
        data: (entry) => entry == null
            ? const Center(child: Text('This photo was deleted.'))
            : _body(context, ref, entry),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PhotoEntry entry) {
    final theme = Theme.of(context);
    final photo = entry.photo;
    final frame = entry.frame;
    final trip = photo.tripId == null ? null : ref.watch(tripDetailProvider(photo.tripId!)).valueOrNull;

    Widget panel(String label, Widget image) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.trip.tea)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(color: theme.colorScheme.surfaceContainerHighest, child: image),
              ),
            ),
          ],
        );

    final shot = panel(
      entry.isEdit ? 'Edited' : 'Your shot',
      PlatformImage(
        photo.localPath,
        key: const Key('photoScreenShot'),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
    final framePanel = frame == null
        ? null
        : panel(
            'The frame',
            SizedBox.expand(
              key: const Key('photoScreenFrame'),
              child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: 1280, height: 720, child: FrameImage(frame: frame))),
            ),
          );

    final when = DateFormat('EEE, MMM d, y · HH:mm').format(entry.time);
    final details = [
      when,
      if (trip != null && trip.deletedAt == null) trip.title,
      if (entry.hasEdit) 'edited',
      if (photo.keepAsIs) 'kept as it is',
    ].join(' · ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                if (framePanel == null) return shot;
                final wide = c.maxWidth > c.maxHeight;
                return wide
                    ? Row(children: [
                        Expanded(child: shot),
                        const SizedBox(width: 12),
                        Expanded(child: framePanel),
                      ])
                    : Column(children: [
                        Expanded(flex: 3, child: shot),
                        const SizedBox(height: 12),
                        Expanded(flex: 2, child: framePanel),
                      ]);
              }),
            ),
            const SizedBox(height: 12),
            Text(details, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (entry.place != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/library/places/${Uri.encodeComponent(photo.placeKey)}'),
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('Open the place'),
                    ),
                  ),
                if (entry.place != null) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _edit(context, ref, entry),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
