import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../library/models/frames.dart' show frameCaption;
import '../../poi/services/full_res_render.dart' show encodeJpeg, rgbaOf;
import '../providers/photos_providers.dart';

// The share image (Photos → Pairs → Share image): up to eight pairs of an
// anime frame over the user's photo of it, under a title, as one JPEG to
// save or send.

/// The most pairs one share image holds.
const shareImageMax = 8;

enum ShareImageLayout { grid, stacked }

/// [selected] with [id] picked or unpicked, in the order they were picked.
/// Picking one more than [max] is refused: the list stays as it was.
({List<String> selected, bool refused}) toggleSharePick(List<String> selected, String id, {int max = shareImageMax}) {
  if (selected.contains(id)) return (selected: [for (final s in selected) if (s != id) s], refused: false);
  if (selected.length >= max) return (selected: selected, refused: true);
  return (selected: [...selected, id], refused: false);
}

/// The photos shot against a frame, newest first, each as its latest
/// version: an original that has an edit gives way to the edit.
List<PhotoEntry> shotPairs(List<PhotoEntry> entries) =>
    [for (final e in entries) if (e.frame != null && !e.hasEdit) e]..sort((a, b) => b.time.compareTo(a.time));

/// "宇治橋 › 東詰": the place, then the spot (the frame's note), else the
/// frame's episode and time.
String pairCaption(PhotoEntry e, {required String placeFallback}) {
  final place = e.place?.name ?? placeFallback;
  final frame = e.frame;
  final note = frame?.note?.trim().split('\n').first.trim();
  final spot = note != null && note.isNotEmpty ? note : (frame == null ? null : frameCaption(frame));
  return spot == null ? place : '$place › $spot';
}

/// The share image's default title: the trip's ("Kansai 2026.6"), else
/// [fallback], with the year and month of the newest photo.
String defaultShareTitle({String? tripTitle, required String fallback, required DateTime newest}) {
  final name = tripTitle?.trim();
  return '${name == null || name.isEmpty ? fallback : name} ${newest.year}.${newest.month}';
}

/// How the share image is laid out for [count] pairs: one column when
/// stacked; else two (or one for a single pair), each pair a frame over a
/// photo, both 16:9, with a caption under them.
class ShareImageGeometry {
  final int cols;
  final int rows;

  /// A frame's (and a photo's) size.
  final double cellWidth;
  final double cellHeight;
  final double width;
  final double height;

  static const gap = 10.0;
  static const head = 150.0;
  static const caption = 56.0;
  static const foot = 50.0;

  const ShareImageGeometry._(this.cols, this.rows, this.cellWidth, this.cellHeight, this.width, this.height);

  factory ShareImageGeometry(int count, ShareImageLayout layout) {
    final n = math.max(1, count);
    final stacked = layout == ShareImageLayout.stacked;
    final cols = stacked ? 1 : math.min(2, n);
    final rows = (n / cols).ceil();
    final cw = stacked ? 1080.0 : 760.0;
    final ch = (cw * 9 / 16).roundToDouble();
    final pairHeight = ch * 2 + gap + caption;
    return ShareImageGeometry._(
      cols,
      rows,
      cw,
      ch,
      cols * cw + (cols + 1) * gap * 2,
      head + rows * (pairHeight + gap * 3) + foot,
    );
  }

  /// Where pair [i]'s frame goes; its photo is right under it.
  Offset origin(int i) => Offset(
        gap * 2 + (i % cols) * (cellWidth + gap * 2),
        head + (i ~/ cols) * (cellHeight * 2 + gap + caption + gap * 3),
      );
}

/// A pair as drawn: the frame, the user's photo and its caption.
class SharePair {
  final ui.Image frame;
  final ui.Image photo;
  final String caption;

  const SharePair({required this.frame, required this.photo, required this.caption});
}

/// Draws [pairs] under [title] and [subtitle] and encodes it as a JPEG.
Future<Uint8List> renderShareImage(
  List<SharePair> pairs, {
  required String title,
  required String subtitle,
  required ShareImageLayout layout,
}) async {
  final g = ShareImageGeometry(pairs.length, layout);
  final w = g.width.round();
  final h = g.height.round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, g.width, g.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, g.width, g.height), Paint()..color = const Color(0xFF0E1311));
  _text(canvas, title, const Offset(28, 44), 56, const Color(0xFFF2F5F3), FontWeight.w700, g.width - 56);
  _text(canvas, subtitle, const Offset(30, 110), 26, const Color(0xFF73C6A0), FontWeight.w500, g.width - 60);
  for (final (i, pair) in pairs.indexed) {
    final at = g.origin(i);
    _cover(canvas, pair.frame, Rect.fromLTWH(at.dx, at.dy, g.cellWidth, g.cellHeight));
    _cover(canvas, pair.photo, Rect.fromLTWH(at.dx, at.dy + g.cellHeight + ShareImageGeometry.gap, g.cellWidth, g.cellHeight));
    _text(
      canvas,
      pair.caption,
      Offset(at.dx + 4, at.dy + g.cellHeight * 2 + ShareImageGeometry.gap + 12),
      28,
      const Color(0xFFC9D4CF),
      FontWeight.w500,
      g.cellWidth - 8,
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  try {
    return await encodeJpeg(await rgbaOf(image), quality: 90);
  } finally {
    image.dispose();
  }
}

/// Draws [image] filling [dst], cropped to its aspect from the middle.
void _cover(Canvas canvas, ui.Image image, Rect dst) {
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final scale = math.max(dst.width / iw, dst.height / ih);
  final sw = dst.width / scale;
  final sh = dst.height / scale;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh),
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );
}

void _text(Canvas canvas, String text, Offset at, double size, Color color, FontWeight weight, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: math.max(0, maxWidth));
  painter.paint(canvas, at);
  painter.dispose();
}
