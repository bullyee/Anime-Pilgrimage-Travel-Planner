/// The browser's user agent; `null` outside the web.
String? get browserUserAgent => null;

/// Whether the web app runs from the home screen rather than a browser tab.
bool get runsAsInstalledWebApp => false;

/// Opens [url] in this tab, such as an Android `intent://` link. Only the web
/// does anything.
void openUrlInThisTab(String url) {}
