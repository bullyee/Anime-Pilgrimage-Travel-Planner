import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/name_dialog.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/controllers/place_controller.dart';
import '../../library/models/frames.dart';
import '../../library/models/library_entry.dart' show labelKinds;
import '../../library/providers/place_providers.dart';
import '../../library/screens/place_screen.dart' show openDirections, sourceLine;
import '../../library/widgets/label_widgets.dart';
import '../../library/widgets/place_page_parts.dart';
import '../../planner/controllers/day_planner_controller.dart';
import '../../planner/models/planner_view.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/day_card.dart' show dayName, dayWithDate;
import '../../planner/widgets/planner_sheets.dart' show pickStartTime;
import '../controllers/trip_stops_controller.dart';
import '../providers/trip_providers.dart';
import '../../auth/providers/auth_provider.dart';

/// Where a stop sits in the plan: its day and its item there.
typedef StopSlot = ({PlannerDay day, PlannerItem item});

StopSlot? findStopSlot(PlannerView view, String stopId) {
  for (final d in view.days) {
    for (final it in d.items) {
      if (it.stop.id == stopId) return (day: d, item: it);
    }
  }
  return null;
}

/// The frames to shoot with on a stop: the user's own frames of the place
/// first, then the stop's copies that aren't among them, such as frames
/// someone else in the trip added.
List<NewReferenceImage> stopFrames({required List<NewReferenceImage> place, required List<NewReferenceImage> stop}) {
  final own = [for (final f in place) if (frameHasImage(f)) f];
  bool same(NewReferenceImage a, NewReferenceImage b) =>
      ((a.localPath?.isNotEmpty ?? false) && a.localPath == b.localPath) ||
      ((a.remoteUrl?.isNotEmpty ?? false) && a.remoteUrl == b.remoteUrl);
  return [
    ...own,
    for (final f in stop)
      if (frameHasImage(f) && !own.any((o) => same(o, f))) f,
  ];
}

/// A stop's facts in the order its page shows them.
List<(String, String?)> stopFacts(Stop stop) => [
      ('Getting there', stop.accessTips),
      ('About', stop.description),
      ('Hours', stop.businessHours),
      ('Contact', stop.contactInfo),
      ('Links', stop.links),
    ];

/// A stop in a trip, on the same page as a library place. The trip's plan
/// for it, its trip note and its copy of the facts are shared with everyone
/// in the trip. The user's note, visits and photos come from their library
/// place, so they follow the place to every trip. The pencil turns the page
/// itself into a form.
class StopScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String stopId;

  const StopScreen({super.key, required this.tripId, required this.stopId});

  @override
  ConsumerState<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends ConsumerState<StopScreen> {
  int _frame = 0;

  /// What edit mode is changing, or null outside it.
  EditDraft? _draft;
  String? _nameError;

  String get _tripId => widget.tripId;
  TripStopsController get _stops => ref.read(tripStopsControllerProvider.notifier);
  DayPlannerController get _planner => ref.read(dayPlannerControllerProvider.notifier);
  PlaceController get _place => ref.read(placeControllerProvider.notifier);

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  void _report(AppResult<dynamic> result, [String? ok, SnackBarAction? action]) {
    if (!mounted) return;
    // The newest outcome replaces the one on screen instead of queueing.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    switch (result) {
      case Failure(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error)));
      case Success():
        if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok), action: action));
    }
  }

  void _edit(Stop stop, Place? place) {
    final currentUid = ref.read(currentUserIdProvider);
    final trip = ref.read(tripDetailProvider(_tripId)).valueOrNull;
    if (trip != null && trip.sharing == 'group' && currentUid == 'guest_local_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to edit a shared trip.')),
      );
      return;
    }
    setState(() {
        _nameError = null;
        _draft = EditDraft(
          PlaceFacts(
            name: stop.name,
            address: stop.address,
            accessTips: stop.accessTips,
            description: stop.description,
            businessHours: stop.businessHours,
            contactInfo: stop.contactInfo,
            links: stop.links,
          ),
          notes: {'trip': stop.note, if (place != null) 'mine': place.privateNote},
        );
      });
  }

  void _leaveEdit() => setState(() {
        _draft?.dispose();
        _draft = null;
      });

  /// Saves what edit mode changed: the stop's facts and trip note for the
  /// trip, and the user's own note on their place.
  Future<void> _done(Stop stop) async {
    final draft = _draft!;
    if (!draft.changed) return _leaveEdit();
    if (draft.name.text.trim().isEmpty) {
      setState(() => _nameError = 'Give the stop a name.');
      return;
    }
    if (draft.factsChanged) {
      final result = await _stops.updateFacts(stop.id, draft.facts);
      if (result is Failure) return _report(result);
    }
    if (draft.noteChanged('trip')) {
      final result = await _stops.setNote(stop.id, draft.notes['trip']!.text);
      if (result is Failure) return _report(result);
    }
    if (draft.notes.containsKey('mine') && draft.noteChanged('mine')) {
      final result = await _place.setNote(stop.placeKey, draft.notes['mine']!.text);
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
    final stopAsync = ref.watch(stopDetailProvider(widget.stopId));
    final stop = stopAsync.valueOrNull;
    if (stop == null || stop.deletedAt != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: stopAsync.isLoading ? const CircularProgressIndicator() : const Text('This stop is no longer in the trip.'),
        ),
      );
    }
    final theme = Theme.of(context);
    final tripAsync = ref.watch(tripDetailProvider(_tripId));
    final trip = tripAsync.valueOrNull;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: tripAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('This trip is not available.'),
        ),
      );
    }
    final view = ref.watch(plannerViewProvider(_tripId)).valueOrNull;
    final slot = view == null ? null : findStopSlot(view, stop.id);
    // Stops someone else added may be of a place that isn't in this library.
    final place = ref.watch(placeDetailProvider(stop.placeKey)).valueOrNull;
    final frames = stopFrames(
      place: place == null ? const [] : ref.watch(placeReferenceImagesProvider(stop.placeKey)).valueOrNull ?? const [],
      stop: ref.watch(stopReferenceImagesProvider(stop.id)).valueOrNull ?? const [],
    );
    if (_frame >= frames.length) _frame = 0;
    final current = frames.isEmpty ? null : frames[_frame];
    final where = slot == null ? 'Not on a day yet' : dayName(slot.day);
    final draft = _draft;
    final facts = stopFacts(stop);
    final tripNote = stop.note?.trim() ?? '';
    final myNote = place?.privateNote?.trim() ?? '';

    return PopScope(
      // Back leaves edit mode first, asking before it drops changes.
      canPop: draft == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(draft == null ? stop.name : 'Editing', maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                trip == null ? where : '${trip.title} · $where',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            EditModeButton(editing: draft != null, onEdit: () => _edit(stop, place), onDone: () => _done(stop)),
            if (draft == null)
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (action) => _onMenu(action, stop, view, slot),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  if (view != null) PopupMenuItem(value: 'day', child: Text(slot == null ? 'Add to a day' : 'Move to another day')),
                  if (slot != null) const PopupMenuItem(value: 'backlog', child: Text('Back to the backlog')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove from the trip')),
                ],
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            FrameHero(
              frames: frames,
              index: _frame,
              onPage: (i) => setState(() => _frame = i),
              onOpen: (i) => _openFrame(stop, frames[i]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageActions(
                    frame: current,
                    onShoot: () => _shoot(stop, current),
                    onFloat: current == null ? null : () => _float(current),
                    onDirections: () async {
                      if (!await openDirections(stop.lat, stop.lng)) _report(const Failure("Couldn't open a maps app."));
                    },
                    last: (icon: Icons.view_timeline_outlined, label: 'In the plan', onTap: () => context.push('/trips/$_tripId?tab=plan')),
                  ),
                  const SizedBox(height: 16),
                  _StopTitle(stop: stop, draft: draft, nameError: _nameError),
                  const SizedBox(height: 14),
                  ...spaced([
                    _PlanCard(
                      slot: slot,
                      loading: view == null,
                      editing: draft != null,
                      onVisited: (visited) => _setVisited(stop, slot!, visited),
                      onStartTime: () => _pickStart(slot!),
                      onClearStart: () => _planner.setFixedTime(slot!.item.item.id, null),
                      onStay: (m) => _planner.setStay(slot!.item.item.id, m),
                      onTransit: (m) => _planner.setTransit(slot!.item.item.id, m),
                      onAddToDay: () => _pickDay(stop, view!, null),
                    ),
                    if (draft != null)
                      NoteField(
                        title: 'Trip note',
                        controller: draft.notes['trip']!,
                        hint: 'A note for everyone in the trip: where to meet, who has the tickets',
                        scope: SectionScope.trip,
                        fieldKey: const Key('tripNoteField'),
                        maxLength: maxTripNoteLength,
                      )
                    else if (tripNote.isNotEmpty)
                      NoteView(title: 'Trip note', note: tripNote, scope: SectionScope.trip),
                    if (draft != null)
                      FactsFields(
                        title: 'About this spot',
                        draft: draft,
                        scope: SectionScope.trip,
                        footer: 'This trip has its own copy of the facts. Edits change it for everyone in the trip, not your library.',
                      )
                    else if (anyFacts(facts))
                      FactsCard(title: 'About this spot', facts: facts, scope: SectionScope.trip),
                    if (place == null)
                      Text(
                        "This spot isn't in your library, so there's no note, visit or photo of your own here.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      )
                    else ...[
                      // With a plan, Mark visited records the visit; without one, the user says so here.
                      VisitsRow(
                        placeKey: stop.placeKey,
                        onHere: slot != null
                            ? null
                            : () async {
                                final result = await _place.addVisitToday(stop.placeKey, tripId: _tripId);
                                _report(result, switch (result) {
                                  Success(value: false) => 'Today is on record already.',
                                  _ => 'Added a visit for today.',
                                });
                              },
                      ),
                      if (draft != null)
                        NoteField(
                          title: 'My note',
                          controller: draft.notes['mine']!,
                          hint: 'Notes only you can see, in every trip: angles, gear, what to try next time',
                          scope: SectionScope.onlyYou,
                          fieldKey: const Key('placeNoteField'),
                        )
                      else if (myNote.isNotEmpty)
                        NoteView(title: 'My note', note: myNote, scope: SectionScope.onlyYou),
                      PhotosCard(
                        placeKey: stop.placeKey,
                        frames: frames,
                        onAdd: () async => _report(await _place.addPhotosFromGallery(stop.placeKey)),
                      ),
                      _LibraryCard(placeKey: stop.placeKey),
                    ],
                    LocationCard(lat: stop.lat, lng: stop.lng),
                    if (stop.source != null) SourceNote('${sourceLine(stop.source!)} · copied into this trip'),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _framePath(NewReferenceImage frame) async {
    final path = await framePath(ref, frame);
    if (path == null) _report(const Failure("This frame isn't on this phone yet. Try again when you're online."));
    return path;
  }

  Future<void> _shoot(Stop stop, NewReferenceImage? frame) async {
    final path = frame == null ? null : await _framePath(frame);
    if ((frame != null && path == null) || !mounted) return;
    await shootWithReference(context, ref, placeKey: stop.placeKey, tripId: _tripId, referencePath: path, referenceImageId: frame?.id);
  }

  Future<void> _float(NewReferenceImage frame) async {
    final path = await _framePath(frame);
    if (path == null || !mounted) return;
    await floatReferenceImage(context, path);
  }

  Future<void> _openFrame(Stop stop, NewReferenceImage frame) async {
    final path = await _framePath(frame);
    if (path == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ImageViewer(
        path: path,
        title: frameCaption(frame) ?? 'Anime frame',
        actions: [
          if (animeCameraSupported) ViewerAction('Take photo', () => _shoot(stop, frame), primary: true),
          if (floatingReferenceSupported) ViewerAction('Float frame', () => floatReferenceImage(context, path)),
        ],
      ),
    ));
  }

  /// Marks the stop visited for everyone in the trip, and adds a visit to the
  /// user's own history. Taking it back also takes back today's visit.
  Future<void> _setVisited(Stop stop, StopSlot slot, bool visited) async {
    final currentUid = ref.read(currentUserIdProvider);
    final trip = ref.read(tripDetailProvider(_tripId)).valueOrNull;
    if (trip != null && trip.sharing == 'group' && currentUid == 'guest_local_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make changes to a shared trip.')),
      );
      return;
    }
    final result = await _planner.setVisited(slot.item.item.id, visited);
    if (result is Failure || ref.read(placeDetailProvider(stop.placeKey)).valueOrNull == null) {
      _report(result, visited ? 'Marked visited for the trip.' : 'No longer marked visited.');
      return;
    }
    if (visited) {
      await _place.addVisitToday(stop.placeKey, tripId: _tripId);
    } else {
      await _place.removeVisitToday(stop.placeKey, tripId: _tripId);
    }
    _report(result, visited ? 'Marked visited for the trip, and added to your visits.' : 'No longer marked visited.');
  }

  Future<void> _pickStart(StopSlot slot) async {
    final items = slot.day.items;
    final index = items.indexOf(slot.item);
    final previous = index > 0 ? items[index - 1] : null;
    final minutes = await pickStartTime(
      context,
      initial: slot.item.startMinutes,
      followsAt: previous == null ? null : previous.endMinutes + previous.item.transitMinutes,
    );
    if (minutes != null) _report(await _planner.setFixedTime(slot.item.item.id, minutes));
  }

  Future<void> _onMenu(String action, Stop stop, PlannerView? view, StopSlot? slot) async {
    switch (action) {
      case 'rename':
        final name = await askName(context, title: 'Rename this stop', action: 'Rename', initial: stop.name);
        if (name == null || name == stop.name) return;
        _report(await _stops.renameStop(stop.id, name), 'Renamed to $name. Your library keeps its own name.');
      case 'day':
        await _pickDay(stop, view!, slot);
      case 'backlog':
        final itemId = slot!.item.item.id;
        _report(
          await _planner.unschedule(itemId),
          'Moved ${stop.name} to the backlog.',
          SnackBarAction(label: 'Undo', onPressed: () => _planner.restoreItem(itemId)),
        );
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Remove “${stop.name}”?'),
            content: Text(slot == null
                ? 'It goes for everyone in the trip. Your library is not changed.'
                : 'It goes for everyone in the trip, and comes off ${dayName(slot.day)}. Your library is not changed.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        final result = await _stops.removeStop(stop.id);
        if (!mounted) return;
        if (result is Success) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/trips/$_tripId?tab=stops');
          }
        }
        _report(result, 'Removed ${stop.name}.');
    }
  }

  /// Puts the stop on a day the user picks, or moves it there.
  Future<void> _pickDay(Stop stop, PlannerView view, StopSlot? slot) async {
    final day = await showModalBottomSheet<PlannerDay>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(slot == null ? 'Add to a day' : 'Move to another day', style: Theme.of(sheetContext).textTheme.titleLarge),
            ),
            for (final d in view.days)
              if (d != slot?.day)
                ListTile(
                  leading: Icon(d.isBackup ? Icons.beach_access_outlined : Icons.today_outlined),
                  title: Text(dayWithDate(d)),
                  onTap: () => Navigator.pop(sheetContext, d),
                ),
          ],
        ),
      ),
    );
    if (day == null) return;
    final result = slot == null
        ? await _planner.scheduleStop(tripId: _tripId, stopId: stop.id, dayId: day.day.id)
        : await _planner.moveItem(itemId: slot.item.item.id, toDayId: day.day.id);
    _report(result, '${slot == null ? 'Added' : 'Moved'} ${stop.name} to ${dayName(day)}.');
  }
}

/// The stop's name, address and labels. In edit mode the name and address
/// are fields, and labels can be added and taken off, for everyone in the trip.
class _StopTitle extends ConsumerWidget {
  final Stop stop;
  final EditDraft? draft;
  final String? nameError;

  const _StopTitle({required this.stop, required this.draft, required this.nameError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(stopLabelsProvider(stop.id)).valueOrNull ?? const <Label>[];
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
          Text(stop.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (stop.address?.trim().isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(child: Text(stop.address!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
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
              for (final l in sorted) LabelPill(label: l, onRemove: editing ? () => controller.removeStopLabel(stop.id, l.id) : null),
              if (editing)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Label'),
                  onPressed: () async {
                    final picked = await showAddLabelSheet(context, labels: allLabels, exclude: labels.map((l) => l.id).toSet());
                    if (picked != null) await controller.addStopLabel(stop.id, kind: picked.$1, name: picked.$2);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The stop's plan, shared with the trip: its day, when it starts, how long
/// it lasts and the travel on, and whether it was visited. Times are changed
/// in edit mode; marking it visited works any time.
class _PlanCard extends StatelessWidget {
  final StopSlot? slot;
  final bool loading;
  final bool editing;
  final ValueChanged<bool> onVisited;
  final VoidCallback onStartTime;
  final VoidCallback onClearStart;
  final ValueChanged<int> onStay;
  final ValueChanged<int> onTransit;
  final VoidCallback onAddToDay;

  const _PlanCard({
    required this.slot,
    required this.loading,
    required this.editing,
    required this.onVisited,
    required this.onStartTime,
    required this.onClearStart,
    required this.onStay,
    required this.onTransit,
    required this.onAddToDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final slot = this.slot;
    if (slot == null) {
      return PageSection(
        title: 'Plan',
        scope: SectionScope.trip,
        child: loading
            ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
            : Row(
                children: [
                  Expanded(child: Text('Not on a day yet. It waits in the backlog.', style: theme.textTheme.bodyMedium)),
                  FilledButton.tonal(onPressed: onAddToDay, child: const Text('Add to a day')),
                ],
              ),
      );
    }

    final item = slot.item;
    final items = slot.day.items;
    final index = items.indexOf(item);
    final previous = index > 0 ? items[index - 1] : null;
    final isLast = index == items.length - 1;
    final followsAt = previous == null ? null : previous.endMinutes + previous.item.transitMinutes;
    final transit = item.item.transitMinutes;

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 84, child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
              Expanded(child: value),
            ],
          ),
        );
    Widget stepper({required int value, required int min, required String less, required String more, required ValueChanged<int> onChanged}) => Row(
          children: [
            IconButton.outlined(tooltip: less, onPressed: value - 5 < min ? null : () => onChanged(value - 5), icon: const Icon(Icons.remove)),
            SizedBox(width: 72, child: Text('$value min', textAlign: TextAlign.center, style: theme.textTheme.titleSmall)),
            IconButton.outlined(tooltip: more, onPressed: () => onChanged(value + 5), icon: const Icon(Icons.add)),
          ],
        );
    final start = Text(
      [formatTimelineMinutes(item.startMinutes), if (item.fixed) 'fixed'].join(' · '),
      style: theme.textTheme.titleSmall?.copyWith(color: item.conflict ? p.vermilion : item.fixed ? p.tea : null),
    );

    return PageSection(
      title: 'Plan',
      scope: SectionScope.trip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayWithDate(slot.day), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      previous == null
                          ? 'First stop of the day'
                          : 'After ${previous.stop.name}${previous.item.transitMinutes > 0 ? ' · ${previous.item.transitMinutes} min on the way' : ''}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              FilterChip(
                selected: item.done,
                showCheckmark: true,
                label: Text(item.done ? 'Visited' : 'Mark visited'),
                onSelected: onVisited,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (editing) ...[
            row(
              'Starts',
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  start,
                  OutlinedButton.icon(
                    onPressed: onStartTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(item.fixed ? 'Change time' : 'Set a time'),
                  ),
                  if (item.fixed) TextButton(onPressed: onClearStart, child: const Text('Clear')),
                ],
              ),
            ),
            row('Stay', stepper(value: item.item.stayMinutes, min: 5, less: '5 minutes shorter', more: '5 minutes longer', onChanged: onStay)),
            if (!isLast)
              row('Travel on', stepper(value: transit, min: 0, less: '5 minutes less travel', more: '5 minutes more travel', onChanged: onTransit)),
          ] else ...[
            row('Starts', start),
            row('Stay', Text('${item.item.stayMinutes} min', style: theme.textTheme.titleSmall)),
            if (!isLast && transit > 0) row('Travel on', Text('$transit min', style: theme.textTheme.titleSmall)),
          ],
          if (item.conflict && followsAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 84, bottom: 4),
              child: Text(
                'Starts before the stop before it is done (${formatTimelineMinutes(followsAt)}).',
                style: theme.textTheme.bodySmall?.copyWith(color: p.vermilion),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${formatTimelineMinutes(item.startMinutes)}–${formatTimelineMinutes(item.endMinutes)}. '
            'Marking it visited shows for everyone in the trip, and also adds a visit to your own history.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// Points to the library place that the user's own parts of the page come from.
class _LibraryCard extends StatelessWidget {
  final String placeKey;

  const _LibraryCard({required this.placeKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageSection(
      title: 'In your library',
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Your note, visits and photos belong to your place, so they follow you to every trip.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => context.push('/library/places/${Uri.encodeComponent(placeKey)}'),
            child: const Text('Open my place'),
          ),
        ],
      ),
    );
  }
}
