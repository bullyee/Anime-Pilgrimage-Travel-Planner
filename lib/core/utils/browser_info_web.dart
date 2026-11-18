import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// The browser's user agent; `null` outside the web.
String? get browserUserAgent => web.window.navigator.userAgent;

/// Whether the web app runs from the home screen rather than a browser tab:
/// `display-mode: standalone`, or Safari's own `navigator.standalone`.
bool get runsAsInstalledWebApp {
  if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  return web.window.navigator.getProperty<JSAny?>('standalone'.toJS).dartify() == true;
}

/// Opens [url] in this tab, such as an Android `intent://` link, which Chrome
/// hands to the app it names.
void openUrlInThisTab(String url) => web.window.location.href = url;
