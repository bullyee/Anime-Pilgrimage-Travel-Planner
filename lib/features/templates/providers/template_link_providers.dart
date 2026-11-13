import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/template_preview_info.dart';
import '../services/template_link_resolver_service.dart';

/// Provider for the singleton/shared [TemplateLinkResolverService].
final templateLinkResolverServiceProvider =
    Provider<TemplateLinkResolverService>((ref) {
  return TemplateLinkResolverService();
});

/// Reactive family provider that resolves any template URL, deep link, or short code.
final templatePreviewQueryProvider =
    FutureProvider.autoDispose.family<TemplatePreviewInfo?, String>(
        (ref, input) async {
  if (input.trim().isEmpty) return null;
  final service = ref.watch(templateLinkResolverServiceProvider);
  return service.resolveTemplate(input);
});
