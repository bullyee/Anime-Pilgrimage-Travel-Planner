import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_planner/core/utils/app_logger.dart';

/// Service wrapping Firebase Analytics for anonymous usage and activity metrics.
/// Disables ad tracking / personalization to strictly comply with CC BY-NC-SA terms.
class AnalyticsService {
  final FirebaseAnalytics? _overrideAnalytics;

  AnalyticsService({FirebaseAnalytics? analytics}) : _overrideAnalytics = analytics;

  FirebaseAnalytics? get _analytics {
    if (_overrideAnalytics != null) return _overrideAnalytics;
    try {
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        return FirebaseAnalytics.instance;
      }
    } catch (_) {
      // Firebase not initialized (e.g. unit tests or local-only mode)
    }
    return null;
  }

  /// Log application open event.
  Future<void> logAppOpen() async {
    try {
      await _analytics?.logAppOpen();
    } catch (e, st) {
      AppLogger.error('Analytics logAppOpen failed', error: e, stackTrace: st, name: 'AnalyticsService');
    }
  }

  /// Log screen view event for tracking navigation usage.
  Future<void> logScreenView({required String screenName, String? screenClass}) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e, st) {
      AppLogger.error('Analytics logScreenView failed', error: e, stackTrace: st, name: 'AnalyticsService');
    }
  }

  /// Log custom non-sensitive event.
  Future<void> logEvent({required String name, Map<String, Object>? parameters}) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      AppLogger.error('Analytics logEvent failed', error: e, stackTrace: st, name: 'AnalyticsService');
    }
  }

  /// Sets whether analytics collection is enabled (can be toggled by user in settings).
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics?.setAnalyticsCollectionEnabled(enabled);
    } catch (e, st) {
      AppLogger.error('Analytics setAnalyticsCollectionEnabled failed', error: e, stackTrace: st, name: 'AnalyticsService');
    }
  }
}

/// Provider for [AnalyticsService].
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
