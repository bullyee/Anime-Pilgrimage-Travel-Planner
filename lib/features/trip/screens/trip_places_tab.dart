import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../home/providers/home_providers.dart' show homeClockProvider;
import '../../planner/controllers/day_planner_controller.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/planner_sheets.dart' show reportResult;
import '../../sharing/providers/group_sharing_providers.dart';
import '../models/place_spots.dart';
import '../models/trip_places_view.dart';
import '../providers/trip_place_providers.dart';
import '../widgets/position_follower.dart';
import 'trip_place_screen.dart' show FrameCell, sectionDate, sectionTitle;

/// Offers the two ways to add places: from the library, or a new spot.
void openAddStopsSheet(BuildContext context, String tripId) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('From my library'),
            subtitle: const Text('Places you have saved'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/trips/$tripId/stops/add');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('New spot'),
            subtitle: const Text('Pick it on the map'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/trips/$tripId/stops/new');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The trip page's Places tab: the trip's days (optional categories with a
/// title and maybe a date), each with its places, then the places on no day
/// in Unsorted. Each place shows its latest photo or first frame, how many
/// spots and frames it has and how many are shot, and how far it is when
/// the position is known; it opens the place page. A search finds places by
/// name, spot note or frame episode, and Nearest lists them all by distance.
///
/// People who can edit the trip rename days, give or take their dates,
/// reorder a day's places, delete days (their places go to Unsorted), add
/// days and places. Times stay in the schedule.
class TripPlacesTab extends ConsumerStatefulWidget {
  final String tripId;

  const TripPlacesTab({super.key, required this.tripId});

  @override
  ConsumerState<TripPlacesTab> createState() => _TripPlacesTabState();
}

class _TripPlacesTabState extends ConsumerState<TripPlacesTab> {
  final _follower = PositionFollower();
  final _search = TextEditingController();
  String _query = '';
  bool _nearest = false;

  /// The day whose places are being reordered.
  String? _reordering;

  // The places' contents, worked out again only when their inputs change.
  List<Object?> _memoKey = const [];
  Map<String, PlaceContent> _contents = const {};

  DayPlannerController get _planner => ref.read(dayPlannerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _follower.addListener(_onPosition);
    _follower.start();
  }

  @override
  void dispose() {
    _follower.removeListener(_onPosition);
    _follower.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onPosition() {
    if (mounted) setState(() {});
  }

  void _open(TripPlace place) => context.push('/trips/${widget.tripId}/places/${place.id}');

  Map<String, PlaceContent> _contentsOf(TripPlacesView view) {
    final own = ref.watch(tripFramesProvider(widget.tripId)).valueOrNull ?? const <NewReferenceImage>[];
    final library = ref.watch(tripLibraryFramesProvider(widget.tripId)).valueOrNull ?? const <NewReferenceImage>[];
    final photos = ref.watch(tripPhotosProvider(widget.tripId)).valueOrNull ?? const <Photo>[];
    final places = view.all;
    final key = [own, library, photos, for (final p in places) ...p.stops];
    if (key.length == _memoKey.length && Iterable.generate(key.length).every((i) => identical(key[i], _memoKey[i]))) return _contents;
    final index = TripFrameIndex(own: own, library: library, photos: photos);
    _memoKey = key;
    return _contents = {for (final p in places) p.id: index.place(p.stops, group: p.group)};
  }

  // ---- days

  Future<({String name, DateTime? date})?> _dayForm({PlacesSection? section}) => showModalBottomSheet<({String name, DateTime? date})>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _DayForm(section: section, pickDate: _pickDate),
      );

  static Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final today = DateUtils.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: initial ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5, 12, 31),
    );
  }

  Future<void> _newDay() async {
    final form = await _dayForm();
    if (form == null || !mounted) return;
    final added = await _planner.addDay(widget.tripId, backup: form.date == null);
    if (added case Success(:final value)) {
      if (form.name.trim().isNotEmpty) await _planner.setDayTitle(value, form.name);
      if (form.date != null) {
        final pinned = await _planner.pinDay(value, form.date);
        if (mounted) reportResult(context, pinned);
      }
    } else if (mounted) {
      reportResult(context, added);
    }
  }

  Future<void> _rename(PlacesSection section) async {
    final form = await _dayForm(section: section);
    if (form == null || !mounted) return;
    reportResult(context, await _planner.setDayTitle(section.dayId!, form.name));
  }

  /// Gives the day a date: a day without one joins the dated days first,
  /// then is pinned to it.
  Future<void> _setDate(PlacesSection section) async {
    final day = section.day!;
    final picked = await _pickDate(context, day.date == null ? null : DateTime(day.date!.year, day.date!.month, day.date!.day));
    if (picked == null || !mounted) return;
    if (day.isBackup) {
      final moved = await _planner.moveDayToTrip(widget.tripId, day.day);
      if (moved is Failure) {
        if (mounted) reportResult(context, moved);
        return;
      }
    }
    final result = await _planner.pinDay(day.day.id, picked);
    if (mounted) reportResult(context, result);
  }

  /// Takes the day's date off: unpinned, and among the days without dates,
  /// so it keeps only its name.
  Future<void> _clearDate(PlacesSection section) async {
    final day = section.day!;
    if (day.isPinned) {
      final unpinned = await _planner.pinDay(day.day.id, null);
      if (unpinned is Failure) {
        if (mounted) reportResult(context, unpinned);
        return;
      }
    }
    if (!day.isBackup) {
      final result = await _planner.moveDayToBackup(widget.tripId, day.day.copyWith(pinnedDate: const Value(null)));
      if (mounted) reportResult(context, result);
    }
  }

  Future<void> _deleteDay(PlacesSection section) async {
    final l10n = context.l10n;
    final title = sectionTitle(context, section);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.placesDeleteDayTitle(title)),
        content: Text(l10n.placesDeleteDayBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.placeCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.placesDeleteDay)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Its places go to Unsorted first, so deleting the day leaves them in the trip.
    final itemIds = [for (final p in section.places) ...p.itemIds];
    if (itemIds.isNotEmpty) {
      final off = await _planner.unscheduleItems(itemIds);
      if (off is Failure) {
        if (mounted) reportResult(context, off);
        return;
      }
    }
    final result = await _planner.removeDay(widget.tripId, section.dayId!);
    if (mounted) reportResult(context, result);
  }

  Future<void> _move(PlacesSection section, TripPlace place, int by) async {
    final target = reorderTarget(section.places, place, by);
    if (target == null || place.itemIds.isEmpty) return;
    final result = await _planner.moveItems(itemIds: place.itemIds, toDayId: section.dayId!, beforeItemId: target.before);
    if (mounted && result is Failure) reportResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final planner = ref.watch(plannerViewProvider(widget.tripId));
    final canEdit = ref.watch(canEditTripProvider(widget.tripId));
    final plannerView = planner.valueOrNull;
    if (plannerView == null) {
      return planner.hasError ? Center(child: Text('${planner.error}')) : const Center(child: CircularProgressIndicator());
    }
    final view = buildTripPlacesView(plannerView);
    final contents = _contentsOf(view);
    final labels = ref.watch(tripAnimeLabelsProvider(widget.tripId)).valueOrNull ?? const <String, List<String>>{};
    final pos = _follower.position;
    final lat = pos?.latitude;
    final lng = pos?.longitude;
    if (!canEdit) _reordering = null;
    final all = view.all;
    final nearest = _nearest && lat != null;
    final query = _query.trim();
    final today = normalizeDay(ref.watch(homeClockProvider)());
    final todaySection = view.todaySection(today);

    List<String> labelsOf(TripPlace p) => {for (final s in p.stops) ...?labels[s.id]}.toList();
    Widget row(TripPlace p, {PlacesSection? section, String? match}) {
      final content = contents[p.id]!;
      final reorder = section != null && section.dayId != null && section.dayId == _reordering;
      return _PlaceRow(
        key: ValueKey('place-${section?.dayId ?? 'x'}-${p.id}'),
        place: p,
        content: content,
        labels: labelsOf(p),
        match: match,
        distance: content.distanceFrom(lat, lng),
        onTap: reorder ? null : () => _open(p),
        onUp: reorder && section.places.first != p ? () => _move(section, p, -1) : null,
        onDown: reorder && section.places.last != p ? () => _move(section, p, 1) : null,
        reordering: reorder,
      );
    }

    final items = <Widget>[];
    if (todaySection != null && todaySection.places.isNotEmpty && query.isEmpty) {
      final places = byDistance(
        todaySection.places,
        (p) => contents[p.id]!.spots.firstOrNull?.point ?? _point(p.stop),
        lat: lat,
        lng: lng,
      );
      final first = places.first;
      final d = contents[first.id]!.distanceFrom(lat, lng);
      items.add(_TodayCard(
        title: l10n.placesTodayTitle(sectionDate(context, todaySection) ?? '', sectionTitle(context, todaySection)),
        line: d == null
            ? l10n.placesTodayStart(todaySection.places.length, first.name)
            : l10n.placesTodayNearest(todaySection.places.length, first.name, distanceText(d)),
        content: contents[first.id]!,
        onTap: () => _open(first),
      ));
    }

    if (query.isNotEmpty) {
      final rows = <Widget>[];
      for (final p in all) {
        final m = matchPlace(p, contents[p.id]!, query);
        if (!m.any) continue;
        final why = [
          if (m.name) l10n.placesMatchName,
          if (m.spots.isNotEmpty) l10n.placesMatchSpots(m.spots.take(3).join('、')),
          if (m.frames.isNotEmpty)
            l10n.placesMatchFrames(m.frames.length, m.frames.take(2).map((f) => f.episode ?? '').join('、')),
        ].join(' · ');
        rows.add(row(p, match: why));
      }
      items.add(rows.isEmpty ? _Empty(text: l10n.placesNoMatch(query)) : _Card(children: rows));
    } else if (nearest) {
      final sorted = byDistance(all, (p) => contents[p.id]!.spots.firstOrNull?.point ?? _point(p.stop), lat: lat, lng: lng);
      items.add(_SectionHeader(title: l10n.placesNearestHeading));
      items.add(_Card(children: [for (final p in sorted) row(p)]));
    } else {
      for (final s in view.sections) {
        if (s.isUnsorted && s.places.isEmpty) continue;
        final reorder = s.dayId != null && s.dayId == _reordering;
        items.add(_SectionHeader(
          key: ValueKey('section-${s.dayId ?? 'unsorted'}'),
          title: sectionTitle(context, s),
          date: s.isUnsorted ? null : (sectionDate(context, s) ?? l10n.placeNoDate),
          today: s == todaySection,
          color: sectionColor(Theme.of(context), view, s),
          trailing: !canEdit || s.isUnsorted
              ? null
              : reorder
                  ? TextButton(key: const Key('reorderDone'), onPressed: () => setState(() => _reordering = null), child: Text(l10n.placesDone))
                  : _DayMenu(
                      section: s,
                      onRename: () => _rename(s),
                      onSetDate: () => _setDate(s),
                      onClearDate: s.day!.date == null ? null : () => _clearDate(s),
                      onReorder: s.places.length < 2 ? null : () => setState(() => _reordering = s.dayId),
                      onDelete: () => _deleteDay(s),
                    ),
        ));
        items.add(s.places.isEmpty ? _Card(children: [_Empty(text: l10n.placesEmptyDay, dense: true)]) : _Card(children: [for (final p in s.places) row(p, section: s)]));
      }
      if (all.isEmpty) {
        items.add(_Empty(text: l10n.placesEmpty));
        if (canEdit) {
          items.add(Center(
            child: FilledButton.icon(
              onPressed: () => openAddStopsSheet(context, widget.tripId),
              icon: const Icon(Icons.add),
              label: Text(l10n.placesAddPlaces),
            ),
          ));
        }
      }
      if (canEdit) {
        items.add(Padding(
          padding: const EdgeInsets.only(top: 14),
          child: OutlinedButton(
            key: const Key('newDayButton'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _newDay,
            child: Text(l10n.placesNewDay),
          ),
        ));
      }
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('placesSearch'),
                      controller: _search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.placesSearchHint,
                        isDense: true,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.placesClearSearch,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (lat != null) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      key: const Key('placesNearest'),
                      label: Text(l10n.placesSortNearest),
                      selected: _nearest,
                      onSelected: (v) => setState(() => _nearest = v),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('placesList'),
                padding: EdgeInsets.fromLTRB(16, 4, 16, canEdit ? 96 : 32),
                itemCount: items.length,
                itemBuilder: (_, i) => items[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [date] as a calendar day, whatever its time and zone.
DateTime normalizeDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// A picked [date] as the locale writes it.
String sectionDateOf(BuildContext context, DateTime date) => MaterialLocalizations.of(context).formatMediumDate(date);

LatLng _point(Stop stop) => LatLng(stop.lat, stop.lng);

/// A day's name and, for a new one, its date if it has one.
class _DayForm extends StatefulWidget {
  final PlacesSection? section;
  final Future<DateTime?> Function(BuildContext context, DateTime? initial) pickDate;

  const _DayForm({required this.section, required this.pickDate});

  @override
  State<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends State<_DayForm> {
  late final _name = TextEditingController(text: widget.section?.day == null ? '' : (dayTitleOf(widget.section!.day!) ?? ''));
  DateTime? _date;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, (name: _name.text, date: _date));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isNew = widget.section == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isNew ? l10n.placesNewDayTitle : l10n.placesRenameTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                key: const Key('dayNameField'),
                controller: _name,
                autofocus: true,
                maxLength: 30,
                decoration: InputDecoration(labelText: l10n.placesDayName, hintText: l10n.placesDayNameHint),
                onSubmitted: (_) => _done(),
              ),
              if (isNew)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(_date == null ? l10n.placesWithDate : sectionDateOf(context, _date!)),
                  trailing: _date == null
                      ? null
                      : IconButton(
                          tooltip: l10n.placesClearDate,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _date = null),
                        ),
                  onTap: () async {
                    final picked = await widget.pickDate(context, _date);
                    if (picked != null && mounted) setState(() => _date = picked);
                  },
                ),
              const SizedBox(height: 8),
              FilledButton(key: const Key('daySave'), onPressed: _done, child: Text(isNew ? l10n.placesCreate : l10n.placesSave)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? date;
  final bool today;
  final Color? color;
  final Widget? trailing;

  const _SectionHeader({super.key, required this.title, this.date, this.today = false, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            if (color != null) ...[
              Container(
                key: const Key('sectionDot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (date != null) ...[
              const SizedBox(width: 8),
              Text(date!, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
            if (today) ...[
              const SizedBox(width: 6),
              Container(
                key: const Key('todayBadge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: theme.trip.teaSoft, borderRadius: BorderRadius.circular(10)),
                child: Text(context.l10n.placesToday, style: theme.textTheme.labelSmall?.copyWith(color: theme.trip.tea, fontWeight: FontWeight.w700)),
              ),
            ],
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A day's options for people who can edit the trip.
class _DayMenu extends StatelessWidget {
  final PlacesSection section;
  final VoidCallback onRename;
  final VoidCallback onSetDate;
  final VoidCallback? onClearDate;
  final VoidCallback? onReorder;
  final VoidCallback onDelete;

  const _DayMenu({
    required this.section,
    required this.onRename,
    required this.onSetDate,
    required this.onClearDate,
    required this.onReorder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = sectionDate(context, section);
    return PopupMenuButton<String>(
      key: ValueKey('dayMenu-${section.dayId}'),
      tooltip: l10n.placesDayOptions(sectionTitle(context, section)),
      icon: const Icon(Icons.more_horiz),
      onSelected: (v) => switch (v) {
        'rename' => onRename(),
        'date' => onSetDate(),
        'undate' => onClearDate?.call(),
        'reorder' => onReorder?.call(),
        'delete' => onDelete(),
        _ => null,
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l10n.placesRename)),
        PopupMenuItem(value: 'date', child: Text(date == null ? l10n.placesSetDate : l10n.placesChangeDate(date))),
        if (onClearDate != null)
          PopupMenuItem(
            value: 'undate',
            child: ListTile(contentPadding: EdgeInsets.zero, title: Text(l10n.placesClearDate), subtitle: Text(l10n.placesClearDateHint)),
          ),
        if (onReorder != null) PopupMenuItem(key: const Key('dayReorder'), value: 'reorder', child: Text(l10n.placesReorder)),
        PopupMenuItem(
          key: const Key('dayDelete'),
          value: 'delete',
          child: ListTile(contentPadding: EdgeInsets.zero, title: Text(l10n.placesDeleteDay), subtitle: Text(l10n.placesDeleteDayHint)),
        ),
      ],
    );
  }
}

/// Rows in a rounded card, a line between them.
class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: theme.colorScheme.outlineVariant),
            c,
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  final bool dense;

  const _Empty({required this.text, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: dense ? 18 : 40),
      child: Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

/// The place's thumbnail: its latest photo with the frame inset, else its
/// first frame.
class _Thumb extends StatelessWidget {
  final PlaceContent content;
  final double width;

  const _Thumb({required this.content, this.width = 96});

  @override
  Widget build(BuildContext context) {
    final latest = content.latestShot;
    final frame = latest == null
        ? content.firstFrame
        : content.frames.where((f) => content.shot[f.id]?.id == latest.id).firstOrNull ?? content.firstFrame;
    return FrameCell(frame: frame, photo: latest, width: width, height: width * 9 / 16);
  }
}

class _PlaceRow extends StatelessWidget {
  final TripPlace place;
  final PlaceContent content;
  final List<String> labels;

  /// Why a search found it.
  final String? match;
  final double? distance;
  final VoidCallback? onTap;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final bool reordering;

  const _PlaceRow({
    super.key,
    required this.place,
    required this.content,
    required this.labels,
    required this.match,
    required this.distance,
    required this.onTap,
    required this.onUp,
    required this.onDown,
    required this.reordering,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    final shot = content.shotCount;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        child: Row(
          children: [
            _Thumb(content: content),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      children: [
                        TextSpan(text: '${l10n.placeSpotCount(content.spots.length)} · ${l10n.placeFrameCount(content.frameCount)}'),
                        if (shot > 0) ...[
                          const TextSpan(text: ' · '),
                          TextSpan(text: l10n.placeShotCount(shot), style: TextStyle(color: p.tea, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  if (match != null)
                    Text(match!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: muted))
                  else if (labels.isNotEmpty)
                    Text(labels.take(2).join('、'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: p.wisteria)),
                ],
              ),
            ),
            if (reordering) ...[
              IconButton(key: ValueKey('up-${place.id}'), tooltip: l10n.placesMoveUp, onPressed: onUp, icon: const Icon(Icons.keyboard_arrow_up)),
              IconButton(key: ValueKey('down-${place.id}'), tooltip: l10n.placesMoveDown, onPressed: onDown, icon: const Icon(Icons.keyboard_arrow_down)),
            ] else ...[
              if (distance != null)
                Text(distanceText(distance!), style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              Icon(Icons.chevron_right, color: muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final String title;
  final String line;
  final PlaceContent content;
  final VoidCallback onTap;

  const _TodayCard({required this.title, required this.line, required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        key: const Key('todayCard'),
        color: p.teaSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Thumb(content: content),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: p.tea)),
                      const SizedBox(height: 2),
                      Text(line, style: theme.textTheme.bodySmall),
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
}
