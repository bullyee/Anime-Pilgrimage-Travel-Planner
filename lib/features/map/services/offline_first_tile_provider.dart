import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import '../models/map_tile_models.dart';
import 'offline_map_tile_service.dart';

/// Offline-first [TileProvider] that serves tiles directly from local disk cache,
/// transparently caching newly browsed tiles to disk for future offline use.
class OfflineFirstTileProvider extends TileProvider {
  final OfflineMapTileService service;
  final Directory cacheDir;
  final http.Client? client;
  final bool silenceExceptions;

  OfflineFirstTileProvider({
    required this.service,
    required this.cacheDir,
    this.client,
    this.silenceExceptions = true,
    super.headers,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tile = TileCoordinate(
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
    );

    final localFile = service.getTileFile(cacheDir, tile);
    if (localFile.existsSync()) {
      return FileImage(localFile);
    }

    final urlTemplate = options.urlTemplate ?? OfflineMapTileService.defaultOsmUrlTemplate;
    final url = urlTemplate
        .replaceAll('{z}', tile.z.toString())
        .replaceAll('{x}', tile.x.toString())
        .replaceAll('{y}', tile.y.toString());

    return _OfflineCachingImageProvider(
      url: url,
      targetFile: localFile,
      client: client,
      headers: {
        'User-Agent': OfflineMapTileService.userAgent,
        ...headers,
      },
      silenceExceptions: silenceExceptions,
    );
  }
}

@immutable
class _OfflineCachingKey {
  final String url;
  final String targetPath;

  const _OfflineCachingKey(this.url, this.targetPath);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OfflineCachingKey &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          targetPath == other.targetPath;

  @override
  int get hashCode => Object.hash(url, targetPath);
}

class _OfflineCachingImageProvider
    extends ImageProvider<_OfflineCachingKey> {
  final String url;
  final File targetFile;
  final http.Client? client;
  final Map<String, String> headers;
  final bool silenceExceptions;

  const _OfflineCachingImageProvider({
    required this.url,
    required this.targetFile,
    this.client,
    this.headers = const {},
    this.silenceExceptions = true,
  });

  @override
  Future<_OfflineCachingKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_OfflineCachingKey>(
      _OfflineCachingKey(url, targetFile.path),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    _OfflineCachingKey key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<String>('URL', url),
        DiagnosticsProperty<String>('Local File', targetFile.path),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    _OfflineCachingKey key,
    ImageDecoderCallback decode,
  ) async {
    // 1. If file was saved while waiting, decode directly from disk
    if (await targetFile.exists()) {
      final bytes = await targetFile.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }

    // 2. Fetch from network
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;

    try {
      final response = await httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Save to local cache in background
        try {
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(response.bodyBytes, flush: true);
        } catch (_) {
          // Ignore disk write errors, still render the image
        }

        final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
        return decode(buffer);
      }
    } catch (e) {
      if (!silenceExceptions) rethrow;
    } finally {
      if (ownsClient) httpClient.close();
    }

    // 3. Fallback to 1x1 transparent PNG when offline or request fails
    final transparentBuffer =
        await ui.ImmutableBuffer.fromUint8List(_transparent1x1Png);
    return decode(transparentBuffer);
  }

  /// 1x1 transparent PNG byte constant
  static final Uint8List _transparent1x1Png = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}
