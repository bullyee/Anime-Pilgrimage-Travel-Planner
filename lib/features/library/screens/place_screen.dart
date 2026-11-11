import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../models/frames.dart';
import '../models/library_entry.dart';
import '../providers/library_providers.dart';
import '../providers/place_providers.dart';
import '../widgets/label_widgets.dart';
import '../widgets/place_page_parts.dart';
import '../widgets/trip_picker.dart';

/// One place in the library: its anime frames first, with the camera one
/// tap away, then its facts, and then what is only the user's own: their
/// note, their visits and their photos. The pencil turns the page itself
/// into a form.
class PlaceScreen extends ConsumerStatefulWidget {
  final String placeKey;

  const PlaceScreen({super.key, required this.placeKey});

  @override
  ConsumerState<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends ConsumerState<PlaceScreen> {
  int _frame = 0;

  /// What edit mode is changing, or null outside it.
  EditDraft? _draft;
  String? _nameError;

  String get _key => widget.placeKey;
  PlaceController get _place => ref.read(placeControllerProvider.notifier);

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

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

  void _edit(Place place) => setState(() {
        _nameError = null;
        _draft = EditDraft(
          PlaceFacts(
            name: place.name,
            address: place.address,
            accessTips: place.accessTips,
            description: place.description,
            businessHours: place.businessHours,
            contactInfo: place.contactInfo,
            links: place.links,
          ),
          notes: {'mine': place.privateNote},
        );
      });

  void _leaveEdit() => setState(() {
        _draft?.dispose();
        _draft = null;
      });

  Future<void> _done() async {
    final draft = _draft!;
    if (!draft.changed) return _leaveEdit();
    if (draft.name.text.trim().isEmpty) {
      setState(() => _nameError = 'Give the place a name.');
      return;
    }
    if (draft.factsChanged) {
      final result = await _place.updateFacts(_key, draft.facts);
      if (result is Failure) return _report(result);
    }
    if (draft.noteChanged('mine')) {
      final result = await _place.setNote(_key, draft.notes['mine']!.text);
      if (result is Failure) return _report(result);
    }
    if (!mounted) return;
    _leaveEdit();
    _report(const Success(null), 'Saved.');
  }

  Future<void> _cancel() async {
    if (_draft?.changed ?? false) {
      if (!await confirmDiscard(context)) return;
    }
    if (mounted) _leaveEdit();
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
    final draft = _draft;
    final facts = placeFacts(place);
    final entry = ref.watch(libraryEntriesProvider).valueOrNull?.where((e) => e.place.placeKey == _key).firstOrNull;
    final trips = [
      for (final t in ref.watch(tripSummariesProvider).valueOrNull ?? const <TripSummary>[])
        if (entry?.tripIds.contains(t.trip.id) ?? false) t,
    ];
    final note = place.privateNote?.trim() ?? '';

    return PopScope(
      // Back leaves edit mode first, asking before it drops changes.
      canPop: draft == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text(draft == null ? place.name : 'Editing', maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            EditModeButton(editing: draft != null, onEdit: () => _edit(place), onDone: _done),
            if (draft == null)
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
            FrameHero(
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
                  PageActions(
                    frame: current,
                    onShoot: () => shootWithFrames(context, ref, placeKey: _key, frames: framesOnDevice, index: _frame),
                    onFloat: current == null ? null : () => floatReferenceImage(context, current.localPath!),
                    onDirections: () => _directions(place),
                    last: (icon: Icons.playlist_add, label: 'Add to trip', onTap: () => _addToTrip(place)),
                  ),
                  const SizedBox(height: 16),
                  _TitleBlock(place: place, placeKey: _key, draft: draft, nameError: _nameError),
                  const SizedBox(height: 8),
                  VisitsRow(placeKey: _key, onHere: () async {
                    final result = await _place.addVisitToday(_key);
                    _report(result, switch (result) {
                      Success(value: false) => 'Today is on record already.',
                      _ => 'Added a visit for today.',
                    });
                  }),
                  const SizedBox(height: 14),
                  ...spaced([
                    if (draft != null)
                      FactsFields(title: 'About this spot', draft: draft)
                    else if (anyFacts(facts))
                      FactsCard(title: 'About this spot', facts: facts),
                    if (trips.isNotEmpty) _TripsCard(trips: trips),
                    if (draft != null)
                      NoteField(
                        title: 'My note',
                        controller: draft.notes['mine']!,
                        hint: 'Notes only you can see, in every trip: angles, gear, what to try next time',
                        scope: SectionScope.onlyYou,
                        fieldKey: const Key('placeNoteField'),
                      )
                    else if (note.isNotEmpty)
                      NoteView(title: 'My note', note: note, scope: SectionScope.onlyYou),
                    PhotosCard(
                      placeKey: _key,
                      frames: frames,
                      onAdd: () async => _report(await _place.addPhotosFromGallery(_key)),
                    ),
                    LocationCard(
                      lat: place.lat,
                      lng: place.lng,
                      onMovePin: draft == null ? null : () => context.push('/library/places/${Uri.encodeComponent(_key)}/location'),
                    ),
                    if (place.source != null) SourceNote(sourceLine(place.source!)),
                  ]),
                ],
              ),
            ),
          ],
        ),
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
    if (!await openDirections(place.lat, place.lng) && mounted) {
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
      builder: (_) => ImageViewer(
        path: frame.localPath!,
        title: frameCaption(frame) ?? 'Anime frame',
        actions: [
          ViewerAction('Take photo', () => shootWithFrames(context, ref, placeKey: _key, frames: frames, index: index), primary: true),
          ViewerAction('Use as cover', () async => _report(await _place.setCover(_key, frame.localPath!), 'This frame is now the cover.')),
          ViewerAction('Delete', () async {
            Navigator.of(context).pop();
            _report(await _place.deleteFrame(frame), 'Deleted the frame.');
          }),
        ],
      ),
    ));
  }
}

/// A place's facts in the order its page shows them.
List<(String, String?)> placeFacts(Place place) => [
      ('Getting there', place.accessTips),
      ('About', place.description),
      ('Hours', place.businessHours),
      ('Contact', place.contactInfo),
      ('Links', place.links),
    ];

/// Opens directions to a point in the maps app, and says whether one opened.
Future<bool> openDirections(double lat, double lng) =>
    launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication);

/// The name, address and labels. In edit mode the name and address are
/// fields, and labels can be added and taken off.
class _TitleBlock extends ConsumerWidget {
  final Place place;
  final String placeKey;
  final EditDraft? draft;
  final String? nameError;

  const _TitleBlock({required this.place, required this.placeKey, required this.draft, required this.nameError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(placeLabelsProvider(placeKey)).valueOrNull ?? const <Label>[];
    final allLabels = ref.watch(labelsListProvider(null)).valueOrNull ?? const <Label>[];
    final controller = ref.read(libraryControllerProvider.notifier);
    final sorted = [...labels]..sort((a, b) => '${labelKinds.indexOf(a.kind)}${a.name}'.compareTo('${labelKinds.indexOf(b.kind)}${b.name}'));
    final editing = draft != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editing)
          NameFields(draft: draft!, nameError: nameError)
        else ...[
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
        ],
        if (editing || sorted.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final l in sorted) LabelPill(label: l, onRemove: editing ? () => controller.removeLabel(placeKey, l.id) : null),
              if (editing)
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
        ],
      ],
    );
  }
}

/// Where a spot's data came from, with Anitabi's license.
String sourceLine(String source) =>
    source.toLowerCase() == 'anitabi' ? 'Spot data from Anitabi, CC BY-NC-SA 4.0' : 'Spot data from $source';

class _TripsCard extends StatelessWidget {
  final List<TripSummary> trips;

  const _TripsCard({required this.trips});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageSection(
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
    );
  }
}

String tripLine(TripSummary t) {
  final f = DateFormat.MMMd();
  if (t.firstDate == null || t.lastDate == null) return 'No dates yet';
  return t.firstDate == t.lastDate ? f.format(t.firstDate!) : '${f.format(t.firstDate!)} – ${f.format(t.lastDate!)}';
}
