import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/browser_info.dart';
import 'invite_links.dart';

/// Where the Android app is downloaded: each release carries its APK.
const apkReleasesUrl = 'https://github.com/bullyee/Anime-Pilgrimage-Travel-Planner/releases';

/// The Android app's package, which an `intent://` link names.
const androidAppPackage = 'com.example.trip_planner';

/// What the web join screen needs to know about the browser it runs in.
class WebJoinBrowser {
  /// An Android browser, where the installed app can open the invite.
  final bool android;

  /// An app's own browser (LINE, Instagram, Facebook…), where Google doesn't
  /// allow signing in.
  final bool inApp;

  const WebJoinBrowser({required this.android, required this.inApp});

  factory WebJoinBrowser.fromUserAgent(String userAgent, {bool installed = false}) => WebJoinBrowser(
        android: isAndroidUserAgent(userAgent),
        inApp: !installed && isInAppBrowserUserAgent(userAgent),
      );
}

bool isAndroidUserAgent(String userAgent) => userAgent.toLowerCase().contains('android');

final _inAppMarkers = RegExp(
  r'FBAN|FBAV|FB_IAB|Instagram|MicroMessenger|KAKAOTALK|Snapchat|musical_ly|BytedanceWebview|Twitter|; wv\)',
  caseSensitive: false,
);
final _line = RegExp(r'\bLine/');
final _iOS = RegExp(r'iPhone|iPad|iPod');

/// Whether [userAgent] is an app's own browser: one that names its app, an
/// Android WebView (`; wv)`), or an iOS web view, which leaves out the
/// `Safari/` that Safari, Chrome and Firefox on iOS all keep.
bool isInAppBrowserUserAgent(String userAgent) {
  if (_inAppMarkers.hasMatch(userAgent) || _line.hasMatch(userAgent)) return true;
  return _iOS.hasMatch(userAgent) && !userAgent.contains('Safari/');
}

/// The link that opens an invite in the Android app from a browser: Chrome
/// hands it to the app, or goes to the download page when it isn't installed.
String openInAppUrl(String token) {
  final link = Uri.parse(inviteLink(token));
  return 'intent://${link.host}${link.path}?${link.query}'
      '#Intent;scheme=https;package=$androidAppPackage;'
      'S.browser_fallback_url=${Uri.encodeComponent(apkReleasesUrl)};end';
}

/// The browser the web app runs in; `null` in the app itself.
final webJoinBrowserProvider = Provider<WebJoinBrowser?>((ref) {
  if (!kIsWeb) return null;
  final userAgent = browserUserAgent;
  if (userAgent == null) return null;
  return WebJoinBrowser.fromUserAgent(userAgent, installed: runsAsInstalledWebApp);
});
