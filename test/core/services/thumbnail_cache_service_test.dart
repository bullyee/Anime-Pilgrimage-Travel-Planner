import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/core/services/thumbnail_cache_service.dart';
import 'package:trip_planner/features/poi/services/anitabi_api_service.dart';

void main() {
  late Directory tempDir;
  int httpCallCount = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('thumb_cache_test_');
    httpCallCount = 0;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ThumbnailCacheService', () {
    test('downloads thumbnail with Anitabi User-Agent on first request and returns cached file on subsequent requests', () async {
      String? capturedUserAgent;
      final mockClient = MockClient((request) async {
        httpCallCount++;
        capturedUserAgent = request.headers['User-Agent'];
        return http.Response.bytes(
          List<int>.generate(100, (i) => i),
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });

      final service = ThumbnailCacheService(
        client: mockClient,
        overrideCacheDir: tempDir,
      );

      const url = 'https://example.com/anime/frame1.jpg';

      // 1. First fetch: downloads from network with Anitabi User-Agent
      final path1 = await service.getOrFetchThumbnail(url);
      expect(path1, isNotNull);
      expect(File(path1!).existsSync(), isTrue);
      expect(httpCallCount, 1);
      expect(capturedUserAgent, equals(AnitabiApiService.userAgent));

      // 2. Second fetch: hits local cache immediately
      final path2 = await service.getOrFetchThumbnail(url);
      expect(path2, equals(path1));
      expect(httpCallCount, 1); // No new network call!
    });

    test('deduplicates simultaneous in-flight requests for the same URL', () async {
      final mockClient = MockClient((request) async {
        httpCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response.bytes(
          List<int>.generate(50, (i) => i),
          200,
        );
      });

      final service = ThumbnailCacheService(
        client: mockClient,
        overrideCacheDir: tempDir,
      );

      const url = 'https://example.com/anime/dedup.png';

      // Fire 3 simultaneous requests for the exact same URL
      final results = await Future.wait([
        service.getOrFetchThumbnail(url),
        service.getOrFetchThumbnail(url),
        service.getOrFetchThumbnail(url),
      ]);

      expect(results[0], isNotNull);
      expect(results[0], equals(results[1]));
      expect(results[1], equals(results[2]));
      expect(httpCallCount, 1); // Deduplicated to single HTTP request!
    });

    test('prefetchThumbnails downloads and caches multiple thumbnails sequentially by default', () async {
      final mockClient = MockClient((request) async {
        httpCallCount++;
        return http.Response.bytes(
          List<int>.generate(20, (i) => i),
          200,
        );
      });

      final service = ThumbnailCacheService(
        client: mockClient,
        overrideCacheDir: tempDir,
      );

      final urls = [
        'https://example.com/thumb_1.jpg',
        'https://example.com/thumb_2.jpg',
        'https://example.com/thumb_3.jpg',
      ];

      await service.prefetchThumbnails(urls);
      expect(httpCallCount, 3);

      final cacheSize = await service.getCacheSizeBytes();
      expect(cacheSize, greaterThan(0));

      // Clear cache
      await service.clearCache();
      final cacheSizeAfterClear = await service.getCacheSizeBytes();
      expect(cacheSizeAfterClear, 0);
    });

    test('stops immediately and never retries when HTTP 403 or 429 is returned', () async {
      final mockClient = MockClient((request) async {
        httpCallCount++;
        return http.Response('Rate limited', 429);
      });

      final service = ThumbnailCacheService(
        client: mockClient,
        overrideCacheDir: tempDir,
      );

      final urls = [
        'https://image.anitabi.cn/points/1/a.jpg',
        'https://image.anitabi.cn/points/1/b.jpg',
        'https://image.anitabi.cn/points/1/c.jpg',
      ];

      await service.prefetchThumbnails(urls);

      // Must stop after the very first 429 without falling back to mirror or fetching remaining URLs
      expect(httpCallCount, equals(1));
      expect(service.isRateLimitedOrBlocked, isTrue);
    });

    test('handles network failure gracefully and returns null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = ThumbnailCacheService(
        client: mockClient,
        overrideCacheDir: tempDir,
      );

      final result = await service.getOrFetchThumbnail('https://example.com/not_found.jpg');
      expect(result, isNull);
    });

    test('getCacheSizeBytes and clearCache operate on thumbnail cache directory', () async {
      final mockClient = MockClient((request) async {
        return http.Response('IMAGE_BYTES_12345', 200, headers: {'content-type': 'image/jpeg'});
      });

      final service = ThumbnailCacheService(
        client: mockClient,
        overrideCacheDir: tempDir,
      );

      expect(await service.getCacheSizeBytes(), equals(0));

      await service.getOrFetchThumbnail('https://image.anitabi.cn/test1.jpg');
      final size = await service.getCacheSizeBytes();
      expect(size, greaterThan(0));

      await service.clearCache();
      expect(await service.getCacheSizeBytes(), equals(0));
    });
  });
}
