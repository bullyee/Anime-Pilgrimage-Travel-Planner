import 'package:flutter/foundation.dart';
import 'package:trip_planner/features/sync/services/transfer_foreground_service.dart';

/// Records what the queue asks of the platform.
class FakeTransferService implements TransferForegroundService {
  final calls = <String>[];
  final updates = <TransferNotification>[];
  ({String? title, String? text})? lastStop;
  VoidCallback? cancelCallback;
  var unmetered = true;

  @override
  Future<bool> start(TransferNotification n) async {
    calls.add('start ${n.title} · ${n.text}');
    return true;
  }

  @override
  Future<void> update(TransferNotification n) async {
    calls.add('update');
    updates.add(n);
  }

  @override
  Future<void> stop({String? title, String? text}) async {
    calls.add('stop');
    lastStop = (title: title, text: text);
  }

  @override
  Future<void> clearDone() async {}

  @override
  Future<void> requestNotificationPermission() async => calls.add('permission');

  @override
  Future<bool> isUnmeteredNetwork() async => unmetered;

  @override
  set onCancel(VoidCallback? callback) => cancelCallback = callback;

  /// The user taps Cancel on the notification.
  void tapNotificationCancel() => cancelCallback?.call();
}
