import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/sharing/web_join_help.dart';

const _androidChrome =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';
const _androidWebView =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/130.0.0.0 Mobile Safari/537.36';
const _androidLine =
    'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36 Line/14.19.1';
const _iPhoneSafari =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1';
const _iPhoneChrome =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/130.0.6723.90 Mobile/15E148 Safari/604.1';
const _iPhoneInstagram =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 357.0.0.25.101';
const _iPhoneWebView =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
const _desktopChrome =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

void main() {
  group('the browser', () {
    test('Android browsers are Android; others are not', () {
      expect(isAndroidUserAgent(_androidChrome), isTrue);
      expect(isAndroidUserAgent(_androidLine), isTrue);
      expect(isAndroidUserAgent(_iPhoneSafari), isFalse);
      expect(isAndroidUserAgent(_desktopChrome), isFalse);
    });

    test("an app's own browser is told apart from a real one", () {
      expect(isInAppBrowserUserAgent(_androidWebView), isTrue);
      expect(isInAppBrowserUserAgent(_androidLine), isTrue);
      expect(isInAppBrowserUserAgent(_iPhoneInstagram), isTrue);
      expect(isInAppBrowserUserAgent(_iPhoneWebView), isTrue);

      expect(isInAppBrowserUserAgent(_androidChrome), isFalse);
      expect(isInAppBrowserUserAgent(_iPhoneSafari), isFalse);
      expect(isInAppBrowserUserAgent(_iPhoneChrome), isFalse);
      expect(isInAppBrowserUserAgent(_desktopChrome), isFalse);
    });

    test('the web app on the home screen is not an app browser, though iOS leaves out Safari/', () {
      expect(WebJoinBrowser.fromUserAgent(_iPhoneWebView).inApp, isTrue);
      expect(WebJoinBrowser.fromUserAgent(_iPhoneWebView, installed: true).inApp, isFalse);
    });
  });

  test('"Open in the app" names the app and falls back to its download page', () {
    const token = '0f8fad5b-d9cb-469f-a165-70867728950e';
    final url = openInAppUrl(token);

    expect(url, startsWith('intent://trip-planner-2775c.web.app/join?token=$token#Intent;'));
    expect(url, contains('scheme=https;'));
    expect(url, contains('package=com.example.trip_planner;'));
    expect(url, contains('S.browser_fallback_url=${Uri.encodeComponent(apkReleasesUrl)};'));
    expect(url, endsWith(';end'));
  });
}
