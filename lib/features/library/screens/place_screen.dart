import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/name_dialog.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../trip/controllers/trip_stops_controller.dart';
import '../../trip/models/trip_summary.dart';
import '../../trip/providers/trip_list_providers.dart';
import '../controllers/library_controller.dart';
import '../controllers/place_controller.dart';
import '../models/library_entry.dart';
import '../providers/library_providers.dart';
import '../providers/place_providers.dart';
import '../widgets/label_widgets.dart';
import '../widgets/trip_picker.dart';

/// One place in the library: its anime frames first, with the camera one
/// tap away, then its facts, and then what is only the user's own: their
/// note, their visits and their photos.
class PlaceScreen extends ConsumerStatefulWidget {
  final String placeKey;

  const PlaceScreen({super.key, required this.placeKey});

  @override
  ConsumerState<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends ConsumerState<PlaceScreen> {
  int _frame = 0;

  String get _key => widget.placeKey;
  PlaceController get _place => ref.read(placeControllerProvider.notifier);

  void _report(AppResult<dynamic> result, [String? ok]) {
    if (!mounted) return;
    // The newest outcome replaces the one on screen instead of queueing.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    switch (result) {
      case Failure(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error)));
      case Success():
        if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeAsync = ref.watch(placeDetailProvider(_key));
    final place = placeAsync.valueOrNull;
    if (place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: placeAsync.isLoading ? const CircularProgressIndicator() : const Text('This place is no longer in your library.'),
        ),
      );
    }
    final frames = ref.watch(placeReferenceImagesProvider(_key)).valueOrNull ?? const <NewReferenceImage>[];
    final framesOnDevice = [for (final f in frames) if (f.localPath?.isNotEmpty ?? false) f];
    if (_frame >= framesOnDevice.length) _frame = 0;
    final current = framesOnDevice.isEmpty ? null : framesOnDevice[_frame];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit the facts',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/library/places/${Uri.encodeComponent(_key)}/edit'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (action) => _onMenu(action, place, current),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'frames', child: Text('Add anime frames')),
              if (current != null) const PopupMenuItem(value: 'cover', child: Text('Use this frame as the cover')),
              PopupMenuItem(value: 'remove', child: Text(place.visibility == 'saved' ? 'Remove from library' : 'Save to library')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _FrameHero(
            frames: framesOnDevice,
            index: _frame,
            onPage: (i) => setState(() => _frame = i),
            onAdd: () async => _report(await _place.addFramesFromGallery(_key)),
            onOpen: (i) => _openFrame(framesOnDevice, i, place),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Actions(
                  frame: current,
                  onShoot: () => shootWithReference(context, ref, placeKey: _key, referencePath: current?.localPath, referenceImageId: current?.id),
                  onFloat: current == null ? null : () => floatReferenceImage(context, current.localPath!),
                  onDirections: () => _directions(place),
                  onAddToTrip: () => _addToTrip(place),
                ),
                const SizedBox(height: 16),
                _TitleBlock(place: place, placeKey: _key),
                const SizedBox(height: 8),
                _VisitsRow(placeKey: _key, onHere: () async {
                  final result = await _place.addVisitToday(_key);
                  _report(result, switch (result) {
                    Success(value: false) => 'Today is on record already.',
                    _ => 'Added a visit for today.',
                  });
                }),
                const SizedBox(height: 14),
                _FactsCard(place: place),
                const SizedBox(height: 14),
                _TripsCard(placeKey: _key),
                _NoteCard(place: place, onSave: (note) async => _report(await _place.setNote(_key, note), 'Saved your note.')),
                const SizedBox(height: 14),
                _PhotosCard(
                  placeKey: _key,
                  frames: frames,
                  onAdd: () async => _report(await _place.addPhotosFromGallery(_key)),
                ),
                const SizedBox(height: 14),
                _LocationCard(place: place),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(String action, Place place, NewReferenceImage? current) async {
    switch (action) {
      case 'frames':
        _report(await _place.addFramesFromGallery(_key));
      case 'cover':
        _report(await _place.setCover(_key, current!.localPath!), 'This frame is now the cover.');
      case 'remove':
        if (place.visibility != 'saved') {
          _report(await ref.read(libraryControllerProvider.notifier).saveToLibrary(_key), 'Saved to your library.');
          return;
        }
        final entry = ref.read(libraryEntriesProvider).valueOrNull?.where((e) => e.place.placeKey == _key).firstOrNull;
        if (entry == null) return;
        if (entry.tripIds.isEmpty) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete “${place.name}”?'),
              content: const Text('Its frames, notes and photos are deleted with it. Your labels stay.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
              ],
            ),
          );
          if (confirmed != true) return;
        }
        final result = await ref.read(libraryControllerProvider.notifier).removeFromLibrary(entry);
        if (!mounted) return;
        if (result case Success(value: RemovedPlace.deleted)) {
          context.pop();
        }
        _report(result, entry.tripIds.isEmpty ? 'Deleted ${place.name}.' : 'Removed from your library. Its trips keep it.');
    }
  }

  Future<void> _directions(Place place) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${place.lat},${place.lng}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      _report(const Failure("Couldn't open a maps app."));
    }
  }

  Future<void> _addToTrip(Place place) async {
    final inTrips = ref.read(libraryEntriesProvider).valueOrNull?.where((e) => e.place.placeKey == _key).firstOrNull?.tripIds ?? const {};
    final trip = await pickTripToAddTo(context, full: inTrips, allowRepeat: true);
    if (trip == null || !mounted) return;
    final again = inTrips.contains(trip.trip.id);
    String? name;
    if (again) {
      // A second stop of the same place needs a name of its own to tell the two apart.
      name = await askName(
        context,
        title: 'Add “${place.name}” again?',
        action: 'Add a second stop',
        initial: '${place.name} (2)',
        message: '${trip.trip.title} already has it. A second stop gets its own plan, for example one visit '
            'at dusk and one at night. Name it so the two are easy to tell apart.',
      );
      if (name == null || !mounted) return;
    }
    final result = await ref.read(tripStopsControllerProvider.notifier).addFromLibrary(
          tripId: trip.trip.id,
          placeKeys: [_key],
          repeat: again,
          names: {if (name != null) _key: name},
        );
    _report(result, 'Added to ${trip.trip.title}. It waits in the backlog until you plan it.');
  }

  Future<void> _openFrame(List<NewReferenceImage> frames, int index, Place place) async {
    final frame = frames[index];
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ImageViewer(
        path: frame.localPath!,
        title: frameCaption(frame) ?? 'Anime frame',
        actions: [
          _ViewerAction('Take photo', () => shootWithReference(context, ref, placeKey: _key, referencePath: frame.localPath, referenceImageId: frame.id), primary: true),
          _ViewerAction('Use as cover', () async => _report(await _place.setCover(_key, frame.localPath!), 'This frame is now the cover.')),
          _ViewerAction('Delete', () async {
            Navigator.of(context).pop();
            _report(await _place.deleteFrame(frame), 'Deleted the frame.');
          }),
        ],
      ),
    ));
  }
}

/// "Ep 3 · 12:34", from what is known of a frame, or null.
String? frameCaption(NewReferenceImage f) {
  final parts = <String>[
    if (f.episode?.trim().isNotEmpty ?? false) 'Ep ${f.episode!.trim()}',
    if (f.timestampS != null) '${f.timestampS! ~/ 60}:${(f.timestampS! % 60).toString().padLeft(2, '0')}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _FrameHero extends StatelessWidget {
  final List<NewReferenceImage> frames;
  final int index;
  final ValueChanged<int> onPage;
  final VoidCallback onAdd;
  final ValueChanged<int> onOpen;

  const _FrameHero({required this.frames, required this.index, required this.onPage, required this.onAdd, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    if (frames.isEmpty) {
      // A place without frames still gets a hero, so the page keeps its shape.
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.teaSoft, p.wisteriaSoft]),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_filter_outlined, size: 44, color: p.wisteria),
              const SizedBox(height: 8),
              Text('No anime frames yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add a frame')),
            ],
          ),
        ),
      );
    }
    final caption = frameCaption(frames[index]);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                itemCount: frames.length,
                controller: PageController(initialPage: index),
                onPageChanged: onPage,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => onOpen(i),
                  child: Image.file(
                    File(frames[i].localPath!),
                    fit: BoxFit.cover,
                    cacheWidth: 1280,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: p.wisteriaSoft,
                      child: Icon(Icons.broken_image_outlined, color: p.wisteria),
                    ),
                    semanticLabel: frameCaption(frames[i]) ?? 'Anime frame ${i + 1}',
                  ),
                ),
              ),
              if (caption != null) Positioned(left: 12, bottom: 12, child: _Chip(caption)),
              Positioned(right: 12, bottom: 12, child: _Chip('${index + 1} / ${frames.length}')),
            ],
          ),
        ),
        if (frames.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < frames.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == index ? p.wisteria : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _Actions extends StatelessWidget {
  final NewReferenceImage? frame;
  final VoidCallback onShoot;
  final VoidCallback? onFloat;
  final VoidCallback onDirections;
  final VoidCallback onAddToTrip;

  const _Actions({required this.frame, required this.onShoot, required this.onFloat, required this.onDirections, required this.onAddToTrip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    Widget small(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, color: onTap == null ? null : p.tea), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))],
            ),
          ),
        );
    // Equal heights for the buttons; a bare stretch has no height to fill in a list.
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (animeCameraSupported)
          Expanded(
            flex: 3,
            child: FilledButton(
              onPressed: onShoot,
              style: FilledButton.styleFrom(
                backgroundColor: p.tea,
                foregroundColor: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_outlined),
                  const SizedBox(height: 4),
                  const Text('Take photo', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(frame == null ? 'no frame' : 'with this frame', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        if (floatingReferenceSupported) ...[const SizedBox(width: 8), small(Icons.picture_in_picture_alt_outlined, 'Float frame', onFloat)],
        const SizedBox(width: 8),
        small(Icons.directions_outlined, 'Directions', onDirections),
        const SizedBox(width: 8),
        small(Icons.playlist_add, 'Add to trip', onAddToTrip),
      ],
      ),
    );
  }
}

class _TitleBlock extends ConsumerWidget {
  final Place place;
  final String placeKey;

  const _TitleBlock({required this.place, required this.placeKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(placeLabelsProvider(placeKey)).valueOrNull ?? const <Label>[];
    final allLabels = ref.watch(labelsListProvider(null)).valueOrNull ?? const <Label>[];
    final controller = ref.read(libraryControllerProvider.notifier);
    final sorted = [...labels]..sort((a, b) => '${labelKinds.indexOf(a.kind)}${a.name}'.compareTo('${labelKinds.indexOf(b.kind)}${b.name}'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (place.address?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text(place.address!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final l in sorted) LabelPill(label: l, onRemove: () => controller.removeLabel(placeKey, l.id)),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Label'),
              onPressed: () async {
                final picked = await showAddLabelSheet(context, labels: allLabels, exclude: labels.map((l) => l.id).toSet());
                if (picked != null) await controller.addLabel(placeKey, kind: picked.$1, name: picked.$2);
              },
            ),
          ],
        ),
        if (place.source != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              place.source!.toLowerCase() == 'anitabi'
                  ? 'Spot data from Anitabi, CC BY-NC-SA 4.0'
                  : 'Spot data from ${place.source}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// A card with a title row and, for what only the user sees, an "Only you" mark.
class _Section extends StatelessWidget {
  final String title;
  final bool private;
  final Widget? trailing;
  final Widget child;
  final Color? color;

  const _Section({required this.title, required this.child, this.private = false, this.trailing, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                if (private) const _OnlyYou(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _OnlyYou extends StatelessWidget {
  const _OnlyYou();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text('Only you', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// One line under the title: how often the user has been here, and a button
/// to note that they are here now.
class _VisitsRow extends ConsumerWidget {
  final String placeKey;
  final VoidCallback onHere;

  const _VisitsRow({required this.placeKey, required this.onHere});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final visits = [...?ref.watch(placeVisitsProvider(placeKey)).valueOrNull]..sort((a, b) => b.date.compareTo(a.date));
    final n = visits.length;
    final last = visits.isEmpty ? null : DateTime.tryParse(visits.first.date);
    return Row(
      children: [
        Icon(n == 0 ? Icons.flag_outlined : Icons.flag, size: 18, color: n == 0 ? theme.colorScheme.onSurfaceVariant : p.wisteria),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            [
              n == 0 ? 'Not visited yet' : n == 1 ? 'Visited once' : 'Visited $n times',
              if (last != null) 'last ${DateFormat.yMMMd().format(last)}',
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(color: n == 0 ? theme.colorScheme.onSurfaceVariant : null),
          ),
        ),
        TextButton(onPressed: onHere, child: const Text("I'm here")),
      ],
    );
  }
}

class _FactsCard extends StatelessWidget {
  final Place place;

  const _FactsCard({required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = <(String, String?)>[
      ('Getting there', place.accessTips),
      ('About', place.description),
      ('Hours', place.businessHours),
      ('Contact', place.contactInfo),
      ('Links', place.links),
    ].where((f) => f.$2?.trim().isNotEmpty ?? false).toList();
    return _Section(
      title: 'About this spot',
      child: facts.isEmpty
          ? Text(
              'Add how to get there, the best time to shoot, or the opening hours with the pencil above.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final (label, value) in facts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 100, child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                        Expanded(child: SelectableText(value!.trim(), style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final Place place;
  final ValueChanged<String> onSave;

  const _NoteCard({required this.place, required this.onSave});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  TextEditingController? _editing;

  @override
  void dispose() {
    _editing?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.place.privateNote;
    final editing = _editing;
    return _Section(
      title: 'My note',
      private: true,
      trailing: editing != null
          ? null
          : TextButton(
              onPressed: () => setState(() => _editing = TextEditingController(text: note ?? '')),
              child: Text(note == null ? 'Write' : 'Edit'),
            ),
      child: editing != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  key: const Key('placeNoteField'),
                  controller: editing,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Angles, gear, what to try next time'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => setState(() => _editing = null), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        widget.onSave(editing.text);
                        setState(() => _editing = null);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            )
          : Text(
              note ?? 'Notes only you can see, in every trip: angles, gear, what to try next time.',
              style: theme.textTheme.bodyMedium?.copyWith(color: note == null ? theme.colorScheme.onSurfaceVariant : null),
            ),
    );
  }
}

class _PhotosCard extends ConsumerWidget {
  final String placeKey;
  final List<NewReferenceImage> frames;
  final VoidCallback onAdd;

  const _PhotosCard({required this.placeKey, required this.frames, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photos = [...?ref.watch(placePhotosProvider(placeKey)).valueOrNull]
      ..sort((a, b) => (b.takenAt ?? b.createdAt).compareTo(a.takenAt ?? a.createdAt));
    final trips = {for (final t in ref.watch(tripSummariesProvider).valueOrNull ?? const <TripSummary>[]) t.trip.id: t.trip.title};
    // Photos grouped by the trip they were taken on, newest group first.
    final groups = <String?, List<Photo>>{};
    for (final photo in photos) {
      groups.putIfAbsent(photo.tripId, () => []).add(photo);
    }
    return _Section(
      title: 'My photos',
      private: true,
      trailing: IconButton(tooltip: 'Add photos', icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: onAdd),
      child: photos.isEmpty
          ? Text(
              'Photos you take here, or add from your gallery, show up here.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final MapEntry(key: tripId, value: items) in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      (tripId == null ? 'No trip' : trips[tripId] ?? 'A deleted trip').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final photo in items)
                        GestureDetector(
                          onTap: () => _open(context, ref, photo),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(photo.localPath),
                              fit: BoxFit.cover,
                              cacheWidth: 360,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Photo photo) async {
    final place = ref.read(placeControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    // The frame it was matched with, preloaded in the editor for a comparison.
    final frame = frames.where((f) => f.id == photo.referenceImageId).firstOrNull;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (viewerContext) => _ImageViewer(
        path: photo.localPath,
        title: DateFormat.yMMMd().add_Hm().format(photo.takenAt ?? photo.createdAt),
        actions: [
          _ViewerAction('Edit', () {
            final qs = {
              'path': Uri.encodeComponent(photo.localPath),
              if (frame?.localPath != null) 'ref': Uri.encodeComponent(frame!.localPath!),
              if (frame != null) 'refId': frame.id,
            };
            viewerContext.push('/pois/${Uri.encodeComponent(placeKey)}/photo-edit?${qs.entries.map((e) => '${e.key}=${e.value}').join('&')}');
          }, primary: true),
          _ViewerAction('Save to device', () async {
            final result = await place.saveToGallery(photo.localPath);
            messenger.showSnackBar(SnackBar(content: Text(result is Failure ? (result as Failure).error : 'Saved to your gallery.')));
          }),
          _ViewerAction('Delete', () async {
            Navigator.of(viewerContext).pop();
            final result = await place.deletePhoto(photo);
            messenger.showSnackBar(SnackBar(content: Text(result is Failure ? (result as Failure).error : 'Deleted the photo.')));
          }),
        ],
      ),
    ));
  }
}

class _TripsCard extends ConsumerWidget {
  final String placeKey;

  const _TripsCard({required this.placeKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(libraryEntriesProvider).valueOrNull?.where((e) => e.place.placeKey == placeKey).firstOrNull;
    final trips = [
      for (final t in ref.watch(tripSummariesProvider).valueOrNull ?? const <TripSummary>[])
        if (entry?.tripIds.contains(t.trip.id) ?? false) t,
    ];
    if (trips.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // It carries its own gap below, so a place in no trip leaves none.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Section(
      title: 'In your trips',
      child: Column(
        children: [
          for (final t in trips)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: theme.trip.teaSoft, foregroundColor: theme.trip.tea, child: const Icon(Icons.flight_takeoff, size: 20)),
              title: Text(t.trip.title),
              subtitle: Text(tripLine(t)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/trips/${t.trip.id}?tab=stops'),
            ),
        ],
      ),
      ),
    );
  }
}

String tripLine(TripSummary t) {
  final f = DateFormat.MMMd();
  if (t.firstDate == null || t.lastDate == null) return 'No dates yet';
  return t.firstDate == t.lastDate ? f.format(t.firstDate!) : '${f.format(t.firstDate!)} – ${f.format(t.lastDate!)}';
}

class _LocationCard extends StatelessWidget {
  final Place place;

  const _LocationCard({required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = LatLng(place.lat, place.lng);
    return _Section(
      title: 'Location',
      trailing: TextButton(
        onPressed: () => context.push('/library/places/${Uri.encodeComponent(place.placeKey)}/location'),
        child: const Text('Move pin'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: IgnorePointer(
                child: FlutterMap(
                  key: ValueKey(at),
                  options: MapOptions(initialCenter: at, initialZoom: 16),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.trip_planner',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: at,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: Icon(Icons.location_on, size: 36, color: theme.trip.wisteria),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${place.lat.toStringAsFixed(5)}, ${place.lng.toStringAsFixed(5)} · map © OpenStreetMap contributors',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ViewerAction {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ViewerAction(this.label, this.onTap, {this.primary = false});
}

/// A frame or photo full screen, pinch to zoom, with its actions below.
class _ImageViewer extends StatelessWidget {
  final String path;
  final String title;
  final List<_ViewerAction> actions;

  const _ImageViewer({required this.path, required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in actions)
                    a.primary
                        ? FilledButton(onPressed: a.onTap, child: Text(a.label))
                        : OutlinedButton(
                            onPressed: a.onTap,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                            child: Text(a.label),
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
