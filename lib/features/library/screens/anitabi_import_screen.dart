import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../anime/models/bangumi_subject.dart';
import '../../anime/services/bangumi_search_service.dart';
import '../../poi/services/anitabi_api_service.dart';
import '../../trip/controllers/trip_stops_controller.dart';
import '../../trip/models/trip_summary.dart';
import '../providers/place_providers.dart';
import '../services/anitabi_import.dart';
import '../widgets/trip_picker.dart';

/// Imports an anime's pilgrimage spots from Anitabi into the library: find
/// the anime, tick the spots, and optionally add them to a trip as well.
class AnitabiImportScreen extends ConsumerStatefulWidget {
  /// Bangumi search and Anitabi loading, replaceable in tests.
  final Future<List<BangumiSubject>> Function(String query) searchAnime;
  final Future<AnitabiWork?> Function(String bangumiId) loadWork;

  const AnitabiImportScreen({super.key, this.searchAnime = _search, this.loadWork = _load});

  static Future<List<BangumiSubject>> _search(String query) => BangumiSearchService.searchByName(query);
  static Future<AnitabiWork?> _load(String bangumiId) => AnitabiImport.loadWork(bangumiId);

  @override
  ConsumerState<AnitabiImportScreen> createState() => _AnitabiImportScreenState();
}

class _AnitabiImportScreenState extends ConsumerState<AnitabiImportScreen> {
  final _query = TextEditingController();
  List<BangumiSubject>? _results;
  bool _searching = false;

  BangumiSubject? _subject;
  AnitabiWork? _work;
  String? _problem;
  bool _loading = false;
  final _picked = <String>{};
  bool _importing = false;

  /// Which host the frame thumbnails load from. A refusal from Anitabi's own
  /// image host moves them to its mirror, and a refusal there stops them for
  /// this visit: refused requests are never retried (CLAUDE.md, #57).
  String? _imageHost = 'image.anitabi.cn';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// [url] on the host thumbnails currently load from, or null when they
  /// don't load at all any more.
  String? _onCurrentHost(String? url) {
    final host = _imageHost;
    final uri = url == null ? null : Uri.tryParse(url);
    if (host == null || uri == null) return null;
    return uri.host == 'image.anitabi.cn' ? uri.replace(host: host).toString() : url;
  }

  void _onImageError(Object error) {
    if (error is! NetworkImageLoadException || (error.statusCode != 403 && error.statusCode != 429)) return;
    final refusedHost = error.uri.host;
    // Rows report after the frame is built, so the switch waits for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || refusedHost != _imageHost) return;
      setState(() => _imageHost = refusedHost == 'image.anitabi.cn' ? 'img-tc.anitabi.cn' : null);
    });
  }

  Widget _thumb(AnitabiSpot spot) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 96,
      height: 54,
      decoration: BoxDecoration(color: theme.trip.wisteriaSoft, borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.movie_outlined, size: 20, color: theme.trip.wisteria),
    );
    final url = _onCurrentHost(spot.thumbnailUrl);
    if (url == null) return placeholder;
    return GestureDetector(
      onTap: () => _preview(spot),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 96,
          height: 54,
          fit: BoxFit.cover,
          cacheWidth: 192,
          headers: const {'User-Agent': AnitabiApiService.userAgent},
          semanticLabel: 'Frame of ${spot.name}',
          errorBuilder: (_, error, _) {
            _onImageError(error);
            return placeholder;
          },
        ),
      ),
    );
  }

  Future<void> _preview(AnitabiSpot spot) {
    final url = _onCurrentHost(spot.imageUrl);
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (url != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  headers: const {'User-Agent': AnitabiApiService.userAgent},
                  errorBuilder: (_, error, _) {
                    _onImageError(error);
                    return const Center(child: Icon(Icons.broken_image_outlined));
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(spot.name, style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                [?spot.scene, if (spot.origin != null) '© ${spot.origin}'].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _search(String text) async {
    if (text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await widget.searchAnime(text);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
    });
  }

  Future<void> _open(BangumiSubject subject) async {
    setState(() {
      _subject = subject;
      _work = null;
      _problem = null;
      _loading = true;
      _picked.clear();
    });
    try {
      final work = await widget.loadWork(subject.id);
      if (!mounted) return;
      setState(() {
        _work = work;
        if (work == null || work.spots.isEmpty) _problem = 'Anitabi has no spots for this anime yet.';
        // Everything that can be imported starts ticked.
        _picked.addAll([for (final s in work?.spots ?? const <AnitabiSpot>[]) if (s.hasLocation) s.id]);
      });
    } on AnitabiUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _problem = e.blocked
          ? 'Anitabi is refusing this network for now. That usually clears within a day; trying again right away makes it last longer.'
          : "Couldn't reach Anitabi. Check the connection and try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final subject = _subject!;
    final work = _work!;
    final spots = [for (final s in work.spots) if (_picked.contains(s.id)) s];
    final destination = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: const Text('Save to the library'),
              subtitle: Text('${spots.length} spots, labelled with the anime'),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Save, and add them to a trip'),
              subtitle: const Text('They wait in the trip\'s backlog until you plan them'),
              onTap: () => Navigator.pop(context, 'trip'),
            ),
          ],
        ),
      ),
    );
    if (destination == null || !mounted) return;
    TripSummary? trip;
    if (destination == 'trip') {
      trip = await pickTripToAddTo(context, full: const {}, subtitle: 'Spots already in the trip are skipped.');
      if (trip == null || !mounted) return;
    }

    setState(() => _importing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await AnitabiImport.importSpots(
        places: ref.read(placeRepositoryProvider),
        bangumiId: subject.id,
        animeName: work.title ?? subject.name,
        spots: spots,
      );
      var addedToTrip = 0;
      if (trip != null) {
        final result = await ref.read(tripStopsControllerProvider.notifier).addFromLibrary(
              tripId: trip.trip.id,
              placeKeys: [for (final s in spots) if (s.hasLocation) s.placeKey],
            );
        if (result case Success(:final value)) addedToTrip = value;
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text([
          'Imported ${summary.added} new ${summary.added == 1 ? 'spot' : 'spots'}.',
          if (summary.alreadySaved > 0) '${summary.alreadySaved} were already in your library.',
          if (trip != null) 'Added $addedToTrip to ${trip.trip.title}.',
          if (summary.framesPending > 0) 'Their anime frames are downloading.',
        ].join(' ')),
        duration: const Duration(seconds: 6),
      ));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/library');
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text("Couldn't import the spots: $e")));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subject;
    return PopScope(
      canPop: subject == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _subject = null);
      },
      child: subject == null ? _searchView(context) : _spotsView(context, subject),
    );
  }

  Widget _searchView(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Anitabi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('animeSearchField'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Anime title, e.g. 響け！ユーフォニアム',
                prefixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: results == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Find the anime, then pick which of its pilgrimage spots to save. '
                      'Spots and frames come from Anitabi (anitabi.cn) under CC BY-NC-SA 4.0.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : results.isEmpty
                    ? const Center(child: Text('No anime found. Try the Japanese title.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        children: [
                          // Posters come from Bangumi; Anitabi's images are only
                          // fetched once a work is picked.
                          for (final s in results) _SubjectCard(subject: s, onTap: () => _open(s)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _spotsView(BuildContext context, BangumiSubject subject) {
    // Anitabi's title is the Japanese one; Bangumi's original name otherwise.
    final title = _work?.title ?? subject.name;
    final theme = Theme.of(context);
    final work = _work;
    final saved = {for (final p in ref.watch(placesListProvider(null)).valueOrNull ?? const <Place>[]) p.placeKey};
    final spots = work?.spots ?? const <AnitabiSpot>[];
    final importable = spots.where((s) => s.hasLocation).toList();
    final withFrames = importable.where((s) => s.imageUrl != null).toList();
    void pickOnly(Iterable<AnitabiSpot> these) => setState(() => _picked
      ..clear()
      ..addAll(these.map((s) => s.id)));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => setState(() => _subject = null)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Loading the spots from Anitabi…')],
              ),
            )
          : _problem != null
              ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(_problem!, textAlign: TextAlign.center)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              '${importable.length} spots',
                              if (spots.length > importable.length) '${spots.length - importable.length} without a location',
                            ].join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.done_all, size: 18),
                                label: Text('All ${importable.length}'),
                                onPressed: () => pickOnly(importable),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.image_outlined, size: 18),
                                label: Text('With frames ${withFrames.length}'),
                                onPressed: () => pickOnly(withFrames),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.remove_done, size: 18),
                                label: const Text('None'),
                                onPressed: () => pickOnly(const []),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: spots.length,
                        itemBuilder: (_, i) {
                          final s = spots[i];
                          final inLibrary = saved.contains(s.placeKey);
                          return CheckboxListTile(
                            value: s.hasLocation && _picked.contains(s.id),
                            onChanged: !s.hasLocation
                                ? null
                                : (v) => setState(() => v == true ? _picked.add(s.id) : _picked.remove(s.id)),
                            secondary: _thumb(s),
                            title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                ?s.scene,
                                if (inLibrary) 'in your library',
                                if (!s.hasLocation) 'no location on Anitabi',
                              ].join(' · '),
                              style: inLibrary ? TextStyle(color: theme.trip.tea) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _work == null || _problem != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const Key('anitabiImportButton'),
                  onPressed: _picked.isEmpty || _importing ? null : _import,
                  child: Text(_importing ? 'Importing…' : 'Import ${_picked.length} ${_picked.length == 1 ? 'spot' : 'spots'}'),
                ),
              ),
            ),
    );
  }
}

/// An anime from the Bangumi search: its poster, its Japanese title first
/// (the one Anitabi and the signs on site use), and the Chinese one below.
class _SubjectCard extends StatelessWidget {
  final BangumiSubject subject;
  final VoidCallback onTap;

  const _SubjectCard({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cn = subject.nameCn?.trim();
    final poster = Container(
      width: 72,
      height: 102,
      color: theme.trip.wisteriaSoft,
      child: Icon(Icons.movie_outlined, color: theme.trip.wisteria),
    );
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: subject.imageUrl == null
                    ? poster
                    : Image.network(
                        subject.imageUrl!,
                        width: 72,
                        height: 102,
                        fit: BoxFit.cover,
                        cacheWidth: 216,
                        errorBuilder: (_, _, _) => poster,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (cn != null && cn.isNotEmpty && cn != subject.name)
                      Text(cn, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (subject.summary?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        subject.summary!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
