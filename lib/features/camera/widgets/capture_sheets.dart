import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/platform_media.dart';
import '../../../core/utils/schedule_logic.dart' show TripStatus;
import '../../library/models/frames.dart';
import '../../library/models/library_entry.dart';
import '../../library/providers/library_providers.dart';
import '../../library/providers/place_providers.dart';
import '../../trip/providers/trip_list_providers.dart';
import '../services/photo_edit_route.dart';

// Sheets and routing shared by both Anime Camera flows — the in-app camera
// (`CameraScreen`, used on iOS) and the phone's own camera with a floating
// reference window (Android, `openAnimeCamera`) — and the photo editor they
// hand their shots to. Places and their anime frames come from the library.

/// Result of the photo editor's place picker ([pickPhotoPlace]): a place to
/// save the photo into, no place (the photo then only goes to the phone's
/// gallery), or a request to make a new place first.
class PhotoPlaceChoice {
  final String? placeKey;
  final bool createNew;

  const PhotoPlaceChoice.existing(String key) : placeKey = key, createNew = false;

  const PhotoPlaceChoice.none() : placeKey = null, createNew = false;

  const PhotoPlaceChoice.create() : placeKey = null, createNew = true;
}

/// Sheet of the library's places to take a frame from. Returns the picked
/// place's key, or null when the sheet is dismissed.
Future<String?> pickPlaceKey(BuildContext context, WidgetRef ref) async {
  final choice = await _showPlaceSheet(context, title: 'Frames from which place?');
  return choice?.placeKey;
}

/// The photo editor's place picker: which place the photo is saved into —
/// none (only the phone's gallery), a new one, or one from the library.
/// [current] is ticked. Null when the sheet is dismissed.
Future<PhotoPlaceChoice?> pickPhotoPlace(
  BuildContext context,
  WidgetRef ref, {
  String? current,
}) =>
    _showPlaceSheet(context, title: 'Save the photo to', current: current, choices: true);

Future<PhotoPlaceChoice?> _showPlaceSheet(
  BuildContext context, {
  required String title,
  String? current,
  bool choices = false,
}) {
  return showModalBottomSheet<PhotoPlaceChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.grey[900],
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _PlaceSheet(title: title, current: current, choices: choices),
    ),
  );
}

/// The library's places, searchable by name, address and label. Places that
/// are stops of a trip happening today come first, since that's usually
/// where the photo is being taken.
class _PlaceSheet extends ConsumerStatefulWidget {
  final String title;
  final String? current;

  /// Offers "No place" and "New place" above the list.
  final bool choices;

  const _PlaceSheet({required this.title, this.current, this.choices = false});

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  static const _tick = Icon(Icons.check, color: Colors.white);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(libraryEntriesProvider).valueOrNull;
    final labels = ref.watch(labelsListProvider(null)).valueOrNull ?? const <Label>[];
    final frames = ref.watch(placeFramePathsProvider).valueOrNull ?? const <String, List<String>>{};
    final today = _placesOnToday();
    final matches = entries == null
        ? null
        : filterLibrary(entries, LibraryFilter(query: _query, includeTripOnly: true), labels);
    final first = [...?matches?.where((e) => today.contains(e.place.placeKey))];
    final rest = [...?matches?.where((e) => !today.contains(e.place.placeKey))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('placeSheetSearch'),
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Search places, anime, tags',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.choices) ...[
          ListTile(
            leading: const Icon(Icons.location_off, color: Colors.white),
            title: const Text('No place', style: TextStyle(color: Colors.white)),
            subtitle: const Text("Only save it to the phone's gallery", style: TextStyle(color: Colors.white54)),
            trailing: widget.current == null ? _tick : null,
            onTap: () => Navigator.pop(context, const PhotoPlaceChoice.none()),
          ),
          ListTile(
            leading: const Icon(Icons.add_location_alt, color: Colors.white),
            title: const Text('New place', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Add it to your library, then save the photo there',
                style: TextStyle(color: Colors.white54)),
            onTap: () => Navigator.pop(context, const PhotoPlaceChoice.create()),
          ),
          const Divider(color: Colors.white24, height: 1),
        ],
        Expanded(
          child: matches == null
              ? const Center(child: CircularProgressIndicator())
              : matches.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.trim().isEmpty
                              ? 'Your library has no places yet.'
                              : 'No place matches “${_query.trim()}”.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        if (first.isNotEmpty) ...[
                          const _Header("On today's trip"),
                          for (final e in first) _row(e, frames[e.place.placeKey]),
                          if (rest.isNotEmpty) const _Header('All places'),
                        ],
                        for (final e in rest) _row(e, frames[e.place.placeKey]),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _row(LibraryEntry entry, List<String>? framePaths) {
    final place = entry.place;
    final anime = entry.labelsOf('anime').map((l) => l.name).join(', ');
    final about = [
      if (anime.isNotEmpty) anime else if (place.address?.isNotEmpty ?? false) place.address!,
      if (framePaths != null) framePaths.length == 1 ? '1 frame' : '${framePaths.length} frames',
    ].join(' · ');
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: framePaths == null
              ? const ColoredBox(color: Colors.white10, child: Icon(Icons.place, color: Colors.white54))
              : PlatformImage(
                  framePaths.first,
                  fit: BoxFit.cover,
                  cacheWidth: 144,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Colors.white10, child: Icon(Icons.broken_image, color: Colors.white54)),
                ),
        ),
      ),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
      subtitle: about.isEmpty
          ? null
          : Text(about, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
      trailing: place.placeKey == widget.current ? _tick : null,
      onTap: () => Navigator.pop(context, PhotoPlaceChoice.existing(place.placeKey)),
    );
  }

  /// The places that are stops of a trip happening today.
  Set<String> _placesOnToday() {
    final ongoing = {
      for (final t in ref.watch(tripSummariesProvider).valueOrNull ?? const [])
        if (t.status == TripStatus.ongoing) t.trip.id,
    };
    if (ongoing.isEmpty) return const {};
    return {
      for (final (placeKey, tripId) in ref.watch(placeTripLinksProvider).valueOrNull ?? const <(String, String)>[])
        if (ongoing.contains(tripId)) placeKey,
    };
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
        ),
      );
}

/// [placeKey]'s anime frames that have a file on the device, in the order
/// the place shows them: what [pickPlaceFrame] offers, and what the camera
/// switches between.
Future<List<NewReferenceImage>> placeFramesOnDevice(WidgetRef ref, String placeKey) async => [
      for (final f in await ref.read(placeRepositoryProvider).getReferenceImagesForPlace(placeKey))
        if (((f.localPath?.isNotEmpty ?? false) &&
                (!kIsWeb || isRemoteOrMemoryUri(f.localPath!))) ||
            (kIsWeb && (f.remoteUrl?.isNotEmpty ?? false)))
          f,
    ];

String? _usableFrameSource(NewReferenceImage frame) {
  final local = frame.localPath;
  if (local != null && local.isNotEmpty && (!kIsWeb || isRemoteOrMemoryUri(local))) {
    return local;
  }
  final remote = frame.remoteUrl;
  if (remote != null && remote.isNotEmpty) return remote;
  return null;
}

/// Sheet of [placeKey]'s anime frames. A place with a single frame skips the
/// sheet. Returns the picked frame once its file is confirmed on the device;
/// null when the sheet is dismissed or the place has none (with a snackbar).
Future<NewReferenceImage?> pickPlaceFrame(
  BuildContext context,
  WidgetRef ref,
  String placeKey,
) async {
  final frames = await placeFramesOnDevice(ref, placeKey);
  if (!context.mounted) return null;
  if (frames.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This place has no anime frames yet. Add some on its page.')),
    );
    return null;
  }

  final picked = frames.length == 1
      ? frames.single
      : await showModalBottomSheet<NewReferenceImage>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.grey[900],
          builder: (ctx) => FractionallySizedBox(
            heightFactor: 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Which frame?',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(12),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 16 / 11,
                    children: [
                      for (final frame in frames)
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx, frame),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox.expand(
                                    child: PlatformImage(
                                      _usableFrameSource(frame) ?? '',
                                      fit: BoxFit.cover,
                                      cacheWidth: 480,
                                      errorBuilder: (_, _, _) => const ColoredBox(
                                        color: Colors.white10,
                                        child: Icon(Icons.broken_image, color: Colors.white54),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                frameCaption(frame) ?? 'Anime frame',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  if (picked == null) return null;

  if (!await mediaExists(_usableFrameSource(picked))) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That frame's file is missing from this phone.")),
      );
    }
    return null;
  }
  return picked;
}

/// Hands a fresh capture straight to the photo editor, saving into
/// [placeKey] when the shot was taken for one. Without one nobody is asked
/// first: the photo goes to the phone's gallery, and the editor's place
/// button can add a place (or a new one). [tripId] files the photo under a
/// trip; without it the save picks the trip that has the place today.
/// [referencePath] / [referenceImageId] ride along for the editor's overlay,
/// Match Color, and the saved photo's link to its anime frame.
///
/// The editor is pushed as a route, so backing out of it (save, discard)
/// returns to whatever opened the camera.
void openCaptureInEditor(
  BuildContext context, {
  required String photoPath,
  String? placeKey,
  String? tripId,
  String? referencePath,
  String? referenceImageId,
}) {
  // A fresh capture isn't in the phone's gallery yet; the editor's Save puts
  // the original there next to the edit.
  context.push(PhotoEditArgs(
    path: photoPath,
    placeKey: placeKey,
    tripId: tripId,
    referencePath: referencePath,
    referenceImageId: referenceImageId,
    capture: true,
  ).location);
}
