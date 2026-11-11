import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

/// Whether [path] is an HTTP(S), blob, or inline data URI rather than a local
/// filesystem path.
bool isRemoteOrMemoryUri(String path) {
  final lower = path.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('blob:') ||
      lower.startsWith('data:');
}

/// Encodes raw image [bytes] as an inline RFC 2397 `data:` URI so saved Web
/// captures outlive ephemeral `blob:` URLs across tab reloads.
String encodeDataUrl(Uint8List bytes, {String mimeType = 'image/jpeg'}) =>
    'data:$mimeType;base64,${base64Encode(bytes)}';

/// Whether [pathOrUrl] exists as a usable media source on the current platform.
Future<bool> mediaExists(String? pathOrUrl) async {
  if (pathOrUrl == null || pathOrUrl.isEmpty) return false;
  if (isRemoteOrMemoryUri(pathOrUrl)) return true;
  if (kIsWeb) return false;
  return File(pathOrUrl).exists();
}

/// Reads the raw bytes of a local file, `blob:`, `data:`, or `http(s):` URI.
Future<Uint8List> readMediaBytes(
  String pathOrUrl, {
  http.Client? client,
}) async {
  final lower = pathOrUrl.toLowerCase();
  if (lower.startsWith('data:')) {
    return UriData.parse(pathOrUrl).contentAsBytes();
  }
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final response = await httpClient
          .get(Uri.parse(pathOrUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('Failed to fetch media (HTTP ${response.statusCode})');
      }
      return response.bodyBytes;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
  if (kIsWeb) {
    return XFile(pathOrUrl).readAsBytes();
  }
  return File(pathOrUrl).readAsBytes();
}

/// Triggers a browser download on Web for raw [bytes].
Future<void> saveBytesAsMediaDownload(
  Uint8List bytes, {
  required String filename,
  String mimeType = 'image/jpeg',
}) async {
  await XFile.fromData(
    bytes,
    mimeType: mimeType,
    name: filename,
  ).saveTo(filename);
}

/// Renders an image from a local path, `http(s):` URL, `blob:` URL, or `data:`
/// URI across native and Web without calling unsupported `Image.file` on Web.
class PlatformImage extends StatefulWidget {
  final String pathOrUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String? semanticLabel;

  const PlatformImage(
    this.pathOrUrl, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.errorBuilder,
    this.semanticLabel,
  });

  @override
  State<PlatformImage> createState() => _PlatformImageState();
}

class _PlatformImageState extends State<PlatformImage> {
  Uint8List? _decodedDataBytes;
  Object? _decodeError;
  StackTrace? _decodeStackTrace;

  @override
  void initState() {
    super.initState();
    _syncDataBytes();
  }

  @override
  void didUpdateWidget(PlatformImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathOrUrl != widget.pathOrUrl) {
      _syncDataBytes();
    }
  }

  void _syncDataBytes() {
    _decodedDataBytes = null;
    _decodeError = null;
    _decodeStackTrace = null;
    if (!widget.pathOrUrl.toLowerCase().startsWith('data:')) return;
    try {
      _decodedDataBytes = UriData.parse(widget.pathOrUrl).contentAsBytes();
    } catch (e, st) {
      _decodeError = e;
      _decodeStackTrace = st;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lower = widget.pathOrUrl.toLowerCase();
    if (lower.startsWith('data:')) {
      if (_decodedDataBytes != null) {
        return Image.memory(
          _decodedDataBytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          errorBuilder: widget.errorBuilder,
          semanticLabel: widget.semanticLabel,
        );
      }
      return widget.errorBuilder?.call(
            context,
            _decodeError ?? StateError('Invalid data URI'),
            _decodeStackTrace,
          ) ??
          const SizedBox.shrink();
    }

    if (isRemoteOrMemoryUri(widget.pathOrUrl)) {
      return Image.network(
        widget.pathOrUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        errorBuilder: widget.errorBuilder,
        semanticLabel: widget.semanticLabel,
      );
    }

    if (kIsWeb) {
      // A raw filesystem path from another device cannot be opened via dart:io
      // on Web and should not fire a spurious 404 request.
      return widget.errorBuilder?.call(
            context,
            UnsupportedError('Local filesystem paths are unavailable on Web'),
            null,
          ) ??
          const SizedBox.shrink();
    }

    return Image.file(
      File(widget.pathOrUrl),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      errorBuilder: widget.errorBuilder,
      semanticLabel: widget.semanticLabel,
    );
  }
}
