import 'package:cloud_firestore/cloud_firestore.dart';

import '../interfaces/template_web_renderer.dart';
import '../models/template_preview_info.dart';

/// Backend service for resolving public trip template deep links, short codes,
/// and generating OpenGraph social sharing preview metadata.
class TemplateLinkResolverService {
  final FirebaseFirestore _firestore;
  final ITemplateWebRenderer _renderer;
  final Map<String, TemplatePreviewInfo> _memoryCache = {};

  /// Default short code character set excluding ambiguous characters (0, O, 1, I, L).
  static final RegExp _validCodeRegex =
      RegExp(r'^[2-9A-HJKMNP-Z]{6}$', caseSensitive: false);

  TemplateLinkResolverService({
    FirebaseFirestore? firestore,
    ITemplateWebRenderer? renderer,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _renderer = renderer ?? const DefaultTemplateWebRenderer();

  /// Clears the in-memory resolution cache (useful for testing or cache eviction).
  void clearCache() => _memoryCache.clear();

  /// Extracts and validates a 6-character template short code from [input].
  ///
  /// Supports:
  /// - Full web URLs: `https://trip-planner-2775c.web.app/t/K7MN2P`
  /// - Firebase URLs: `https://trip-planner-2775c.firebaseapp.com/t/K7MN2P`
  /// - App deep links: `tripplanner://template/K7MN2P` or `animepilgrim://template/K7MN2P`
  /// - Relative paths: `/t/K7MN2P`
  /// - Raw short codes: `K7MN2P` or `k7mn2p`
  ///
  /// Returns the uppercase normalized 6-character code, or null if [input] is invalid.
  String? extractShortCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    String candidate = trimmed;

    // Check if it's a URI
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (uri.scheme == 'tripplanner' || uri.scheme == 'animepilgrim') {
        if (segments.isNotEmpty) {
          candidate = segments.last;
        } else if (uri.host.isNotEmpty && uri.host != 'template') {
          candidate = uri.host;
        }
      } else if (uri.host.contains('trip-planner-2775c') ||
          uri.host.contains('web.app') ||
          uri.host.contains('firebaseapp.com')) {
        final tIndex = segments.indexOf('t');
        if (tIndex != -1 && tIndex + 1 < segments.length) {
          candidate = segments[tIndex + 1];
        } else if (segments.isNotEmpty) {
          candidate = segments.last;
        }
      }
    } else if (trimmed.startsWith('/t/')) {
      candidate = trimmed.substring(3);
    }

    // Strip trailing slashes, fragments, or query params if any
    final queryIdx = candidate.indexOf('?');
    if (queryIdx != -1) candidate = candidate.substring(0, queryIdx);
    final hashIdx = candidate.indexOf('#');
    if (hashIdx != -1) candidate = candidate.substring(0, hashIdx);
    candidate = candidate.replaceAll('/', '').trim().toUpperCase();

    if (_validCodeRegex.hasMatch(candidate)) {
      return candidate;
    }
    return null;
  }

  /// Resolves [input] (URL or short code) to a [TemplatePreviewInfo].
  ///
  /// Queries Firestore `/template_codes/:code` and `/templates/:templateId`.
  /// Caches successfully resolved metadata in memory for zero-latency repeats.
  Future<TemplatePreviewInfo?> resolveTemplate(String input) async {
    final code = extractShortCode(input);
    if (code == null) return null;

    if (_memoryCache.containsKey(code)) {
      return _memoryCache[code]!;
    }

    try {
      final codeDoc =
          await _firestore.collection('template_codes').doc(code).get();
      if (!codeDoc.exists) return null;

      final data = codeDoc.data();
      final templateId = data?['templateId'] as String?;
      if (templateId == null || templateId.isEmpty) return null;

      final templateDoc =
          await _firestore.collection('templates').doc(templateId).get();
      if (!templateDoc.exists) return null;

      final templateData = templateDoc.data();
      if (templateData == null) return null;

      final preview = TemplatePreviewInfo.fromMap(
        templateData,
        code: code,
        templateId: templateId,
      );

      _memoryCache[code] = preview;
      return preview;
    } catch (_) {
      return null;
    }
  }

  /// Generates OpenGraph and Twitter card meta tag mappings for crawler scraping.
  Map<String, String> generateOpenGraphMetaTags(TemplatePreviewInfo preview) {
    final desc = preview.description?.isNotEmpty == true
        ? preview.description!
        : '${preview.dayCount} 天聖地巡禮行程 · 共 ${preview.stopCount} 個巡禮點 (作者: ${preview.authorName})';

    final tags = <String, String>{
      'og:type': 'website',
      'og:title': '${preview.title} | 聖地巡禮行程規劃',
      'og:description': desc,
      'og:url': preview.webUrl,
      'twitter:card': 'summary_large_image',
      'twitter:title': preview.title,
      'twitter:description': desc,
      'al:android:url': preview.appDeepLink,
      'al:android:package': 'com.example.trip_planner',
      'al:android:app_name': 'Trip Planner',
    };

    if (preview.coverImageUrl != null && preview.coverImageUrl!.isNotEmpty) {
      tags['og:image'] = preview.coverImageUrl!;
      tags['twitter:image'] = preview.coverImageUrl!;
    }

    return tags;
  }

  /// Generates a lightweight static HTML preview shell embedding OpenGraph tags
  /// and responsive web preview information for scrapers and browser visitors.
  String generateStaticPreviewHtml(TemplatePreviewInfo preview) {
    final meta = generateOpenGraphMetaTags(preview);
    final metaTagsHtml = meta.entries
        .map((e) =>
            '    <meta property="${_escapeHtml(e.key)}" content="${_escapeHtml(e.value)}">')
        .join('\n');

    final animeBadge = preview.animeNames.isNotEmpty
        ? '<div class="badge">${_escapeHtml(preview.animeNames.join(' · '))}</div>'
        : '';

    final coverHtml = preview.coverImageUrl != null &&
            preview.coverImageUrl!.isNotEmpty
        ? '<img class="cover" src="${_escapeHtml(preview.coverImageUrl!)}" alt="Cover">'
        : '<div class="cover placeholder">聖地巡禮行程</div>';

    return '''<!DOCTYPE html>
<html lang="zh-Hant">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${_escapeHtml(preview.title)} - 聖地巡禮行程預覽</title>
$metaTagsHtml
    <style>
        :root { --primary: #5B4B8A; --bg: #F8F9FA; --card: #FFFFFF; --text: #212529; --sub: #6C757D; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; padding: 16px; box-sizing: border-box; }
        .card { background: var(--card); border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); max-width: 440px; width: 100%; overflow: hidden; text-align: center; }
        .cover { width: 100%; height: 220px; object-fit: cover; background: #E9ECEF; }
        .placeholder { display: flex; align-items: center; justify-content: center; font-size: 20px; color: var(--sub); font-weight: bold; }
        .content { padding: 24px 20px; }
        .badge { display: inline-block; background: #EDE7F6; color: var(--primary); padding: 4px 12px; border-radius: 20px; font-size: 13px; font-weight: 600; margin-bottom: 12px; }
        h1 { font-size: 20px; margin: 0 0 8px; color: var(--text); }
        .meta { font-size: 14px; color: var(--sub); margin-bottom: 16px; }
        .btn { display: block; background: var(--primary); color: #FFF; text-decoration: none; padding: 14px 20px; border-radius: 10px; font-weight: 600; font-size: 16px; margin-top: 16px; }
    </style>
</head>
<body>
    <div class="card">
        $coverHtml
        <div class="content">
            $animeBadge
            <h1>${_escapeHtml(preview.title)}</h1>
            <div class="meta">${preview.dayCount} 天行程 · ${preview.stopCount} 個巡禮點 · 由 ${_escapeHtml(preview.authorName)} 分享</div>
            <a class="btn" href="${_escapeHtml(preview.appDeepLink)}">在 App 中開啟並複製行程</a>
        </div>
    </div>
</body>
</html>''';
  }

  /// Passes [preview] to the injected [ITemplateWebRenderer].
  Object render(TemplatePreviewInfo preview) => _renderer.renderPreview(preview);

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
