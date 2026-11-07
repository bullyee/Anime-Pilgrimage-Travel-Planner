import 'dart:typed_data';

/// Foreground mask representation output by IS-Net segmentation.
class IsnetMask {
  /// Soft foreground mask, [res]×[res], row-major, 0..1.
  final Float32List mask;

  /// Luma of the 1024² resized input, row-major, 0..1 — guide for guided filter.
  final Float32List guideLuma;

  /// Mask/guide resolution (model input size, 1024).
  final int res;

  const IsnetMask({
    required this.mask,
    required this.guideLuma,
    required this.res,
  });
}
