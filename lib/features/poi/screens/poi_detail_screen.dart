import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../../calendar/models/time_chunk_model.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../calendar/repositories/time_chunk_repository.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../services/background_photo_save.dart';
import '../models/media_asset_model.dart';
import '../models/poi_model.dart';
import '../models/reference_image_model.dart';
import '../providers/media_provider.dart';
import '../providers/poi_provider.dart';
import '../../roi/providers/roi_provider.dart';
import '../../anime/providers/anime_provider.dart';
import '../../tag/providers/tag_provider.dart';
import '../../../core/utils/schedule_utils.dart';
import '../repositories/media_repository.dart';
import '../repositories/poi_repository.dart';


class PoiDetailScreen extends ConsumerWidget {
  final String poiId;

  const PoiDetailScreen({super.key, required this.poiId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poiAsync = ref.watch(poiByIdProvider(poiId));
    final mediaAsync = ref.watch(mediaAssetsByPoiProvider(poiId));
    final referenceImagesAsync =
        ref.watch(referenceImagesByPoiProvider(poiId));
    final chunksAsync = ref.watch(timeChunksByPoiProvider(poiId));

    return Scaffold(
      appBar: AppBar(
        title: poiAsync.when(
          data: (poi) => poi == null
              ? const Text('Spot Not Found')
              : Row(
                  mainAxisSize: MainAxisSize.min, // Prevent the Row from expanding infinitely
                  children: [
                    Flexible(
                      // Flexible ensures the text truncates instead of overflowing the AppBar
                      child: Text(
                        poi.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Error'),
        ),
        actions: [
          poiAsync.when(
            data: (poi) => poi == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleAction(context, ref, action, poi),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: poiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (poi) {
          if (poi == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Spot not found or has been deleted.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/pois'),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ROI breadcrumb
              if (poi.roiId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final roiAsync = ref.watch(roiByIdProvider(poi.roiId!));
                    return roiAsync.maybeWhen(
                      data: (roi) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => context.push('/rois/${poi.roiId}'),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                roi?.name ?? 'Unknown Location',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),

              // Anime hero chips (m:n via PoiAnimes)
              Consumer(
                builder: (context, ref, _) {
                  final animesAsync = ref.watch(animesForPoiProvider(poi.id));
                  return animesAsync.maybeWhen(
                    data: (animes) {
                      if (animes.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: animes
                              .map((anime) => ActionChip(
                                    avatar: Icon(
                                      Icons.movie_outlined,
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                    label: Text(
                                      anime.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    onPressed: () =>
                                        context.push('/anime/${anime.id}'),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),

              // Description
              if (poi.description != null) ...[
                Text(
                  poi.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],

              // Info card (address + gps + hours + contact)
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (poi.address != null)
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(poi.address!),
                        dense: true,
                      ),
                    ListTile(
                      leading: const Icon(Icons.gps_fixed),
                      title: Text('${poi.lat}, ${poi.lng}'),
                      dense: true,
                    ),
                    if (poi.businessHours != null)
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: Text(poi.businessHours!),
                        dense: true,
                      ),
                    if (poi.contactInfo != null)
                      ListTile(
                        leading: const Icon(Icons.contact_phone_outlined),
                        title: Text(poi.contactInfo!),
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tags (m:n via PoiTags)
              Consumer(
                builder: (context, ref, _) {
                  final tagsAsync = ref.watch(tagsForPoiProvider(poi.id));
                  return tagsAsync.maybeWhen(
                    data: (tags) {
                      if (tags.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.label_outline,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: tags
                                    .map((tag) => ActionChip(
                                          label: Text(tag.name),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          onPressed: () =>
                                              context.push('/tag/${tag.id}'),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),

              // Schedule section
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Schedule',
                      style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        _showScheduleDialog(context, ref, poi.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              chunksAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, _) => Text('Error: $err'),
                data: (chunks) {
                  if (chunks.isEmpty) {
                    return const Text('Not scheduled yet. Tap + to add.');
                  }
                  return Column(
                    children: chunks
                        .map((chunk) => Card(
                              child: ListTile(
                                leading: _statusIcon(chunk.status ?? 'backlog'),
                                title: Text(chunk.date ?? 'Backlog'),
                                subtitle: chunk.startTime != null
                                    ? Text(
                                        '${chunk.startTime} - ${chunk.endTime ?? '?'}')
                                    : null,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) =>
                                      handleTimeChunkAction(
                                          context, ref, action, chunk),
                                  itemBuilder: (context) {
                                    final List<PopupMenuEntry<String>> menuItems = [];
                                    if (chunk.status != 'backlog') {
                                      if (chunk.status != 'scheduled') {
                                        menuItems.add(const PopupMenuItem(
                                          value: 'scheduled',
                                          child: Text('Schedule'),
                                        ));
                                      }
                                      if (chunk.status != 'completed'){
                                        menuItems.add(const PopupMenuItem(
                                            value: 'completed', child: Text('Complete')));
                                      }
                                      if (chunk.status != 'skipped'){
                                        menuItems.add(const PopupMenuItem(
                                            value: 'skipped', child: Text('Skip')));
                                      }
                                      menuItems.add(const PopupMenuItem(
                                          value: 'backlog', child: Text('To Backlog')));
                                      menuItems.add(const PopupMenuDivider());
                                    }
                                    menuItems.add(const PopupMenuItem(value: 'edit', child: Text('Edit')));
                                    menuItems.add(const PopupMenuItem(value: 'delete', child: Text('Delete')));
                                    return menuItems;
                                  }
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),

              // Reference Images section
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reference Images',
                      style: Theme.of(context).textTheme.titleMedium),
                  FilledButton.tonalIcon(
                    onPressed: () => _addReferenceImage(context, ref, poi.id),
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              referenceImagesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, _) => Text('Error: $err'),
                data: (images) {
                  if (images.isEmpty) {
                    return const Text(
                      'No reference images. Add anime screenshots to overlay in camera.',
                    );
                  }
                  return Column(
                    children: images
                        .map((image) => _ReferenceImageTile(
                              image: image,
                              title: _referenceImageTitle(image),
                              onRename: () =>
                                  _renameReferenceImage(context, ref, image),
                              onDelete: () =>
                                  _deleteReferenceImage(context, ref, image),
                              onPreview: () => _showFullscreenImage(
                                context,
                                localPath: image.localPath,
                                remoteUrl: image.remoteUrl,
                                title: 'Reference Image',
                              ),
                            ))
                        .toList(),
                  );
                },
              ),

              // Media section
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Media Assets',
                      style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Desktop and web have no Anime Camera.
                      if (animeCameraSupported)
                        IconButton(
                          tooltip: 'Take photo',
                          onPressed: () =>
                              openAnimeCamera(context, ref, poiId: poi.id),
                          icon: const Icon(Icons.camera_alt),
                        ),
                      if (floatingReferenceSupported)
                        IconButton(
                          tooltip: 'Float reference',
                          onPressed: () =>
                              floatReference(context, ref, poiId: poi.id),
                          icon: const Icon(Icons.picture_in_picture_alt),
                        ),
                      IconButton(
                        tooltip: 'Add image',
                        onPressed: () =>
                            _addImageToMediaAssets(context, ref, poi.id),
                        icon: const Icon(Icons.add_photo_alternate),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Edits saving in the background land in the list below
              // once they finish.
              Builder(builder: (context) {
                final saving = ref
                    .watch(backgroundPhotoSavesProvider)
                    .where((save) => save.poiId == poi.id)
                    .length;
                if (saving == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(saving == 1
                          ? 'Saving 1 photo…'
                          : 'Saving $saving photos…'),
                    ],
                  ),
                );
              }),
              mediaAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, _) => Text('Error: $err'),
                data: (assets) {
                  if (assets.isEmpty) {
                    return const Text('No media assets yet.');
                  }
                  final referenceImagesById =
                      referenceImagesAsync.maybeWhen(
                    data: (refs) => {for (final r in refs) r.id: r},
                    orElse: () => <String, ReferenceImageModel>{},
                  );
                  return Column(
                    children: assets.map((asset) {
                      final linkedRef = asset.referenceImageId != null
                          ? referenceImagesById[asset.referenceImageId]
                          : null;
                      return _MediaAssetTile(
                        asset: asset,
                        onRename: () => _renameMediaAsset(context, ref, asset),
                        onDelete: () => _deleteMediaAsset(context, ref, asset),
                        onPreview: _isPreviewableImage(asset)
                            ? () => _showImagePreview(context, asset)
                            : null,
                        onEdit: _isPreviewableImage(asset)
                            ? () => _editMediaAsset(context, asset, linkedRef)
                            : null,
                        title: _mediaAssetTitle(asset),
                        icon: _iconForType(asset.type ?? 'unknown'),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

  void _handleAction(
      BuildContext context, WidgetRef ref, String action, PoiModel poi) {
    switch (action) {
      case 'edit':
        context.push('/pois/${poi.id}/edit');
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Location?'),
            content: Text('This will permanently delete "${poi.name}".'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await ref.read(poiRepositoryProvider).deletePoi(poi.id);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/pois');
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _showScheduleDialog(
      BuildContext context, WidgetRef ref, String poiId) {
    DateTime? selectedDate;
    final startController = TextEditingController(text: '10:00');
    final endController = TextEditingController(text: '12:00');
    String status = 'backlog';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Time Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'backlog', label: Text('Backlog')),
                  ButtonSegment(value: 'scheduled', label: Text('Schedule')),
                ],
                selected: {status},
                onSelectionChanged: (s) =>
                    setDialogState(() => status = s.first),
              ),
              const SizedBox(height: 16),
              if (status == 'scheduled') ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : 'Select Date'),
                  onTap: () async {
                    final picked = await showMonthCalendarPicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(DateTime.now().year + 20),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        decoration:
                            const InputDecoration(labelText: 'Start'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        decoration:
                            const InputDecoration(labelText: 'End'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  if (status == 'scheduled' && selectedDate == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please select a date first.')),
                    );
                    return;
                  }

                  int timeToMins(String? t) {
                    if (t == null || t == '--:--') return 0;
                    final parts = t.split(':');
                    if (parts.length != 2) return 0;
                    return (int.tryParse(parts[0]) ?? 0) * 60 +
                        (int.tryParse(parts[1]) ?? 0);
                  }

                  final startStr = status == 'scheduled' ? startController.text.trim() : null;
                  final endStr = status == 'scheduled' ? endController.text.trim() : null;
                  int duration = 60;
                  if (status == 'scheduled' && startStr != null && endStr != null) {
                    duration = timeToMins(endStr) - timeToMins(startStr);
                    if (duration < 0) duration += 24 * 60;
                    if (duration <= 0) duration = 60;
                  }

                  final targetDateStr = (status == 'scheduled' && selectedDate != null)
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : null;

                  final newChunk = TimeChunkModel(
                    id: const Uuid().v4(),
                    poiId: poiId,
                    authorId: ref.read(currentUserIdProvider),
                    date: targetDateStr,
                    startTime: startStr,
                    endTime: endStr,
                    duration: duration,
                    isFixedTime: status == 'scheduled',
                    status: status,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                    isShared: false,
                  );

                  await ref.read(timeChunkRepositoryProvider).addTimeChunk(newChunk);
                  if (targetDateStr != null) {
                    final dayChunks = await ref
                        .read(timeChunkRepositoryProvider)
                        .watchTimeChunksByDate(targetDateStr)
                        .first;
                    await ref.read(scheduleEngineProvider).recalculateDaySchedule(dayChunks);
                  }
                  
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Schedule added successfully!')),
                    );
                  }
                } catch (e) {
                  debugPrint('Schedule Add Error: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to add schedule: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      startController.dispose();
      endController.dispose();
    });
  }

  Widget _statusIcon(String status) {
    return switch (status) {
      'completed' => const Icon(Icons.check_circle, color: Colors.green),
      'scheduled' => const Icon(Icons.schedule, color: Colors.blue),
      'skipped' => const Icon(Icons.skip_next, color: Colors.orange),
      _ => const Icon(Icons.inbox, color: Colors.grey),
    };
  }

  Widget _iconForType(String type) {
    return switch (type) {
      'reference_frame' => const Icon(Icons.image),
      'user_photo' => const Icon(Icons.camera_alt),
      'uploaded_image' => const Icon(Icons.save_alt),
      'comparison_image' => const Icon(Icons.compare),
      'ticket_qr' => const Icon(Icons.qr_code),
      'audio_bgm' => const Icon(Icons.music_note),
      _ => const Icon(Icons.attachment),
    };
  }

  String _mediaAssetTitle(MediaAssetModel asset) {
    final title = asset.localPath != null 
    ? p.basenameWithoutExtension(asset.localPath!) 
    : (asset.metadata ?? 'Cloud Asset');
    return title.isEmpty ? (asset.type ?? 'unknown') : title;
  }

  Future<void> _renameMediaAsset(
    BuildContext context,
    WidgetRef ref,
    MediaAssetModel asset,
  ) async {
    // 1. Guard clause: Prevent physical file operations on cloud-only assets
    if (asset.localPath == null || asset.localPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot rename a cloud-only image. Please download it first.'),
        ),
      );
      return;
    }

    final currentLocalPath = asset.localPath!;
    final oldFile = File(currentLocalPath);
    final currentName = p.basenameWithoutExtension(currentLocalPath);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(
        title: 'Rename Image',
        initialName: currentName,
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;
    if (!context.mounted) return;

    final sanitizedName = p.basenameWithoutExtension(_sanitizeFileName(newName));
    if (sanitizedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid image name.')),
      );
      return;
    }

    if (!await oldFile.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image file not found: $currentLocalPath')),
      );
      return;
    }

    // Perform path operations safely
    final extension = p.extension(currentLocalPath).isEmpty
        ? '.jpg'
        : p.extension(currentLocalPath);
        
    final newPath = await _nextAvailableMediaPath(
      p.dirname(currentLocalPath),
      sanitizedName,
      extension,
      currentLocalPath,
    );

    try {
      await oldFile.rename(newPath);

      await ref.read(mediaRepositoryProvider).updateMediaAssetLocalPath(
            asset.id,
            newPath,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image renamed.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: $e')),
      );
    }
  }

  Future<void> _deleteMediaAsset(
    BuildContext context,
    WidgetRef ref,
    MediaAssetModel asset,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image?'),
        content: Text('This will remove "${_mediaAssetTitle(asset)}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final file = (asset.localPath != null && asset.localPath!.isNotEmpty) 
          ? File(asset.localPath!) 
          : null;
          
      // CRITICAL FIX: Add a null check before calling exists() and delete()
      if (file != null && await file.exists()) {
        await file.delete();
      }

      // Proceed to delete the record from the database regardless of whether
      // a local physical file existed or not.
      await ref.read(mediaRepositoryProvider).deleteMediaAsset(asset.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  Future<String> _nextAvailableMediaPath(
    String directory,
    String baseName,
    String extension,
    String currentPath,
  ) async {
    var candidate = p.join(directory, '$baseName$extension');
    var suffix = 1;

    while (candidate != currentPath && await File(candidate).exists()) {
      candidate = p.join(directory, '$baseName-$suffix$extension');
      suffix += 1;
    }

    return candidate;
  }

  bool _isPreviewableImage(MediaAssetModel asset) {
    // 1. Check known asset types first (this is the safest fallback)
    final isKnownImageType = asset.type == 'user_photo' ||
        asset.type == 'uploaded_image' ||
        asset.type == 'comparison_image' ||
        asset.type == 'reference_frame' ||
        asset.type == 'ticket_qr';

    // 2. Helper function to check extensions safely
    bool hasImageExtension(String? path) {
      if (path == null || path.isEmpty) return false;
      final uri = path.toLowerCase();
      return uri.endsWith('.jpg') ||
          uri.endsWith('.jpeg') ||
          uri.endsWith('.png') ||
          uri.endsWith('.webp') ||
          uri.endsWith('.gif') ||
          uri.endsWith('.heic');
    }

    // 3. It's previewable if the type matches OR if either the local or remote path has an image extension
    return isKnownImageType || 
           hasImageExtension(asset.localPath) || 
           hasImageExtension(asset.remoteUrl);
  }

  void _showImagePreview(BuildContext context, MediaAssetModel asset) {
    // INFERENCE FIX: Added remoteUrl to ensure cloud-only assets can be previewed
    _showFullscreenImage(
      context, 
      localPath: asset.localPath, 
      remoteUrl: asset.remoteUrl,
      title: asset.type ?? 'unknown'
    );
  }

  void _showFullscreenImage(
    BuildContext context, {
    String? localPath,
    String? remoteUrl,
    required String title,
  }) {
    // 1. Determine which image widget to build based on availability
    Widget imageWidget;

    if (localPath != null && localPath.isNotEmpty) {
      // Scenario A: Local file exists
      imageWidget = Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Local image file corrupted or missing:\n$localPath',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      // Scenario B: Cloud-only file
      imageWidget = Image.network(
        remoteUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Failed to load cloud image.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    } else {
      // Scenario C: Total failure / No data
      imageWidget = const Center(
        child: Icon(Icons.cloud_off, size: 64, color: Colors.white54),
      );
    }

    // 2. Render the fullscreen dialog using your existing UI structure
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.75,
              maxScale: 4.0,
              child: Center(child: imageWidget), // Inject the dynamically chosen widget
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  title: Text(title),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _referenceImageTitle(ReferenceImageModel image) {
    final title = image.localPath != null 
    ? p.basenameWithoutExtension(image.localPath!) 
    : (image.metadata ?? 'Cloud Asset');
    return title.isEmpty ? 'Reference' : title;
  }

  /// Pick an image from the gallery and drop the user into the photo
  /// editor against it. The file is copied into the app's temp
  /// directory first so the editor can freely overwrite it with the
  /// edited bytes without touching the gallery item or the picker's
  /// cache; once the editor saves, that temp copy gets archived into
  /// permanent app storage with `type = uploaded_image`.
  Future<void> _addImageToMediaAssets(
    BuildContext context,
    WidgetRef ref,
    String poiId,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!context.mounted) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final tempPath = p.join(
        tempDir.path,
        'upload_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(picked.path).copy(tempPath);

      if (!context.mounted) return;
      context.push(
        '/pois/$poiId/photo-edit'
        '?path=${Uri.encodeComponent(tempPath)}'
        '&upload=1',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load image: $e')),
      );
    }
  }

  /// Open the photo editor on an existing media asset. Copies it to a temp file
  /// first so editing is non-destructive — saving creates a NEW asset and the
  /// original is preserved. Passes the paired reference (if any) so Match Color
  /// / Compose are available.
  Future<void> _editMediaAsset(
    BuildContext context,
    MediaAssetModel asset,
    ReferenceImageModel? linkedRef,
  ) async {
    // 1. CRITICAL GUARD: Stop immediately if the asset has no local file.
    if (asset.localPath == null || asset.localPath!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot edit cloud-only asset. Please download it first.')),
        );
      }
      return; 
    }

    // 2. SAFE EXTRACTION: Guaranteed to be non-null for all subsequent path operations
    final currentPath = asset.localPath!;
    final src = File(currentPath);

    final ext = p.extension(currentPath).isEmpty
        ? '.jpg'
        : p.extension(currentPath);
        
    if (!await src.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found.')),
        );
      }
      return;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      
      // FIXED: Removed redundant local declaration of 'ext' and updated to use 'currentPath'
      final tempPath = p.join(
        tempDir.path,
        'edit_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      
      await src.copy(tempPath);
      if (!context.mounted) return;
      
      final qs = <String, String>{'path': Uri.encodeComponent(tempPath)};
      
      if (linkedRef != null) {
        // Fallback to remoteUrl if localPath is missing for the linked reference
        final pathOrUrl = linkedRef.localPath ?? linkedRef.remoteUrl ?? '';
        qs['ref'] = Uri.encodeComponent(pathOrUrl);
        qs['refId'] = asset.referenceImageId!;
      }
      
      final query = qs.entries.map((e) => '${e.key}=${e.value}').join('&');
      context.push('/pois/${asset.poiId}/photo-edit?$query');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Edit failed: $e')),
      );
    }
  }

  Future<void> _addReferenceImage(
    BuildContext context,
    WidgetRef ref,
    String poiId,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!context.mounted) return;

    try {
      final newPath = await _copyReferenceImageToStorage(File(picked.path));
      final newImage = ReferenceImageModel(
        id: const Uuid().v4(),
        authorId: ref.read(currentUserIdProvider),
        poiId: poiId,
        localPath: newPath,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isShared: false,
      );

      await ref.read(mediaRepositoryProvider).addReferenceImage(newImage);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reference image added.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add reference image: $e')),
      );
    }
  }

  Future<void> _renameReferenceImage(
    BuildContext context,
    WidgetRef ref,
    ReferenceImageModel image,
  ) async {
    // 1. CRITICAL FIX: Guard clause. Abort immediately if it's a cloud-only image.
    // You cannot physically rename a file that doesn't exist on the device.
    if (image.localPath == null || image.localPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot rename a cloud-only image. Please download it first.')),
      );
      return;
    }

    // 2. Safe extraction: We are now 100% sure the path is not null.
    final currentPath = image.localPath!;
    
    // Replace all subsequent uses of 'image.localPath' with 'currentPath'
    final oldFile = File(currentPath);
    final currentName = p.basenameWithoutExtension(currentPath);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(
        title: 'Rename Reference Image',
        initialName: currentName,
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;
    if (!context.mounted) return;

    final sanitizedName = p.basenameWithoutExtension(_sanitizeFileName(newName));
    if (sanitizedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid image name.')),
      );
      return;
    }

    if (!await oldFile.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image file not found: $currentPath')),
      );
      return;
    }

    final extension = p.extension(currentPath).isEmpty
        ? '.jpg'
        : p.extension(currentPath);
        
    final newPath = await _nextAvailableMediaPath(
      p.dirname(currentPath),
      sanitizedName,
      extension,
      currentPath,
    );

    try {
      await oldFile.rename(newPath);

      // This will now correctly pass the newPath as String to the repository
      await ref.read(mediaRepositoryProvider).updateReferenceImageLocalPath(
            image.id,
            newPath,
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image renamed.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: $e')),
      );
    }
  }

  Future<void> _deleteReferenceImage(
    BuildContext context,
    WidgetRef ref,
    ReferenceImageModel image,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reference Image?'),
        content: Text('This will remove "${_referenceImageTitle(image)}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    if (!context.mounted) return;

    try {
      final file = (image.localPath != null && image.localPath!.isNotEmpty)
          ? File(image.localPath!)
          : null;
          
      if (file != null && await file.exists()) {
        await file.delete();
      }

      await ref.read(mediaRepositoryProvider).deleteReferenceImage(image.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reference image deleted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<String> _copyReferenceImageToStorage(File source) async {
    final appDir = await getApplicationDocumentsDirectory();
    final refDir = Directory(p.join(appDir.path, 'reference_images'));
    if (!await refDir.exists()) {
      await refDir.create(recursive: true);
    }

    final extension =
        p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final newPath = p.join(refDir.path, '${const Uuid().v4()}$extension');
    await source.copy(newPath);
    return newPath;
  }
}

class _MediaAssetTile extends StatelessWidget {
  final MediaAssetModel asset;
  final String title;
  final Widget icon;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onPreview;
  final VoidCallback? onEdit;

  const _MediaAssetTile({
    required this.asset,
    required this.title,
    required this.icon,
    required this.onRename,
    required this.onDelete,
    required this.onPreview,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        asset.localPath ?? asset.remoteUrl ?? 'Cloud Asset',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: EdgeInsets.zero,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Save to device',
            icon: const Icon(Icons.download),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                // CRITICAL FIX: Prevent Gallery package from crashing on cloud assets
    if (asset.localPath == null || asset.localPath!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save cloud image to gallery. Download it first.')),
        );
      }
      return;
    }
    
    // Use the bang operator since we've guaranteed it's not null
    await Gal.putImage(asset.localPath!);
                final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
                messenger.showSnackBar(
                  SnackBar(content: Text(isDesktop ? 'Saved to Pictures folder.' : 'Saved to gallery.')),
                );
              } on GalException catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Save failed: ${e.type.message}')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Save failed: $e')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'rename') onRename();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.open_in_full),
            onPressed: onPreview,
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String title;
  final String initialName;

  const _RenameDialog({required this.title, required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Image name'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _ReferenceImageTile extends StatelessWidget {
  final ReferenceImageModel image;
  final String title;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  const _ReferenceImageTile({
    required this.image,
    required this.title,
    required this.onRename,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Dual-track image rendering strategy (Local -> Remote -> Placeholder)
    Widget imageWidget;
    if (image.localPath != null && image.localPath!.isNotEmpty) {
      imageWidget = Image.file(
        File(image.localPath!), // Safe to use ! here
        cacheHeight: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image),
        ),
      );
    } else if (image.remoteUrl != null && image.remoteUrl!.isNotEmpty) {
      imageWidget = Image.network(
        image.remoteUrl!, // Safe to use ! here
        cacheHeight: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image),
        ),
      );
    } else {
      imageWidget = const ColoredBox(
        color: Colors.black12,
        child: Icon(Icons.cloud_off, color: Colors.grey),
      );
    }

    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 48,
            height: 48,
            child: imageWidget, // Inject the dynamically resolved widget
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        
        // 2. Safe subtitle rendering using the null-coalescing operator (??)
        // If localPath is null, try remoteUrl. If both are null, show default text.
        subtitle: Text(
          image.localPath ?? image.remoteUrl ?? 'Cloud Image (Not Downloaded)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // Optional: Dim the text if it's not a local file
            color: image.localPath == null ? Colors.grey : null,
          ),
        ),
        
        onTap: onPreview,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onRename,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
            IconButton(
              tooltip: 'Preview',
              icon: const Icon(Icons.open_in_full),
              onPressed: onPreview,
            ),
          ],
        ),
      ),
    );
  }
}