import 'package:image/image.dart' as img;

import 'isnet_mask.dart';
import 'isnet_model_store.dart';

/// Web fallback stub for IS-Net cutout service (ONNX Runtime is native-only).
class IsnetCutoutService {
  IsnetCutoutService({IsnetModelStore? store})
      : store = store ?? IsnetModelStore();

  final IsnetModelStore store;

  static const int inputRes = 1024;

  Future<IsnetMask> segment(img.Image original) async {
    throw UnsupportedError('IS-Net cutout is not supported on Web.');
  }

  void dispose() {}
}
