import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/thumbnail_cache_provider.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../camera/services/photo_edit_route.dart';
import '../../trip/models/trip_summary.dart';
import '../../trip/providers/trip_list_providers.dart';
import '../controllers/place_controller.dart';
import '../models/frames.dart';
import '../providers/place_providers.dart';

// The parts of a place's page, shared by a library place and a trip's stop.

/// Whether a frame has an image to show: a file on the device, or a link
/// that the thumbnail cache can fetch (a frame on a stop someone else added).
bool frameHasImage(NewReferenceImage f) =>
    (f.localPath?.isNotEmpty ?? false) || (f.remoteUrl?.isNotEmpty ?? false);

/// A local copy of a frame that only has a link, from the thumbnail cache.
/// Null while offline or when the host refuses.
final cachedFramePathProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, url) => ref.watch(thumbnailCacheServiceProvider).getOrFetchThumbnail(url),
);

/// A file on the device (or URL on Web) to show [frame] from: its own, else
/// the cached copy of its link.
Future<String?> framePath(WidgetRef ref, NewReferenceImage frame) async {
  final local = frame.localPath;
  if (local != null && local.isNotEmpty && await mediaExists(local)) return local;
  final url = frame.remoteUrl;
  if (url == null || url.isEmpty) return null;
  if (kIsWeb) return url;
  return ref.read(cachedFramePathProvider(url).future);
}

/// Like [framePath], but only a file already on the device (or remote URL on
/// Web). Never downloads to disk.
Future<String?> framePathOnDevice(WidgetRef ref, NewReferenceImage frame) async {
  final local = frame.localPath;
  if (local != null && local.isNotEmpty && await mediaExists(local)) return local;
  final url = frame.remoteUrl;
  if (url == null || url.trim().isEmpty) return null;
  if (kIsWeb) return url;
  final cached = await ref.read(thumbnailCacheServiceProvider).getCacheFile(url);
  return await cached.exists() ? cached.path : null;
}

/// A frame's image: the file on the device, else the cached copy of its link
/// (or direct network image on Web).
class FrameImage extends ConsumerWidget {
  final NewReferenceImage frame;
  final int cacheWidth;
  final String? semanticLabel;

  const FrameImage({super.key, required this.frame, this.cacheWidth = 1280, this.semanticLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).trip;
    final broken = ColoredBox(color: p.wisteriaSoft, child: Icon(Icons.broken_image_outlined, color: p.wisteria));
    Widget imageWidget(String path, Widget Function() orElse) => PlatformImage(
          path,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) => orElse(),
          semanticLabel: semanticLabel,
        );
    Widget remote() {
      final url = frame.remoteUrl;
      if (url == null || url.isEmpty) return broken;
      if (kIsWeb) return imageWidget(url, () => broken);
      final cached = ref.watch(cachedFramePathProvider(url));
      return cached.when(
        data: (path) => path == null ? broken : imageWidget(path, () => broken),
        loading: () => ColoredBox(color: p.wisteriaSoft),
        error: (_, _) => broken,
      );
    }

    final local = frame.localPath;
    final hasUsableLocal = local != null && local.isNotEmpty && (!kIsWeb || isRemoteOrMemoryUri(local));
    return hasUsableLocal ? imageWidget(local, remote) : remote();
  }
}

/// Where a spot's data came from, at the foot of its page.
class SourceNote extends StatelessWidget {
  final String text;

  const SourceNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class FrameHero extends StatelessWidget {
  final List<NewReferenceImage> frames;
  final int index;
  final ValueChanged<int> onPage;

  /// Adds frames from the gallery. Without it, the filler only says there are none.
  final VoidCallback? onAdd;
  final ValueChanged<int> onOpen;

  const FrameHero({super.key, required this.frames, required this.index, required this.onPage, required this.onOpen, this.onAdd});

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
              if (onAdd != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add a frame')),
              ],
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
                  child: FrameImage(frame: frames[i], semanticLabel: frameCaption(frames[i]) ?? 'Anime frame ${i + 1}'),
                ),
              ),
              if (caption != null) Positioned(left: 12, bottom: 12, child: PageChip(caption)),
              Positioned(right: 12, bottom: 12, child: PageChip('${index + 1} / ${frames.length}')),
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

class PageChip extends StatelessWidget {
  final String text;

  const PageChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// The last of the action buttons, which differs between a place and a stop.
typedef PageAction = ({IconData icon, String label, VoidCallback onTap});

class PageActions extends StatelessWidget {
  final NewReferenceImage? frame;
  final VoidCallback onShoot;
  final VoidCallback? onFloat;
  final VoidCallback onDirections;
  final PageAction last;

  const PageActions({
    super.key,
    required this.frame,
    required this.onShoot,
    required this.onFloat,
    required this.onDirections,
    required this.last,
  });

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
            // Twice a small button: any wider and "Directions" breaks mid-word on a phone.
            flex: 2,
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
        small(last.icon, last.label, last.onTap),
      ],
      ),
    );
  }
}

/// Who sees a section: everyone in the trip, or only the user.
enum SectionScope { onlyYou, trip }

/// A card with a title row and a mark for who sees it.
class PageSection extends StatelessWidget {
  final String title;
  final SectionScope? scope;
  final Widget? trailing;
  final Widget child;
  final Color? color;

  const PageSection({super.key, required this.title, required this.child, this.scope, this.trailing, this.color});

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
                // The mark gives way first on a narrow screen or with large text.
                if (scope != null) Flexible(child: ScopeMark(scope!)),
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

/// "Only you", or "Shared with the trip".
class ScopeMark extends StatelessWidget {
  final SectionScope scope;

  const ScopeMark(this.scope, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shared = scope == SectionScope.trip;
    final color = shared ? theme.trip.wisteria : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: shared ? theme.trip.wisteriaSoft : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(shared ? Icons.group_outlined : Icons.lock_outline, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              shared ? 'Shared with the trip' : 'Only you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line: how often the user has been here, and a button to note that
/// they are here now. Without [onHere] it carries the "Only you" mark instead.
class VisitsRow extends ConsumerWidget {
  final String placeKey;
  final VoidCallback? onHere;

  const VisitsRow({super.key, required this.placeKey, this.onHere});

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
        if (onHere != null) TextButton(onPressed: onHere, child: const Text("I'm here")) else const ScopeMark(SectionScope.onlyYou),
      ],
    );
  }
}

/// A spot's facts, as label and value rows. Pages leave the card out while
/// none of [facts] is filled in; see [anyFacts].
class FactsCard extends StatelessWidget {
  final String title;
  final List<(String, String?)> facts;
  final SectionScope? scope;

  /// A line under the facts, such as who an edit reaches.
  final String? footer;

  const FactsCard({super.key, required this.title, required this.facts, this.scope, this.footer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = facts.where((f) => f.$2?.trim().isNotEmpty ?? false).toList();
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return PageSection(
      title: title,
      scope: scope,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in shown)
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
          if (footer != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(footer!, style: muted)),
        ],
      ),
    );
  }
}

/// Whether any of a spot's [facts] is filled in.
bool anyFacts(List<(String, String?)> facts) => facts.any((f) => f.$2?.trim().isNotEmpty ?? false);

/// [text] cut to at most [max] UTF-16 code units, without splitting an emoji
/// or another character that takes two.
String truncateUtf16(String text, int max) {
  if (text.length <= max) return text;
  final last = text.codeUnitAt(max - 1);
  // A high surrogate at the end would lose its other half.
  return text.substring(0, last >= 0xD800 && last <= 0xDBFF ? max - 1 : max);
}

/// The text a page's edit mode works on: a spot's name, address and facts,
/// and its notes. Each starts from what is saved, so [changed] tells whether
/// there is anything to save.
class EditDraft {
  final PlaceFacts initial;
  final Map<String, String> initialNotes;
  final name = TextEditingController();
  final address = TextEditingController();
  final access = TextEditingController();
  final about = TextEditingController();
  final hours = TextEditingController();
  final contact = TextEditingController();
  final links = TextEditingController();
  final Map<String, TextEditingController> notes;

  /// [notes]: the page's notes by key, such as the trip note and the user's own.
  EditDraft(this.initial, {Map<String, String?> notes = const {}})
      : initialNotes = {for (final MapEntry(:key, :value) in notes.entries) key: value ?? ''},
        notes = {for (final MapEntry(:key, :value) in notes.entries) key: TextEditingController(text: value ?? '')} {
    name.text = initial.name;
    address.text = initial.address ?? '';
    access.text = initial.accessTips ?? '';
    about.text = initial.description ?? '';
    hours.text = initial.businessHours ?? '';
    contact.text = initial.contactInfo ?? '';
    links.text = initial.links ?? '';
  }

  PlaceFacts get facts => PlaceFacts(
        name: name.text,
        address: address.text,
        accessTips: access.text,
        description: about.text,
        businessHours: hours.text,
        contactInfo: contact.text,
        links: links.text,
      );

  static String _norm(String? s) => s?.trim() ?? '';

  bool get factsChanged {
    final f = facts;
    return _norm(f.name) != _norm(initial.name) ||
        _norm(f.address) != _norm(initial.address) ||
        _norm(f.accessTips) != _norm(initial.accessTips) ||
        _norm(f.description) != _norm(initial.description) ||
        _norm(f.businessHours) != _norm(initial.businessHours) ||
        _norm(f.contactInfo) != _norm(initial.contactInfo) ||
        _norm(f.links) != _norm(initial.links);
  }

  bool noteChanged(String key) => _norm(notes[key]!.text) != _norm(initialNotes[key]);

  bool get changed => factsChanged || notes.keys.any(noteChanged);

  void dispose() {
    for (final c in [name, address, access, about, hours, contact, links, ...notes.values]) {
      c.dispose();
    }
  }
}

Widget _field(
  BuildContext context,
  String key,
  TextEditingController controller,
  String label, {
  int lines = 1,
  String? hint,
  String? error,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key('placeField_$key'),
        controller: controller,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, hintText: hint, errorText: error),
      ),
    );

/// The name and address as fields, where the title is outside edit mode.
class NameFields extends StatelessWidget {
  final EditDraft draft;
  final String? nameError;

  const NameFields({super.key, required this.draft, this.nameError});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _field(context, 'name', draft.name, 'Name', error: nameError),
          _field(context, 'address', draft.address, 'Address'),
        ],
      );
}

/// The facts as fields, in edit mode.
class FactsFields extends StatelessWidget {
  final String title;
  final EditDraft draft;
  final SectionScope? scope;
  final String? footer;

  const FactsFields({super.key, required this.title, required this.draft, this.scope, this.footer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageSection(
      title: title,
      scope: scope,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _field(context, 'access', draft.access, 'Getting there', lines: 3, hint: 'Nearest station, where to stand, the best time of day'),
          _field(context, 'about', draft.about, 'About', lines: 3),
          _field(context, 'hours', draft.hours, 'Hours'),
          _field(context, 'contact', draft.contact, 'Contact'),
          _field(context, 'links', draft.links, 'Links', lines: 2, hint: 'One link per line'),
          if (footer != null)
            Text(footer!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A note in view mode: the user's own note, or a stop's trip note. Pages
/// leave it out while it's empty.
class NoteView extends StatelessWidget {
  final String title;
  final String note;
  final SectionScope scope;

  const NoteView({super.key, required this.title, required this.note, required this.scope});

  @override
  Widget build(BuildContext context) => PageSection(
        title: title,
        scope: scope,
        child: Text(note, style: Theme.of(context).textTheme.bodyMedium),
      );
}

/// A note's field in edit mode.
class NoteField extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String hint;
  final SectionScope scope;
  final Key fieldKey;

  /// The most UTF-16 code units the note may have, counted like Dart's
  /// `String.length` and Firestore rules' `size()`. TextField's own
  /// `maxLength` counts characters as people see them, and lets more through.
  final int? maxLength;

  const NoteField({
    super.key,
    required this.title,
    required this.controller,
    required this.hint,
    required this.scope,
    required this.fieldKey,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = maxLength;
    return PageSection(
      title: title,
      scope: scope,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            key: fieldKey,
            controller: controller,
            minLines: 3,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              if (max != null)
                TextInputFormatter.withFunction((old, next) {
                  if (next.text.length <= max) return next;
                  final text = truncateUtf16(next.text, max);
                  return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
                }),
            ],
            decoration: InputDecoration(hintText: hint),
          ),
          if (max != null)
            ListenableBuilder(
              listenable: controller,
              builder: (_, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${controller.text.length} / $max',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The app bar's way into and out of a page's edit mode.
class EditModeButton extends StatelessWidget {
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onDone;

  const EditModeButton({super.key, required this.editing, required this.onEdit, required this.onDone});

  @override
  Widget build(BuildContext context) => editing
      ? Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(onPressed: onDone, icon: const Icon(Icons.check), label: const Text('Done')),
        )
      : IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: onEdit);
}

/// Asks whether to drop the changes made in edit mode. True to drop them.
Future<bool> confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard your changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard')),
        ],
      ),
    ) ??
    false;

/// [children] with a gap between each two, for a page whose sections come
/// and go.
List<Widget> spaced(List<Widget> children, {double gap = 14}) => [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
    ];

class PhotosCard extends ConsumerWidget {
  final String placeKey;
  final List<NewReferenceImage> frames;
  final VoidCallback onAdd;

  const PhotosCard({super.key, required this.placeKey, required this.frames, required this.onAdd});

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
    return PageSection(
      title: 'My photos',
      scope: SectionScope.onlyYou,
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
                            child: PlatformImage(
                              photo.localPath,
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
      builder: (viewerContext) => ImageViewer(
        path: photo.localPath,
        title: DateFormat.yMMMd().add_Hm().format(photo.takenAt ?? photo.createdAt),
        actions: [
          ViewerAction('Edit', () {
            final framePath = (frame?.localPath?.isNotEmpty ?? false)
                ? frame!.localPath
                : frame?.remoteUrl;
            viewerContext.push(PhotoEditArgs(
              path: photo.localPath,
              placeKey: placeKey,
              tripId: photo.tripId,
              photoId: photo.id,
              referencePath: framePath,
              referenceImageId: frame?.id,
            ).location);
          }, primary: true),
          ViewerAction('Save to device', () async {
            final result = await place.saveToGallery(photo.localPath);
            messenger.showSnackBar(SnackBar(content: Text(result is Failure ? (result as Failure).error : 'Saved to your gallery.')));
          }),
          ViewerAction('Delete', () async {
            Navigator.of(viewerContext).pop();
            final result = await place.deletePhoto(photo);
            messenger.showSnackBar(SnackBar(content: Text(result is Failure ? (result as Failure).error : 'Deleted the photo.')));
          }),
        ],
      ),
    ));
  }
}

class LocationCard extends StatelessWidget {
  final double lat;
  final double lng;

  /// Opens the map to move the pin. Without it there is no "Move pin".
  final VoidCallback? onMovePin;

  const LocationCard({super.key, required this.lat, required this.lng, this.onMovePin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = LatLng(lat, lng);
    return PageSection(
      title: 'Location',
      trailing: onMovePin == null ? null : TextButton(onPressed: onMovePin, child: const Text('Move pin')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: IgnorePointer(
                child: AppMap(
                  pins: [MapPin(id: 'here', point: at, name: 'This place', color: theme.trip.wisteria)],
                  interactive: false,
                  cluster: false,
                  attribution: false,
                  // A moved pin centres the map on its new spot.
                  fitKey: at,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} · map © OpenStreetMap contributors',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class ViewerAction {
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const ViewerAction(this.label, this.onTap, {this.primary = false});
}

/// A frame or photo full screen, pinch to zoom, with its actions below.
class ImageViewer extends StatelessWidget {
  final String path;
  final String title;
  final List<ViewerAction> actions;

  const ImageViewer({super.key, required this.path, required this.title, required this.actions});

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
              child: Center(child: PlatformImage(path, fit: BoxFit.contain)),
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

/// Source chosen when adding a reference frame to a place.
enum AddFrameMethod { gallery, link }

/// Asks whether to pick reference frames from the device's gallery (local-only)
/// or paste an external image link (syncs to shared trips).
Future<AddFrameMethod?> showAddPlaceFrameSheet(BuildContext context) {
  return showModalBottomSheet<AddFrameMethod>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Add anime frame', style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from photos'),
            subtitle: const Text('Saved on this phone only — gallery frames do not auto-sync to shared trips.'),
            onTap: () => Navigator.pop(sheetContext, AddFrameMethod.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.link_outlined),
            title: const Text('Add image link'),
            subtitle: const Text('Paste an https:// image URL — syncs with everyone in a shared trip.'),
            onTap: () => Navigator.pop(sheetContext, AddFrameMethod.link),
          ),
        ],
      ),
    ),
  );
}

/// Prompts for an external image URL (and optional episode label) and returns
/// the validated input, or null when cancelled.
Future<({String url, String? episode})?> askFrameImageUrl(BuildContext context) {
  return showDialog<({String url, String? episode})>(
    context: context,
    builder: (dialogContext) => const _FrameUrlDialog(),
  );
}

class _FrameUrlDialog extends StatefulWidget {
  const _FrameUrlDialog();

  @override
  State<_FrameUrlDialog> createState() => _FrameUrlDialogState();
}

class _FrameUrlDialogState extends State<_FrameUrlDialog> {
  final _url = TextEditingController();
  final _episode = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _episode.dispose();
    super.dispose();
  }

  void _submit() {
    final check = validateFrameImageUrl(_url.text);
    if (check.error != null) {
      setState(() => _error = check.error);
      return;
    }
    final ep = _episode.text.trim();
    Navigator.pop(context, (url: check.url!, episode: ep.isEmpty ? null : ep));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add image link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Image URL',
              hintText: 'https://example.com/frame.jpg',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _episode,
            decoration: const InputDecoration(
              labelText: 'Episode (optional)',
              hintText: 'e.g. 5',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          Text(
            'Image links sync automatically across trip members. No image file is uploaded to our server.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

/// Source chosen when adding a reference frame to a shared trip stop.
enum AddStopFrameMethod { driveUpload, link, localGallery }

/// Asks whether an editor wants to upload photos via their Google Drive (`drive.file`),
/// paste an external image link, or pick a local-only photo onto a shared stop.
Future<AddStopFrameMethod?> showAddStopFrameSheet(BuildContext context) {
  return showModalBottomSheet<AddStopFrameMethod>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Add anime frame to stop', style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Upload photo via Google Drive'),
            subtitle: const Text('Uploads to your Google Drive (drive.file) with an "anyone with the link" URL so trip members see it.'),
            onTap: () => Navigator.pop(sheetContext, AddStopFrameMethod.driveUpload),
          ),
          ListTile(
            leading: const Icon(Icons.link_outlined),
            title: const Text('Add image link'),
            subtitle: const Text('Paste an https:// image URL — syncs with everyone in this trip.'),
            onTap: () => Navigator.pop(sheetContext, AddStopFrameMethod.link),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from photos (this device only)'),
            subtitle: const Text('Stays on this phone and does not upload or auto-sync.'),
            onTap: () => Navigator.pop(sheetContext, AddStopFrameMethod.localGallery),
          ),
        ],
      ),
    ),
  );
}

/// Subtle callout on a shared trip stop when one or more frames live only on
/// this device and won't sync automatically to collaborators.
class LocalFramesSyncNote extends StatelessWidget {
  final int count;
  final VoidCallback? onSyncViaDrive;

  const LocalFramesSyncNote({super.key, required this.count, this.onSyncViaDrive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = count == 1 ? '1 frame is' : '$count frames are';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.devices_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label saved on this phone only and will not auto-sync to trip members. '
                  'Sync via your Google Drive, Share local frames in the Members tab, or add an image link.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (onSyncViaDrive != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSyncViaDrive,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Sync via Google Drive'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
