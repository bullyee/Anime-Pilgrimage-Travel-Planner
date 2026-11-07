import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/map/models/map_tile_models.dart';
import 'package:trip_planner/features/map/providers/offline_map_providers.dart';
import 'package:trip_planner/features/map/services/offline_first_tile_provider.dart';
import 'package:trip_planner/features/map/services/offline_map_tile_service.dart';
import 'package:trip_planner/features/map/services/tile_math.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('map_tile_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Sample 1x1 PNG bytes for mock HTTP responses
  final mockTileBytes = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  group('TileMath', () {
    test('latLngToTile converts Kyoto Station coordinates accurately', () {
      // Kyoto Station: 34.985833, 135.758333
      final tile15 = TileMath.latLngToTile(34.985833, 135.758333, 15);
      expect(tile15.z, 15);
      expect(tile15.x, 28741);
      expect(tile15.y, 12980);

      // Zoom 0 covers the entire world in one tile
      final tile0 = TileMath.latLngToTile(34.985833, 135.758333, 0);
      expect(tile0.z, 0);
      expect(tile0.x, 0);
      expect(tile0.y, 0);
    });

    test('tileToNorthWestLatLng reverses tile index to coordinates', () {
      final coords = TileMath.tileToNorthWestLatLng(28741, 12980, 15);
      expect(coords.lat, closeTo(34.9858, 0.05));
      expect(coords.lng, closeTo(135.758, 0.05));
    });

    test('tilesForBoundingBox and estimateTileCount calculate correct tile sets', () {
      const bbox = BoundingBox(
        minLat: 34.88,
        maxLat: 34.90,
        minLng: 135.80,
        maxLng: 135.82,
      );

      final count14 = TileMath.estimateTileCount(bbox, [14]);
      expect(count14, greaterThan(0));
      expect(count14, lessThan(10));

      final tiles14 = TileMath.tilesForBoundingBox(bbox, 14);
      expect(tiles14.length, count14);

      for (final t in tiles14) {
        expect(t.z, 14);
        expect(t.x, greaterThan(0));
        expect(t.y, greaterThan(0));
      }
    });
  });

  group('BoundingBox', () {
    test('fromPoints expands tight bounds with buffer margin', () {
      final points = [
        (lat: 34.891111, lng: 135.808056), // Keihan Uji
        (lat: 34.893889, lng: 135.816667), // Daikichiyama
      ];

      final bbox = BoundingBox.fromPoints(points, bufferMeters: 500.0);
      expect(bbox.minLat, lessThan(34.891111));
      expect(bbox.maxLat, greaterThan(34.893889));
      expect(bbox.minLng, lessThan(135.808056));
      expect(bbox.maxLng, greaterThan(135.816667));
    });

    test('handles empty points gracefully', () {
      final emptyBbox = BoundingBox.fromPoints([]);
      expect(emptyBbox.minLat, 0.0);
      expect(emptyBbox.maxLat, 0.0);
    });
  });

  group('OfflineMapTileService', () {
    late OfflineMapTileService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('tile.openstreetmap.org')) {
          return http.Response.bytes(mockTileBytes, 200);
        }
        return http.Response('not found', 404);
      });

      service = OfflineMapTileService(
        cacheDir: () async => tempDir,
      );
    });

    test('downloadTile downloads and writes tile file to disk cache', () async {
      const tile = TileCoordinate(z: 15, x: 28738, y: 12971);

      // Initially not cached
      expect(await service.getCachedTile(tile), isNull);

      final file = await service.downloadTile(tile, client: mockClient);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), mockTileBytes.length);

      // Now cached
      final cachedFile = await service.getCachedTile(tile);
      expect(cachedFile, isNotNull);
      expect(cachedFile!.path, file.path);
    });

    test('downloadTile returns null on HTTP error without throwing', () async {
      final failingClient = MockClient((request) async => http.Response('Server Error', 500));
      const tile = TileCoordinate(z: 15, x: 99999, y: 99999);

      final result = await service.downloadTile(tile, client: failingClient);
      expect(result, isNull);
    });

    test('prefetchTilesForBoundingBox downloads tiles and reports progress', () async {
      const bbox = BoundingBox(
        minLat: 34.891,
        maxLat: 34.893,
        minLng: 135.808,
        maxLng: 135.812,
      );

      final progressUpdates = <PrefetchProgress>[];

      final summary = await service.prefetchTilesForBoundingBox(
        bbox,
        zoomLevels: [15],
        client: mockClient,
        onProgress: progressUpdates.add,
      );

      expect(summary.totalTiles, greaterThan(0));
      expect(summary.downloadedTiles, summary.totalTiles);
      expect(summary.alreadyCachedTiles, 0);
      expect(summary.failedTiles, 0);
      expect(summary.totalBytes, greaterThan(0));
      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.last.isDone, isTrue);

      // Running again on the same region: all tiles are already cached!
      final summary2 = await service.prefetchTilesForBoundingBox(
        bbox,
        zoomLevels: [15],
        client: mockClient,
      );
      expect(summary2.alreadyCachedTiles, summary.totalTiles);
      expect(summary2.downloadedTiles, 0);
    });

    test('prefetchTilesForBoundingBox throws ArgumentError when exceeding maxTiles threshold', () async {
      // Entire Japan at zoom 16 would require thousands of tiles
      const massiveBbox = BoundingBox(
        minLat: 30.0,
        maxLat: 45.0,
        minLng: 128.0,
        maxLng: 145.0,
      );

      expect(
        () => service.prefetchTilesForBoundingBox(
          massiveBbox,
          zoomLevels: [15, 16],
          maxTiles: 100,
        ),
        throwsArgumentError,
      );
    });

    test('prefetchTilesForStops precalculates bounds and prefetches pilgrimage route', () async {
      final stops = [
        Stop(
          id: 's1',
          tripId: 't1',
          placeKey: 'p1',
          name: '京阪宇治站',
          lat: 34.891111,
          lng: 135.808056,
          addedBy: 'u1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: 0,
        ),
        Stop(
          id: 's2',
          tripId: 't1',
          placeKey: 'p2',
          name: '大吉山展望台',
          lat: 34.893889,
          lng: 135.816667,
          addedBy: 'u1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: 0,
        ),
      ];

      final summary = await service.prefetchTilesForStops(
        stops,
        zoomLevels: [14],
        bufferMeters: 300.0,
        client: mockClient,
      );

      expect(summary.totalTiles, greaterThan(0));
      expect(summary.downloadedTiles, summary.totalTiles);
    });

    test('cache size, count, and LRU eviction enforce storage quota', () async {
      // Download 3 tiles
      await service.downloadTile(const TileCoordinate(z: 14, x: 1, y: 1), client: mockClient);
      await service.downloadTile(const TileCoordinate(z: 14, x: 2, y: 2), client: mockClient);
      await service.downloadTile(const TileCoordinate(z: 14, x: 3, y: 3), client: mockClient);

      expect(await service.getCachedTileCount(), 3);
      final size = await service.getCacheSizeBytes();
      expect(size, mockTileBytes.length * 3);

      // Evict to quota less than 2 tiles
      final evicted = await service.evictOldestTiles(targetMaxBytes: mockTileBytes.length * 2 - 1);
      expect(evicted, greaterThanOrEqualTo(2));
      expect(await service.getCachedTileCount(), lessThanOrEqualTo(1));

      // Clear all
      await service.clearCache();
      expect(await service.getCachedTileCount(), 0);
      expect(await service.getCacheSizeBytes(), 0);
    });
  });

  group('OfflineFirstTileProvider', () {
    test('serves cached tile directly from disk when present', () async {
      final service = OfflineMapTileService(cacheDir: () async => tempDir);
      final tile = const TileCoordinate(z: 15, x: 100, y: 100);

      // Pre-save tile to disk
      final file = service.getTileFile(tempDir, tile);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(mockTileBytes);

      final provider = OfflineFirstTileProvider(
        service: service,
        cacheDir: tempDir,
      );

      final image = provider.getImage(
        TileCoordinates(100, 100, 15),
        TileLayer(urlTemplate: OfflineMapTileService.defaultOsmUrlTemplate),
      );

      expect(image, isA<FileImage>());
      expect((image as FileImage).file.path, file.path);
    });
  });

  group('Riverpod Providers', () {
    test('evaluates mapTileCacheSizeBytesProvider and count', () async {
      final testService = OfflineMapTileService(cacheDir: () async => tempDir);
      final container = ProviderContainer(
        overrides: [
          offlineMapTileServiceProvider.overrideWithValue(testService),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(mapTileCacheSizeBytesProvider.future), 0);
      expect(await container.read(mapTileCacheCountProvider.future), 0);
    });
  });
}
