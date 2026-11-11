import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/camera/models/shot_series.dart';
import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart';

NewReferenceImage _frame(String id) =>
    NewReferenceImage(id: id, placeKey: 'uji', localPath: '/frames/$id.jpg', createdAt: DateTime(2026));

void main() {
  final frames = [_frame('u1'), _frame('u2'), _frame('u3'), _frame('u4')];

  test("the camera gets the spot's frames in order, starting on the one picked", () async {
    final fetched = <String>[];
    final result = await seriesFrames(
      frames,
      2,
      start: (f) async {
        fetched.add(f.id);
        return '/start/${f.id}.jpg';
      },
      other: (f) async => '/device/${f.id}.jpg',
    );

    expect(result!.index, 2);
    expect(result.frames, [
      const SeriesFrame('/device/u1.jpg', imageId: 'u1'),
      const SeriesFrame('/device/u2.jpg', imageId: 'u2'),
      const SeriesFrame('/start/u3.jpg', imageId: 'u3'),
      const SeriesFrame('/device/u4.jpg', imageId: 'u4'),
    ]);
    expect(fetched, ['u3'], reason: 'only the starting frame may be downloaded');
  });

  test("frames that aren't on the phone are left out, and the start moves with them", () async {
    final result = await seriesFrames(
      frames,
      2,
      start: (f) async => '/start/${f.id}.jpg',
      other: (f) async => f.id == 'u1' ? null : '/device/${f.id}.jpg',
    );

    expect(result!.frames.map((f) => f.imageId), ['u2', 'u3', 'u4']);
    expect(result.index, 1);
  });

  test("the starting frame missing: nothing to shoot against", () async {
    expect(
      await seriesFrames(frames, 0, start: (f) async => null, other: (f) async => '/device/${f.id}.jpg'),
      isNull,
    );
    expect(await seriesFrames(const [], 0, start: (f) async => 'x', other: (f) async => 'x'), isNull);
  });

  test('an index out of range starts on the nearest end', () async {
    final result = await seriesFrames(frames, 9, start: (f) async => 's', other: (f) async => 'o');
    expect((result!.index, result.frames[result.index].imageId), (3, 'u4'));
  });
}
