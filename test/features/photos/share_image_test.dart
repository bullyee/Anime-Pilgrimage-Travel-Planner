import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/photos/providers/photos_providers.dart';
import 'package:trip_planner/features/photos/services/share_image.dart';

/// The share image's pure parts and its drawing.
void main() {
  final t0 = DateTime(2026, 6, 19, 10);

  PhotoEntry entry(String id, DateTime at, {String? frameId, String? note, bool hasEdit = false, String? place = '宇治橋'}) => PhotoEntry(
        photo: Photo(id: id, placeKey: 'uji', kind: 'original', localPath: '$id.jpg', referenceImageId: frameId, isShared: false, keepAsIs: false, takenAt: at, createdAt: at),
        place: place == null ? null : Place(placeKey: 'uji', name: place, lat: 34.89, lng: 135.8, visibility: 'private', createdAt: t0, updatedAt: t0),
        frame: frameId == null ? null : NewReferenceImage(id: frameId, localPath: '$frameId.png', note: note, episode: '3', createdAt: t0),
        hasEdit: hasEdit,
      );

  group('picking pairs', () {
    test('picks in order, unpicks, and refuses a ninth', () {
      var picks = <String>[];
      for (var i = 0; i < shareImageMax; i++) {
        final r = toggleSharePick(picks, 'p$i');
        expect(r.refused, isFalse);
        picks = r.selected;
      }
      expect(picks, hasLength(8));
      final ninth = toggleSharePick(picks, 'p8');
      expect(ninth.refused, isTrue);
      expect(ninth.selected, picks);
      final off = toggleSharePick(picks, 'p3');
      expect(off.refused, isFalse);
      expect(off.selected, [for (var i = 0; i < 8; i++) if (i != 3) 'p$i']);
      expect(toggleSharePick(off.selected, 'p8').selected.last, 'p8', reason: 'room again after unpicking one');
    });
  });

  test('shotPairs: photos with a frame, newest first, the edit instead of its original', () {
    final pairs = shotPairs([
      entry('old', t0, frameId: 'f1'),
      entry('none', t0.add(const Duration(hours: 2))),
      entry('edited-original', t0.add(const Duration(hours: 1)), frameId: 'f2', hasEdit: true),
      entry('new', t0.add(const Duration(hours: 3)), frameId: 'f2'),
    ]);
    expect(pairs.map((e) => e.photo.id), ['new', 'old']);
  });

  test('captions: place › spot note, else the episode', () {
    expect(pairCaption(entry('a', t0, frameId: 'f', note: '東詰\n往上游'), placeFallback: '?'), '宇治橋 › 東詰');
    expect(pairCaption(entry('a', t0, frameId: 'f'), placeFallback: '?'), '宇治橋 › Ep 3');
    expect(pairCaption(entry('a', t0, frameId: 'f', note: '東詰', place: null), placeFallback: 'Gone'), 'Gone › 東詰');
  });

  test('the default title is the trip and the month', () {
    expect(defaultShareTitle(tripTitle: '關西聖地巡禮', fallback: 'x', newest: t0), '關西聖地巡禮 2026.6');
    expect(defaultShareTitle(tripTitle: '  ', fallback: 'My pilgrimage', newest: t0), 'My pilgrimage 2026.6');
  });

  test('layout: two columns in a grid (one for a single pair), one when stacked', () {
    final grid = ShareImageGeometry(5, ShareImageLayout.grid);
    expect((grid.cols, grid.rows), (2, 3));
    expect(grid.origin(1).dx, greaterThan(grid.origin(0).dx));
    expect(grid.origin(2).dy, greaterThan(grid.origin(0).dy));
    expect(ShareImageGeometry(1, ShareImageLayout.grid).cols, 1);
    final stacked = ShareImageGeometry(3, ShareImageLayout.stacked);
    expect((stacked.cols, stacked.rows), (1, 3));
    expect(stacked.width, lessThan(grid.width));
  });

  testWidgets('draws the pairs into a JPEG of the layout\'s size', (tester) async {
    await tester.runAsync(() async {
      Future<ui.Image> solid(Color color, int w, int h) {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = color);
        return recorder.endRecording().toImage(w, h);
      }

      final pairs = [
        for (var i = 0; i < 3; i++) SharePair(frame: await solid(Colors.red, 32, 18), photo: await solid(Colors.blue, 24, 32), caption: 'Place › $i'),
      ];
      final bytes = await renderShareImage(pairs, title: 'Kansai 2026.6', subtitle: '3 pairs', layout: ShareImageLayout.grid);
      final decoded = img.decodeJpg(bytes)!;
      final g = ShareImageGeometry(3, ShareImageLayout.grid);
      expect(decoded.width, g.width.round());
      expect(decoded.height, g.height.round());
    });
  });
}
