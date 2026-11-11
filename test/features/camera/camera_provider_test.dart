import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/camera/providers/camera_provider.dart';

void main() {
  test("switching to another frame keeps the overlay where it is, its size and its opacity", () {
    final camera = CameraNotifier()
      ..setReferenceImage(File('/frames/u1.jpg'), referenceImageId: 'u1')
      ..updateOverlayTransform(offset: const Offset(20, -40), scale: 1.6)
      ..setOverlayOpacity(0.8)
      ..toggleOverlayVisibility();

    camera.switchReference(File('/frames/u2.jpg'), referenceImageId: 'u2');

    final state = camera.debugState;
    expect((state.referenceImage!.path, state.referenceImageId), ('/frames/u2.jpg', 'u2'));
    expect((state.overlayOffset, state.overlayScale, state.overlayOpacity), (const Offset(20, -40), 1.6, 0.8));
    expect(state.overlayVisible, isTrue, reason: 'the new frame shows');

    // Picking a frame anew starts the overlay over.
    camera.setReferenceImage(File('/frames/u3.jpg'), referenceImageId: 'u3');
    expect(camera.debugState.overlayScale, 1);
  });
}
