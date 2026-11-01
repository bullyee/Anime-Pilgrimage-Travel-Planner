import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/thumbnail_cache_service.dart';

part 'thumbnail_cache_provider.g.dart';

@Riverpod(keepAlive: true)
ThumbnailCacheService thumbnailCacheService(Ref ref) {
  return ThumbnailCacheService();
}

