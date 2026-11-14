import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class CameraState {
  final bool isInitialized;
  final File? referenceImage;
  final String? referencePath;
  final String? referenceImageId;
  // Whether the reference overlay should currently be painted on top
  // of the live preview. The reference itself stays in state when
  // toggled off so the user can flick it back on without re-picking.
  final bool overlayVisible;
  final String? placeKey;
  final String? error;
  final Offset overlayOffset;
  final double overlayScale;
  final double overlayOpacity;

  const CameraState({
    this.isInitialized = false,
    this.referenceImage,
    this.referencePath,
    this.referenceImageId,
    this.overlayVisible = true,
    this.placeKey,
    this.error,
    this.overlayOffset = Offset.zero,
    this.overlayScale = 1,
    this.overlayOpacity = 0.55,
  });

  /// Effective reference path or URL for both native files and Web URLs.
  String? get effectiveReferencePath => referencePath ?? referenceImage?.path;

  CameraState copyWith({
    bool? isInitialized,
    File? referenceImage,
    String? referencePath,
    String? referenceImageId,
    bool? overlayVisible,
    String? placeKey,
    String? error,
    Offset? overlayOffset,
    double? overlayScale,
    double? overlayOpacity,
    bool clearReferenceImage = false,
    bool clearReferenceImageId = false,
    bool clearError = false,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      referenceImage:
          clearReferenceImage ? null : (referenceImage ?? this.referenceImage),
      referencePath:
          clearReferenceImage ? null : (referencePath ?? this.referencePath),
      referenceImageId: (clearReferenceImage || clearReferenceImageId)
          ? null
          : (referenceImageId ?? this.referenceImageId),
      overlayVisible: overlayVisible ?? this.overlayVisible,
      placeKey: placeKey ?? this.placeKey,
      error: clearError ? null : (error ?? this.error),
      overlayOffset: overlayOffset ?? this.overlayOffset,
      overlayScale: overlayScale ?? this.overlayScale,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
    );
  }
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  void initialize(String? placeKey) {
    state = state.copyWith(placeKey: placeKey, isInitialized: true, clearError: true);
  }

  void setCameraError(String message) {
    state = state.copyWith(error: message);
  }

  void setReferenceImage(File file, {String? referenceImageId}) {
    state = state.copyWith(
      referenceImage: file,
      referencePath: file.path,
      referenceImageId: referenceImageId,
      clearReferenceImageId: referenceImageId == null,
      overlayVisible: true,
      overlayOffset: Offset.zero,
      overlayScale: 1,
      overlayOpacity: 0.55,
    );
  }

  /// Sets the reference overlay from either a filesystem path or a Web URI.
  void setReferencePath(String path, {String? referenceImageId}) {
    state = state.copyWith(
      referencePath: path,
      referenceImageId: referenceImageId,
      clearReferenceImageId: referenceImageId == null,
      overlayVisible: true,
      overlayOffset: Offset.zero,
      overlayScale: 1,
      overlayOpacity: 0.55,
    );
  }

  /// Switches to another frame of the same spot, keeping where the overlay
  /// is, its size and its opacity.
  void switchReference(File file, {required String referenceImageId}) {
    state = state.copyWith(
      referenceImage: file,
      referencePath: file.path,
      referenceImageId: referenceImageId,
      overlayVisible: true,
    );
  }

  /// Switches to another frame by path or URL, preserving overlay transforms.
  void switchReferencePath(String path, {required String referenceImageId}) {
    state = state.copyWith(
      referencePath: path,
      referenceImageId: referenceImageId,
      overlayVisible: true,
    );
  }

  void clearReferenceImage() {
    state = state.copyWith(clearReferenceImage: true);
  }

  /// Flip the overlay's visibility without throwing away the reference
  /// itself — the eye-icon toggle uses this so the user can hide the
  /// overlay temporarily and bring it back without re-picking from
  /// the library.
  void toggleOverlayVisibility() {
    state = state.copyWith(overlayVisible: !state.overlayVisible);
  }

  void updateOverlayTransform({
    required Offset offset,
    required double scale,
  }) {
    state = state.copyWith(
      overlayOffset: offset,
      overlayScale: scale.clamp(0.35, 4).toDouble(),
    );
  }

  void setOverlayOpacity(double opacity) {
    state = state.copyWith(overlayOpacity: opacity.clamp(0.1, 1).toDouble());
  }

  void resetOverlay() {
    state = state.copyWith(
      overlayOffset: Offset.zero,
      overlayScale: 1,
      overlayOpacity: 0.55,
    );
  }

  void setPlaceKey(String key) {
    state = state.copyWith(placeKey: key);
  }
}

final cameraProvider =
    StateNotifierProvider.autoDispose<CameraNotifier, CameraState>(
  (ref) => CameraNotifier(),
);
