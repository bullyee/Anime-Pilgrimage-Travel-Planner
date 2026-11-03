import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_providers.dart';

/// A spot's preview in a list: the place's cover, else its first anime
/// frame, else [extraCover] (a stop's own copy of the cover), else
/// [fallback]. Only files already on the device are shown; a list never
/// fetches images.
class SpotThumb extends ConsumerWidget {
  final String placeKey;
  final String? extraCover;
  final Widget fallback;
  final double size;

  const SpotThumb({super.key, required this.placeKey, required this.fallback, this.extraCover, this.size = 48});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(placeCoversProvider).valueOrNull?[placeKey] ??
        ref.watch(placeFramePathsProvider).valueOrNull?[placeKey]?.firstOrNull ??
        ((extraCover?.isNotEmpty ?? false) ? extraCover : null);
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
