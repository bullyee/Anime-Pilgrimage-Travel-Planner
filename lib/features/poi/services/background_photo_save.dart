import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/media_repository.dart';
import 'media_asset_service.dart';

/// Messenger for snackbars that outlive the page that started them — a save
/// finishing after its editor has closed. Wired into `MaterialApp.router`.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Album that photos saved to the phone's gallery land in.
const galleryAlbum = 'Trip Planner';

/// A save still in flight, so the POI page can show "Saving…". [poiId] is
/// null for a save that only goes to the phone's gallery.
class PendingPhotoSave {
  final String id;
  final String? poiId;

  const PendingPhotoSave(this.id, this.poiId);
}

/// Saves edited photos in the background. The editor and Compose hand their
/// full-resolution render here and close straight away, instead of keeping
/// the user on a spinner for the seconds a 12 MP render takes.
///
/// Each save renders into its own temp file and never writes over the photo
/// it was edited from, and a photo only joins the POI's media once its save
/// has finished. So re-opening the editor while a save runs — on another
/// photo, or the same one again — can't clash with it: every editor works
/// on its own copy, and every save adds its own media asset.
///
/// The state lists the saves still in flight.
class BackgroundPhotoSaves extends Notifier<List<PendingPhotoSave>> {
  // Saves render one at a time: each holds a full-size image in memory, and
  // several side by side could get the app killed on a low-memory phone.
  // Persisting is queued on its own, because persistMediaAsset names files
  // by the second and picks a free name, which two saves finishing together
  // could otherwise both claim.
  Future<void> _renderQueue = Future.value();
  Future<void> _persistQueue = Future.value();

  @override
  List<PendingPhotoSave> build() => const [];

  /// Saves the bytes [render] produces — or [original] as-is when it returns
  /// null — to [poiId]'s media as [type], and with [toGallery] to the
  /// phone's gallery ([galleryAlbum]) as well. With [originalToGallery] (a
  /// fresh camera capture, which isn't in the gallery yet) the untouched
  /// [original] goes to the gallery next to the edit. Returns at once; the
  /// outcome shows up as a snackbar and, on success, as the new photo on the
  /// POI page.
  ///
  /// [render] runs when it's this save's turn — after the saves queued
  /// before it — so it must not need the caller's page, which is gone by
  /// then.
  void save({
    String? poiId,
    bool toGallery = false,
    bool originalToGallery = false,
    required String type,
    required Future<Uint8List?> Function() render,
    File? original,
    String? referenceImageId,
  }) {
    final job = PendingPhotoSave(const Uuid().v4(), poiId);
    state = [...state, job];
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final targetName = isDesktop ? 'Pictures folder' : 'gallery';
    final message = !toGallery
        ? 'Photo saved.'
        : poiId == null
        ? 'Saved to the $targetName.'
        : 'Saved to the POI and the $targetName.';
    unawaited(
      _run(
        job,
        toGallery,
        originalToGallery,
        type,
        render,
        original,
        referenceImageId,
        message,
      ),
    );
  }

  Future<void> _run(
    PendingPhotoSave job,
    bool toGallery,
    bool originalToGallery,
    String type,
    Future<Uint8List?> Function() render,
    File? original,
    String? referenceImageId,
    String savedMessage,
  ) async {
    File? temp;
    var ok = false;
    Object? error;
    // Timed from when this save's turn comes, for the log line below.
    final watch = Stopwatch();
    var galleryMs = 0;
    try {
      final rendered = _renderQueue.then((_) {
        watch.start();
        return render();
      });
      _renderQueue = rendered.then((_) {}, onError: (_) {});
      final bytes = await rendered;
      final File source;
      if (bytes == null) {
        if (original == null) throw StateError('nothing to save');
        source = original;
      } else {
        temp = File(
          p.join((await getTemporaryDirectory()).path, 'edited_${job.id}.jpg'),
        );
        await temp.writeAsBytes(bytes, flush: true);
        source = temp;
      }
      if (toGallery) {
        final galleryStart = watch.elapsedMilliseconds;
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          if (!await Gal.requestAccess(toAlbum: true)) {
            throw StateError('no access to the gallery');
          }
        }
        await Gal.putImage(source.path, album: galleryAlbum);
        if (originalToGallery && bytes != null && original != null) {
          await Gal.putImage(original.path, album: galleryAlbum);
        }
        galleryMs = watch.elapsedMilliseconds - galleryStart;
      }
      final poiId = job.poiId;
      if (poiId == null) {
        ok = true;
      } else {
        final persisted = _persistQueue.then(
          (_) => persistMediaAsset(
            mediaRepo: ref.read(mediaRepositoryProvider),
            source: source,
            poiId: poiId,
            type: type,
            referenceImageId: referenceImageId,
            authorId: ref.read(currentUserIdProvider),
          ),
        );
        _persistQueue = persisted.then((_) {}, onError: (_) {});
        ok = await persisted;
      }
    } catch (e) {
      error = e;
    } finally {
      if (temp != null) {
        try {
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
      }
      state = [
        for (final pending in state)
          if (pending.id != job.id) pending,
      ];
    }
    debugPrint(
      'Photo save ${ok ? 'done' : 'failed'} in ${watch.elapsedMilliseconds} '
      'ms, $galleryMs ms of it saving to the gallery',
    );
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? savedMessage
              : error == null
              ? 'Save failed.'
              : 'Save failed: $error',
        ),
      ),
    );
  }
}

final backgroundPhotoSavesProvider =
    NotifierProvider<BackgroundPhotoSaves, List<PendingPhotoSave>>(
      BackgroundPhotoSaves.new,
    );
