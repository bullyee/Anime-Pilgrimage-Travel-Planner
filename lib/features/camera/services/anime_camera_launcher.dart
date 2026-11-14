import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/database.dart' show NewReferenceImage;
import '../../library/widgets/place_page_parts.dart' show framePath, framePathOnDevice;
import '../models/shot_series.dart';
import '../screens/shot_series_screen.dart';
import '../widgets/capture_sheets.dart';
import '../widgets/shoot_here_sheet.dart';
import 'camera_overlay.dart';
import 'photo_edit_route.dart';
import 'web_camera_probe.dart';

@visibleForTesting
bool? debugAnimeCameraSupportedOverride;

/// Whether this platform has an Anime Camera at all. Mobile apps use either
/// Android's overlay or the in-app camera; Web enables the in-app WebRTC
/// camera when the browser exposes `navigator.mediaDevices`.
bool get animeCameraSupported =>
    debugAnimeCameraSupportedOverride ??
    (kIsWeb ? webCameraAvailable : (Platform.isAndroid || Platform.isIOS));

/// Whether [floatReference] works here (Android only).
bool get floatingReferenceSupported => CameraOverlay.isSupported;

/// Opens the Anime Camera, for [placeKey] when the user came from a place.
/// The photo is filed under [tripId] when given, or else under the trip that
/// has the place today.
///
/// Without a place it starts with Shoot here ([pickShootHere]): the frames
/// of the places around the user, found with GPS, and the ways to shoot
/// without a place.
///
/// - **Android:** the phone's own camera app (full HDR / night / white
///   balance processing) with the reference floating over it in a small
///   draggable window. See `docs/anime-camera-decision.md`.
/// - **iOS:** the in-app camera (`/camera`), which overlays the reference
///   inside the app, since iOS can't draw over another app.
Future<void> openAnimeCamera(
  BuildContext context,
  WidgetRef ref, {
  String? placeKey,
  String? tripId,
}) async {
  if (!animeCameraSupported) return;
  if (placeKey == null) {
    await _shootHere(context, ref, tripId: tripId);
    return;
  }
  if (!kIsWeb && Platform.isAndroid) {
    await _shootWithPhoneCamera(context, ref, placeKey: placeKey, tripId: tripId);
  } else {
    context.push(_inAppCameraLocation(placeKey, tripId));
  }
}

String _inAppCameraLocation(String? placeKey, String? tripId, {String? frameId}) =>
    Uri(path: '/camera', queryParameters: {
      if (placeKey != null) 'place': placeKey,
      if (tripId != null) 'trip': tripId,
      if (frameId != null) 'frame': frameId,
    }).toString();

/// Floats a reference over whatever is on screen without opening a camera.
/// Unlike [openAnimeCamera], the window stays up after the user leaves Trip
/// Planner, so they can shoot as many photos as they like with any camera
/// app and add the keeper on the place page later (Add photos). It stays
/// until closed with its bar's ✕ (a double-tap shrinks it to a dot).
/// Android only.
Future<void> floatReference(
  BuildContext context,
  WidgetRef ref, {
  String? placeKey,
}) async {
  if (!floatingReferenceSupported) return;
  final source = await _askReferenceSource(
    context,
    hasPlace: placeKey != null,
    mode: _SheetMode.floatOnly,
  );
  if (source == null || !context.mounted) return;
  final reference = await _pickReference(context, ref, source, placeKey: placeKey);
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
                  'camera and shoot. Double-tap it to shrink it to a dot; tap '
                  'it for ✕ to close it.'
            : 'Could not show the reference.',
      ),
    ),
  );
}

/// Edits a photo that's already on the phone — e.g. the keeper from a batch
/// shot under the Floating Reference — as in anime_camera_studio: pick the
/// photo and go straight to the editor, where the user adds a reference if
/// they want one. The result is saved to the phone's gallery, and also to a
/// place's photos when the reference was picked from that place.
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
  context.push(PhotoEditArgs(path: picked.path, upload: true).location);
}

/// Android may kill the app while the phone's camera is open; image_picker
/// then hands the photo back on the next launch. When a shot series was
/// running, the photo joins it and the shots screen opens again, with the
/// series' place and frame. Otherwise it goes on to the editor with no
/// place. Call once when the home screen first shows.
Future<void> recoverLostCapture(BuildContext context, {ShotSeriesStore? store}) async {
  if (kIsWeb || !Platform.isAndroid) return;
  LostDataResponse? response;
  try {
    response = await ImagePicker().retrieveLostData();
  } catch (_) {
    response = null;
  }
  final file = response == null || response.isEmpty ? null : response.file;

  final series = store ?? ShotSeriesStore();
  var pending = await series.latest();
  if (pending != null) {
    if (file != null) pending = await series.addShot(pending, file.path);
    if (pending.shots.isEmpty) {
      await series.discard(pending.id);
    } else {
      if (context.mounted) context.push(ShotSeriesArgs(seriesId: pending.id).location);
      return;
    }
  }
  if (file == null || !context.mounted) return;
  openCaptureInEditor(context, photoPath: file.path);
}

enum _ReferenceSource { place, gallery, none }

/// Which flow the reference sheet is asking for.
enum _SheetMode { camera, floatOnly }

/// The picked reference: one image, or a place's frames to switch between,
/// starting on [index]. [placeKey] is set when they're a place's frames.
class _Reference {
  final List<SeriesFrame> frames;
  final int index;
  final String? placeKey;

  const _Reference(this.frames, {this.index = 0, this.placeKey});

  _Reference.single(String path, {String? imageId, this.placeKey})
      : frames = [SeriesFrame(path, imageId: imageId)],
        index = 0;

  String get path => frames[index].path;
}

/// Shoot here, then the camera for what the user picked.
Future<void> _shootHere(BuildContext context, WidgetRef ref, {String? tripId}) async {
  final android = !kIsWeb && Platform.isAndroid;
  final choice = await pickShootHere(context, plainCameraOnly: !android);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case ShootAtPlace(:final placeKey, :final frame, :final frames):
      // All the place's frames, to switch to in the camera, starting on the picked one.
      final all = frame == null || frames.any((f) => f.id == frame.id) ? frames : [frame, ...frames];
      await shootWithFrames(
        context,
        ref,
        placeKey: placeKey,
        tripId: tripId ?? choice.tripId,
        frames: frame == null ? const [] : all,
        index: frame == null ? 0 : all.indexWhere((f) => f.id == frame.id),
      );
    case ShootWithoutPlace(:final kind):
      if (!android) {
        context.push(_inAppCameraLocation(null, tripId));
        return;
      }
      final source = switch (kind) {
        ShootHereOther.anotherPlace => _ReferenceSource.place,
        ShootHereOther.gallery => _ReferenceSource.gallery,
        ShootHereOther.noReference => _ReferenceSource.none,
      };
      _Reference? reference;
      if (source != _ReferenceSource.none) {
        reference = await _pickReference(context, ref, source);
        if (reference == null || !context.mounted) return;
      }
      await _shootWith(context, reference, placeKey: reference?.placeKey, tripId: tripId);
  }
}

Future<void> _shootWithPhoneCamera(
  BuildContext context,
  WidgetRef ref, {
  String? placeKey,
  String? tripId,
}) async {
  final source = await _askReferenceSource(context, hasPlace: placeKey != null);
  if (source == null || !context.mounted) return;
  _Reference? reference;
  if (source != _ReferenceSource.none) {
    reference = await _pickReference(context, ref, source, placeKey: placeKey);
    if (reference == null || !context.mounted) return;
  }
  await _shootWith(context, reference, placeKey: placeKey, tripId: tripId);
}

/// Opens the Anime Camera for a place with its frames, starting on [index]:
/// Take photo on a place page, a stop page, Home's next stop and the day
/// map's card, and a place picked in Shoot here. With several frames, the
/// floating window switches between them without leaving the camera. The
/// shots the user keeps are saved to [placeKey]'s photos, each with the frame
/// it was taken with, filed under [tripId] when given. Without frames it
/// just shoots.
///
/// The starting frame is fetched if it only has a link; the others go along
/// only when they're on the phone already, so opening the camera never waits
/// on a download per frame.
Future<void> shootWithFrames(
  BuildContext context,
  WidgetRef ref, {
  required String placeKey,
  String? tripId,
  List<NewReferenceImage> frames = const [],
  int index = 0,
}) async {
  if (!animeCameraSupported) return;
  _Reference? reference;
  if (frames.isNotEmpty) {
    final resolved = await seriesFrames(
      frames,
      index,
      start: (frame) => framePath(ref, frame),
      other: (frame) => framePathOnDevice(ref, frame),
    );
    if (!context.mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This frame isn't on this phone yet. Try again when you're online.")),
      );
      return;
    }
    reference = _Reference(resolved.frames, index: resolved.index, placeKey: placeKey);
  }
  if (kIsWeb || !Platform.isAndroid) {
    // The in-app camera starts on the frame and offers the place's others.
    final start = reference?.frames[reference.index].imageId;
    context.push(_inAppCameraLocation(placeKey, tripId, frameId: start));
    return;
  }
  await _shootWith(context, reference, placeKey: placeKey, tripId: tripId);
}

/// The frames a series switches between, from a place's or stop's [frames]
/// in their order, and where it starts: [index]'s frame through [start]
/// (which may download it), the others through [other] (on the device
/// only). A frame with no file is left out. Null when the starting frame has
/// no file.
@visibleForTesting
Future<({List<SeriesFrame> frames, int index})?> seriesFrames(
  List<NewReferenceImage> frames,
  int index, {
  required Future<String?> Function(NewReferenceImage frame) start,
  required Future<String?> Function(NewReferenceImage frame) other,
}) async {
  if (frames.isEmpty) return null;
  final first = index.clamp(0, frames.length - 1);
  final out = <SeriesFrame>[];
  var at = -1;
  for (var i = 0; i < frames.length; i++) {
    final frame = frames[i];
    final path = i == first ? await start(frame) : await other(frame);
    if (path == null) {
      if (i == first) return null;
      continue;
    }
    if (i == first) at = out.length;
    out.add(SeriesFrame(path, imageId: frame.id));
  }
  return (frames: out, index: at);
}

/// Shoots a series against [reference] on the shots screen: the camera
/// reopens after every shot with the reference still floating, and the user
/// then keeps the shots they want, saved as shot (see [ShotSeriesScreen]).
Future<void> _shootWith(
  BuildContext context,
  _Reference? reference, {
  String? placeKey,
  String? tripId,
}) async {
  // The shots screen floats the reference over the camera when allowed.
  // Without the permission the user can still shoot; the reference then
  // only shows next to the shots.
  if (reference != null && !await CameraOverlay.canDrawOverlays()) {
    if (!context.mounted) return;
    final openSettings = await _askOverlayPermission(context);
    if (openSettings == null) return;
    if (openSettings) {
      await CameraOverlay.requestPermission();
      return;
    }
  }
  if (!context.mounted) return;
  await context.push(ShotSeriesArgs(
    placeKey: placeKey ?? reference?.placeKey,
    tripId: tripId,
    frames: reference?.frames ?? const [],
    frameIndex: reference?.index ?? 0,
  ).location);
}

/// Resolves a [_ReferenceSource.place] or [_ReferenceSource.gallery] pick to
/// an image; null when the user backs out.
Future<_Reference?> _pickReference(
  BuildContext context,
  WidgetRef ref,
  _ReferenceSource source, {
  String? placeKey,
}) async {
  switch (source) {
    case _ReferenceSource.place:
      final key = placeKey ?? await pickPlaceKey(context, ref);
      if (key == null || !context.mounted) return null;
      final frame = await pickPlaceFrame(context, ref, key);
      if (frame == null) return null;
      // The place's other frames come along, to switch to in the camera.
      final frames = [
        for (final f in await placeFramesOnDevice(ref, key)) SeriesFrame(f.localPath!, imageId: f.id),
      ];
      final index = frames.indexWhere((f) => f.imageId == frame.id);
      if (index < 0) return _Reference.single(frame.localPath!, imageId: frame.id, placeKey: key);
      return _Reference(frames, index: index, placeKey: key);
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
      return _Reference.single(picked.path);
    case _ReferenceSource.none:
      return null;
  }
}

Future<_ReferenceSource?> _askReferenceSource(
  BuildContext context, {
  required bool hasPlace,
  _SheetMode mode = _SheetMode.camera,
}) {
  final intro = switch (mode) {
    _SheetMode.camera =>
      'The reference floats over your camera in a small window you can drag '
          'and pinch. Tap it for opacity; double-tap it to shrink it to a dot.',
    _SheetMode.floatOnly =>
      'The reference floats over every app until you close it, so you can '
          'shoot as many photos as you like with your own camera app. '
          'Double-tap it to shrink it to a dot.',
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
              hasPlace ? "This place's anime frames" : "A place's anime frames",
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(ctx, _ReferenceSource.place),
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
/// reference (camera flow only); null means the dialog was dismissed, or
/// App info was opened instead.
Future<bool?> _askOverlayPermission(
  BuildContext context, {
  bool floatOnly = false,
}) async {
  // A downloaded APK on Android 13+ can't be given the permission until
  // "Allow restricted settings" is on in App info; Android only says so with
  // an "App access denied" dialog, so say what to do first.
  final restricted = await CameraOverlay.mayBeRestricted();
  if (!context.mounted) return null;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        floatOnly
            ? 'Float the reference over other apps?'
            : 'Float the reference over the camera?',
      ),
      content: Text(
        [
          floatOnly
              ? 'Allow "Display over other apps" for Trip Planner, then try '
                    'again.'
              : 'Allow "Display over other apps" for Trip Planner, then open '
                    'the camera again.',
          if (restricted)
            'If Android says the setting is restricted ("App access denied"): '
                'open App info, tap ⋮ at the top right, choose "Allow '
                'restricted settings", then come back and allow it. Android '
                'asks this of apps installed from a downloaded file.',
          if (!floatOnly)
            'Without it you can still shoot — the reference opens in the '
                'editor.',
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, floatOnly ? null : false),
          child: Text(floatOnly ? 'Cancel' : 'Shoot without it'),
        ),
        if (restricted)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              CameraOverlay.openAppInfo();
            },
            child: const Text('App info'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
}
