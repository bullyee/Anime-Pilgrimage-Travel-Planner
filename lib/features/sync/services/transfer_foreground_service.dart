import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the ongoing transfer notification shows.
@immutable
class TransferNotification {
  final String jobId;
  final String title;
  final String text;
  final int done;
  final int total;
  final bool upload;

  const TransferNotification({
    required this.jobId,
    required this.title,
    required this.text,
    this.done = 0,
    this.total = 0,
    this.upload = true,
  });

  Map<String, Object?> toMap() => {
    'jobId': jobId,
    'title': title,
    'text': text,
    'done': done,
    'total': total,
    'upload': upload,
  };
}

/// The platform side of background frame transfers: on Android a foreground
/// service (`TransferService.kt`) that keeps the process alive and shows the
/// progress with a Cancel action. Elsewhere it does nothing and the
/// transfers just run while the app does.
abstract class TransferForegroundService {
  /// Raises the process to foreground priority and shows [n]. Returns false
  /// when the platform refused (e.g. started from the background); the
  /// transfer runs anyway.
  Future<bool> start(TransferNotification n);

  Future<void> update(TransferNotification n);

  /// Lowers the priority again. With a [title], leaves a dismissible
  /// notification saying what happened (or that the app needs the user).
  Future<void> stop({String? title, String? text});

  /// Removes the notification [stop] left behind.
  Future<void> clearDone();

  /// Android 13+: asks to show notifications, if not granted yet.
  Future<void> requestNotificationPermission();

  /// Whether the active network is unmetered; false when unknown.
  Future<bool> isUnmeteredNetwork();

  /// Called when the user taps Cancel on the notification.
  set onCancel(VoidCallback? callback);
}

/// No foreground service: desktop, web, iOS, and tests.
class NoopTransferForegroundService implements TransferForegroundService {
  const NoopTransferForegroundService();

  @override
  Future<bool> start(TransferNotification n) async => false;

  @override
  Future<void> update(TransferNotification n) async {}

  @override
  Future<void> stop({String? title, String? text}) async {}

  @override
  Future<void> clearDone() async {}

  @override
  Future<void> requestNotificationPermission() async {}

  /// Unknown, so automatic downloads simply queue (desktop/iOS are not
  /// metered-aware here).
  @override
  Future<bool> isUnmeteredNetwork() async => true;

  @override
  set onCancel(VoidCallback? callback) {}
}

/// Android: the `trip_planner/transfers` channel to `TransferBridge.kt`.
class MethodChannelTransferForegroundService implements TransferForegroundService {
  static const channelName = 'trip_planner/transfers';

  final MethodChannel _channel;
  VoidCallback? _onCancel;

  MethodChannelTransferForegroundService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'cancel') _onCancel?.call();
      return null;
    });
  }

  @override
  set onCancel(VoidCallback? callback) => _onCancel = callback;

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('[TransferForegroundService] $method failed: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> start(TransferNotification n) async => await _call<bool>('start', n.toMap()) ?? false;

  @override
  Future<void> update(TransferNotification n) => _call<void>('update', n.toMap());

  @override
  Future<void> stop({String? title, String? text}) => _call<void>('stop', {'title': title, 'text': text});

  @override
  Future<void> clearDone() => _call<void>('clearDone');

  @override
  Future<void> requestNotificationPermission() => _call<bool>('requestNotificationPermission');

  @override
  Future<bool> isUnmeteredNetwork() async => await _call<bool>('isUnmeteredNetwork') ?? false;
}

final transferForegroundServiceProvider = Provider<TransferForegroundService>((ref) {
  if (!kIsWeb && Platform.isAndroid) return MethodChannelTransferForegroundService();
  return const NoopTransferForegroundService();
});

/// Whether the app is on screen. A transfer that needs the user (Google
/// sign-in) pauses instead of prompting while it isn't.
final appVisibleProvider = Provider<bool Function()>((ref) {
  return () {
    final state = WidgetsBinding.instance.lifecycleState;
    // Null before the first lifecycle event: the app is starting in front.
    return state == null || state == AppLifecycleState.resumed;
  };
});
