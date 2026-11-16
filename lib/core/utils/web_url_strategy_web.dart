import 'package:flutter_web_plugins/url_strategy.dart';

/// Enables path-based URLs (e.g. `/join/ABC123`) on Flutter Web so deep links
/// and Android App Links share identical paths without `#` fragments.
void configureWebUrlStrategy() {
  usePathUrlStrategy();
}
