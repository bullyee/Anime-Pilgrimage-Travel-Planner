import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/capture_sheets.dart';
import 'camera_overlay.dart';

/// Whether this platform has an Anime Camera at all. Desktop and web don't,
/// so their camera entry points are hidden.
bool get animeCameraSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Whether [floatReference] works here (Android only).
bool get floatingReferenceSupported => CameraOverlay.isSupported;

/// Opens the Anime Camera, for [poiId] when the user came from a POI page.
///
/// - **Android:** the phone's own camera app (full HDR / night / white
///   balance processing) with the reference floating over it in a small
///   draggable window. See `docs/anime-camera-decision.md`.
/// - **iOS:** the in-app camera (`/camera`), which overlays the reference
///   inside the app, since iOS can't draw over another app.
Future<void> openAnimeCamera(
  BuildContext context,
  WidgetRef ref, {
  String? poiId,
}) async {
  if (!animeCameraSupported) return;
  if (Platform.isAndroid) {
    await _shootWithPhoneCamera(context, ref, poiId: poiId);
  } else {
    context.push(poiId == null ? '/camera' : '/camera?poiId=$poiId');
  }
}

/// Floats a reference over whatever is on screen without opening a camera.
/// Unlike [openAnimeCamera], the window stays up after the user leaves Trip
/// Planner, so they can shoot as many photos as they like with any camera
/// app and add the keeper on the POI page later (Add image). It stays until
/// closed with ✕ or a double-tap. Android only.
Future<void> floatReference(
  BuildContext context,
  WidgetRef ref, {
  String? poiId,
}) async {
  if (!floatingReferenceSupported) return;
  final source = await _askReferenceSource(
    context,
    hasPoi: poiId != null,
    mode: _SheetMode.floatOnly,
  );
  if (source == null || !context.mounted) return;
  final reference = await _pickReference(context, ref, source, poiId: poiId);
  if (reference == null || !context.mounted) return;
  await floatReferenceImage(context, reference.path);
}

/// Floats the image at [path] over other apps, the way [floatReference]
/// does once a reference is picked: a place page's "Float frame".
Future<void> floatReferenceImage(BuildContext context, String path) async {
  if (!floatingReferenceSupported) return;
  if (!await CameraOverlay.canDrawOverlays()) {
    if (!context.mounted) return;
    final openSettings = await _askOverlayPermission(context, floatOnly: true);
    if (openSettings == true) await CameraOverlay.requestPermission();
    return;
  }
  final shown = await CameraOverlay.show(path, followCamera: false);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        shown
            ? 'The reference now floats over other apps. Switch to your '
                  'camera and shoot; close it with ✕ or a double-tap.'
            : 'Could not show the reference.',
      ),
    ),
  );
}

/// Edits a photo that's already on the phone — e.g. the keeper from a batch
/// shot under the Floating Reference — as in anime_camera_studio: pick the
/// photo and go straight to the editor, where the user adds a reference if
/// they want one. The result is saved to the phone's gallery, and also to a
/// POI's media when the reference was picked from that POI.
Future<void> editPhotoFromGallery(BuildContext context, WidgetRef ref) async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not pick image: ${e.message ?? e.code}')),
    );
    return;
  }
  if (picked == null || !context.mounted) return;
  // The editor never writes over the file it's given, so it can work on the
  // picker's file directly.
  context.push('/photo-edit?path=${Uri.encodeComponent(picked.path)}&upload=1');
}

/// Android may kill the app while the phone's camera is open; image_picker
/// then hands the photo back on the next launch. Send it on to the editor —
/// the reference and POI it was taken for are gone by then, so it starts
/// with no POI. Call once when the home screen first shows.
Future<void> recoverLostCapture(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return;
  final LostDataResponse response;
  try {
    response = await ImagePicker().retrieveLostData();
  } catch (_) {
    return;
  }
  final file = response.file;
  if (response.isEmpty || file == null || !context.mounted) return;
  openCaptureInEditor(context, photoPath: file.path);
}

enum _ReferenceSource { poi, gallery, none }

/// Which flow the reference sheet is asking for.
enum _SheetMode { camera, floatOnly }

/// A picked reference image. [imageId] / [poiId] are set when it's one of a
/// POI's reference images.
class _Reference {
  final String path;
  final String? imageId;
  final String? poiId;

  const _Reference(this.path, {this.imageId, this.poiId});
}

Future<void> _shootWithPhoneCamera(
  BuildContext context,
  WidgetRef ref, {
  String? poiId,
}) async {
  final source = await _askReferenceSource(context, hasPoi: poiId != null);
  if (source == null || !context.mounted) return;
  _Reference? reference;
  if (source != _ReferenceSource.none) {
    reference = await _pickReference(context, ref, source, poiId: poiId);
    if (reference == null || !context.mounted) return;
  }
  await _shootWith(context, reference, poiId: poiId);
}

/// Opens the Anime Camera for a place with its frame already chosen: a place
/// page's "Take photo". The shot goes to the editor with the frame loaded,
/// and is saved to [placeKey]'s photos. Without a frame it just shoots.
Future<void> shootWithReference(
  BuildContext context,
  WidgetRef ref, {
  required String placeKey,
  String? referencePath,
  String? referenceImageId,
}) async {
  if (!animeCameraSupported) return;
  if (!Platform.isAndroid) {
    context.push('/camera?poiId=${Uri.encodeComponent(placeKey)}');
    return;
  }
  final reference = referencePath == null ? null : _Reference(referencePath, imageId: referenceImageId, poiId: placeKey);
  await _shootWith(context, reference, poiId: placeKey);
}

Future<void> _shootWith(BuildContext context, _Reference? reference, {String? poiId}) async {
  // Float the reference over the camera when allowed. Without the
  // permission the user can still shoot; the reference then only shows up
  // in the editor.
  var overlayShown = false;
  if (reference != null) {
    if (await CameraOverlay.canDrawOverlays()) {
      overlayShown = await CameraOverlay.show(reference.path);
    } else {
      if (!context.mounted) return;
      final openSettings = await _askOverlayPermission(context);
      if (openSettings == null) return;
      if (openSettings) {
        await CameraOverlay.requestPermission();
        return;
      }
    }
  }

  XFile? shot;
  try {
    shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Camera unavailable: ${e.message ?? e.code}')),
    );
    return;
  } finally {
    if (overlayShown) await CameraOverlay.hide();
  }
  if (shot == null || !context.mounted) return;

  openCaptureInEditor(
    context,
    photoPath: shot.path,
    poiId: poiId ?? reference?.poiId,
    referencePath: reference?.path,
    referenceImageId: reference?.imageId,
  );
}

/// Resolves a [_ReferenceSource.poi] or [_ReferenceSource.gallery] pick to an
/// image; null when the user backs out.
Future<_Reference?> _pickReference(
  BuildContext context,
  WidgetRef ref,
  _ReferenceSource source, {
  String? poiId,
}) async {
  switch (source) {
    case _ReferenceSource.poi:
      final id = poiId ?? await pickPoiId(context, ref);
      if (id == null || !context.mounted) return null;
      final image = await pickPoiReferenceImage(context, ref, id);
      if (image == null) return null;
      return _Reference(image.localPath!, imageId: image.id, poiId: id);
    case _ReferenceSource.gallery:
      final XFile? picked;
      try {
        picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      } on PlatformException catch (e) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: ${e.message ?? e.code}'),
          ),
        );
        return null;
      }
      if (picked == null) return null;
      return _Reference(picked.path);
    case _ReferenceSource.none:
      return null;
  }
}

Future<_ReferenceSource?> _askReferenceSource(
  BuildContext context, {
  required bool hasPoi,
  _SheetMode mode = _SheetMode.camera,
}) {
  final intro = switch (mode) {
    _SheetMode.camera =>
      'The reference floats over your camera in a small window you can drag '
          'and pinch. Tap it for opacity.',
    _SheetMode.floatOnly =>
      'The reference floats over every app until you close it (✕ or '
          'double-tap), so you can shoot as many photos as you like with your '
          'own camera app.',
  };
  return showModalBottomSheet<_ReferenceSource>(
    context: context,
    backgroundColor: Colors.grey[900],
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(intro, style: const TextStyle(color: Colors.white54)),
          ),
          ListTile(
            leading: const Icon(Icons.collections, color: Colors.white),
            title: Text(
              hasPoi
                  ? "This POI's reference images"
                  : "A POI's reference images",
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(ctx, _ReferenceSource.poi),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: const Text(
              'Pick a reference from the gallery',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(ctx, _ReferenceSource.gallery),
          ),
          if (mode != _SheetMode.floatOnly)
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text(
                'No reference',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Just open the camera; you can add one in the editor.',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () => Navigator.pop(ctx, _ReferenceSource.none),
            ),
        ],
      ),
    ),
  );
}

/// True opens the settings screen; false shoots without the floating
/// reference (camera flow only); null means the dialog was dismissed.
Future<bool?> _askOverlayPermission(
  BuildContext context, {
  bool floatOnly = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        floatOnly
            ? 'Float the reference over other apps?'
            : 'Float the reference over the camera?',
      ),
      content: Text(
        floatOnly
            ? 'Allow "Display over other apps" for Trip Planner, then try '
                  'again.'
            : 'Allow "Display over other apps" for Trip Planner, then open '
                  'the camera again.\n\nWithout it you can still shoot — the '
                  'reference opens in the editor.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, floatOnly ? null : false),
          child: Text(floatOnly ? 'Cancel' : 'Shoot without it'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
}
