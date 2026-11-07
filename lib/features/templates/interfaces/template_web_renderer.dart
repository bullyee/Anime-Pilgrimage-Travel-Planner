import '../models/template_preview_info.dart';

/// Abstract contract for rendering template web previews and cards.
///
/// Implemented by UI layers or platform-specific presenters (e.g. Flutter Web,
/// HTML generation, or native embedder), maintaining a clean boundary between backend
/// resolution and frontend rendering.
abstract class ITemplateWebRenderer {
  /// Renders a representation of [preview] for display.
  Object renderPreview(TemplatePreviewInfo preview);
}

/// Fallback / Headless default renderer that formats a plain-text summary.
class DefaultTemplateWebRenderer implements ITemplateWebRenderer {
  const DefaultTemplateWebRenderer();

  @override
  String renderPreview(TemplatePreviewInfo preview) {
    final buffer = StringBuffer();
    buffer.writeln('${preview.title} (by ${preview.authorName})');
    buffer.writeln('${preview.dayCount} Days · ${preview.stopCount} Spots');
    if (preview.animeNames.isNotEmpty) {
      buffer.writeln('Featured Anime: ${preview.animeNames.join(', ')}');
    }
    if (preview.areas.isNotEmpty) {
      buffer.writeln('Pilgrimage Areas: ${preview.areas.join(', ')}');
    }
    buffer.writeln('Link: ${preview.webUrl}');
    return buffer.toString();
  }
}
