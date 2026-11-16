import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/platform_media.dart';
import 'edit_preview_service.dart';
import 'edit_recipe.dart';

// The full-resolution render behind Save and Compose: the photo is decoded
// once with the engine's native codec, edited as raw pixels in a worker
// isolate ([renderEdits]), and encoded once — on Android by the platform's
// own JPEG encoder.

/// The photo at [sourcePath] with [recipe] applied, at full resolution.
Future<RgbaImage> renderEditedPixels(
  String sourcePath,
  EditRecipe recipe,
) async => _applyRecipe(
  await decodeRgba(await readMediaBytes(sourcePath)),
  recipe,
);

/// [recipe] applied to the decoded [photo], in a worker isolate.
Future<RgbaImage> _applyRecipe(RgbaImage photo, EditRecipe recipe) async {
  if (recipe.isEmpty) return photo;
  final references = <Uint8List?>[];
  for (final step in recipe.steps) {
    final path = step.tool == 'match' && !step.isNoOp
        ? step.referencePath
        : null;
    references.add(path == null ? null : await readMediaBytes(path));
  }
  return compute(renderEdits, RenderEditsArgs(photo, recipe, references));
}

/// [renderEditedPixels] as the JPEG Save writes. Logs how long the decode,
/// the edits and the encode took, so a slow save on a phone shows where the
/// time went (`adb logcat -s flutter`).
Future<Uint8List> renderEditedJpeg(String sourcePath, EditRecipe recipe) async {
  final watch = Stopwatch()..start();
  final photo = await decodeRgba(await readMediaBytes(sourcePath));
  final decoded = watch.elapsedMilliseconds;
  final edited = await _applyRecipe(photo, recipe);
  final rendered = watch.elapsedMilliseconds;
  final (jpeg, encoder) = await _encode(edited, 95);
  debugPrint(
    'Photo save render: ${photo.width}×${photo.height} decoded in '
    '$decoded ms, edited in ${rendered - decoded} ms, '
    '${edited.width}×${edited.height} encoded in '
    '${watch.elapsedMilliseconds - rendered} ms by the $encoder encoder',
  );
  return jpeg;
}

/// [renderEditedPixels] as an image Compose can draw its layers on. With
/// nothing to apply, the photo is decoded straight into one.
Future<ui.Image> renderEditedImage(String sourcePath, EditRecipe recipe) async {
  if (recipe.isEmpty) {
    return decodeUiImage(await readMediaBytes(sourcePath));
  }
  return imageFromRgba(await renderEditedPixels(sourcePath, recipe));
}

/// Decodes [bytes] with the engine's codec, which applies the EXIF
/// orientation, so the result is upright.
Future<ui.Image> decodeUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// [decodeUiImage] as raw pixels: native, and several times faster than
/// package:image's pure-Dart decoder.
Future<RgbaImage> decodeRgba(Uint8List bytes) async {
  final image = await decodeUiImage(bytes);
  try {
    return await rgbaOf(image);
  } finally {
    image.dispose();
  }
}

/// [image]'s pixels. They're premultiplied, which only differs from
/// straight RGBA where a pixel is see-through — never in a photo.
Future<RgbaImage> rgbaOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('could not read the image pixels');
  return RgbaImage(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    image.width,
    image.height,
  );
}

/// An image of raw pixels, for drawing.
Future<ui.Image> imageFromRgba(RgbaImage image) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(image.pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: image.width,
    height: image.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

/// `trip_planner/jpeg` (`JpegEncoder.kt`).
const _jpegChannel = BasicMessageChannel<ByteData>(
  'trip_planner/jpeg',
  BinaryCodec(),
);

/// JPEG-encodes [image] at [quality]. On Android it's the platform's own
/// encoder (libjpeg-turbo), several times faster than package:image's;
/// elsewhere, or if that fails, the pure-Dart one runs in a worker isolate.
Future<Uint8List> encodeJpeg(RgbaImage image, {int quality = 95}) async =>
    (await _encode(image, quality)).$1;

/// [encodeJpeg], along with which encoder ran: "Android" or "Dart".
Future<(Uint8List, String)> _encode(RgbaImage image, int quality) async {
  if (!kIsWeb && Platform.isAndroid) {
    final jpeg = await _encodeOnAndroid(image, quality);
    if (jpeg != null) return (jpeg, 'Android');
  }
  final jpeg = await compute(
    encodeRgbaJpeg,
    RgbaJpegArgs(image.pixels, image.width, image.height, quality: quality),
  );
  return (jpeg, 'Dart');
}

/// The message is a 12-byte little-endian header (width, height, quality)
/// followed by the pixels; the reply is the JPEG, or empty on failure.
Future<Uint8List?> _encodeOnAndroid(RgbaImage image, int quality) async {
  try {
    final message = Uint8List(12 + image.pixels.length);
    message.buffer.asByteData()
      ..setInt32(0, image.width, Endian.little)
      ..setInt32(4, image.height, Endian.little)
      ..setInt32(8, quality, Endian.little);
    message.setRange(12, message.length, image.pixels);
    final reply = await _jpegChannel.send(message.buffer.asByteData());
    if (reply == null || reply.lengthInBytes == 0) {
      // JpegEncoder.kt logs why under its own tag.
      debugPrint('Native JPEG encode failed, using the Dart encoder');
      return null;
    }
    return reply.buffer.asUint8List(reply.offsetInBytes, reply.lengthInBytes);
  } catch (e) {
    debugPrint('Native JPEG encode failed, using the Dart encoder: $e');
    return null;
  }
}
