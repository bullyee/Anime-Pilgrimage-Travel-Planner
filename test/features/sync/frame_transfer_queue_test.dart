import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/utils/archive_isolate.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_queue.dart';
import 'package:trip_planner/features/sync/services/transfer_foreground_service.dart';

import 'fake_transfer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransferService service;
  late InMemoryTransferJournal journal;
  late ProviderContainer container;
  var visible = true;

  setUp(() {
    service = FakeTransferService();
    journal = InMemoryTransferJournal();
    visible = true;
    container = ProviderContainer(overrides: [
      transferForegroundServiceProvider.overrideWithValue(service),
      transferJournalProvider.overrideWithValue(journal),
      appVisibleProvider.overrideWithValue(() => visible),
    ]);
  });

  tearDown(() => container.dispose());

  FrameTransferQueue queue() => container.read(frameTransferQueueProvider.notifier);
  FrameTransferState state() => container.read(frameTransferQueueProvider);

  TransferJobSpec job(
    String tripId, {
    TransferKind kind = TransferKind.download,
    required Future<String> Function(TransferContext ctx) run,
    bool journaled = false,
    bool quiet = false,
  }) =>
      TransferJobSpec(
        kind: kind,
        tripId: tripId,
        tripTitle: 'Trip $tripId',
        run: run,
        journaled: journaled,
        quiet: quiet,
      );

  test('runs jobs one at a time, in order, and drives the service: start once, stop when idle', () async {
    final order = <String>[];
    final gateA = Completer<void>();
    var bStartedWhileARunning = false;

    queue().enqueue(job('a', run: (ctx) async {
      order.add('a start');
      ctx.progress(1, 2);
      await gateA.future;
      ctx.progress(2, 2);
      order.add('a end');
      return 'A done';
    }));
    queue().enqueue(job('b', kind: TransferKind.driveUpload, run: (ctx) async {
      order.add('b start');
      bStartedWhileARunning = !gateA.isCompleted;
      return 'B done';
    }));

    await pumpEventQueue();
    expect(state().current?.tripId, 'a');
    expect(state().current?.done, 1);
    expect(state().current?.total, 2);
    expect(state().queued.map((q) => q.tripId), ['b']);

    gateA.complete();
    await queue().whenIdle();

    expect(order, ['a start', 'a end', 'b start']);
    expect(bStartedWhileARunning, isFalse);
    expect(state().isBusy, isFalse);
    expect(state().notices.map((n) => n.message), ['A done', 'B done']);
    expect(service.calls.where((c) => c.startsWith('start')), hasLength(1));
    expect(service.calls.first, 'permission', reason: 'asks for notifications at the first transfer');
    expect(service.calls.last, 'stop');
    expect(service.calls.where((c) => c == 'stop'), hasLength(1));
    // The second job's headline reached the notification.
    expect(service.updates.any((u) => u.title == 'Uploading frames to Google Drive' && u.text.contains('Trip b')), isTrue);
  });

  test('a second job of the same kind for the same trip joins the first', () async {
    final gate = Completer<void>();
    var runs = 0;
    Future<String> run(TransferContext ctx) async {
      runs++;
      await gate.future;
      return 'ok';
    }

    final id1 = queue().enqueue(job('a', run: run));
    final id2 = queue().enqueue(job('a', run: run));
    final other = queue().enqueue(job('a', kind: TransferKind.driveUpload, run: (_) async => 'up'));
    expect(id2, id1);
    expect(other, isNot(id1));
    gate.complete();
    await queue().whenIdle();
    expect(runs, 1);
  });

  test("the notification's Cancel stops the running job; the next one still runs", () async {
    var uploaded = 0;
    queue().enqueue(job('a', kind: TransferKind.driveUpload, journaled: true, run: (ctx) async {
      for (var i = 0; i < 100; i++) {
        if (ctx.cancel.isCancelled) throw const BackupCancelled();
        uploaded++;
        ctx.progress(uploaded, 100);
        if (uploaded == 3) service.tapNotificationCancel();
        await Future<void>.delayed(Duration.zero);
      }
      return 'all';
    }));
    var bRan = false;
    queue().enqueue(job('b', run: (_) async {
      bRan = true;
      return 'b';
    }));
    await queue().whenIdle();

    expect(uploaded, lessThan(10));
    expect(bRan, isTrue);
    final a = state().notices.firstWhere((n) => n.tripId == 'a');
    expect(a.type, TransferNoticeType.cancelled);
    expect(a.message, 'Upload cancelled.');
    expect(await journal.read(), isEmpty, reason: 'a cancelled run is not offered again');
  });

  test('cancelling a queued job drops it before it runs', () async {
    final gate = Completer<void>();
    queue().enqueue(job('a', run: (_) async {
      await gate.future;
      return 'a';
    }));
    var bRan = false;
    final b = queue().enqueue(job('b', run: (_) async {
      bRan = true;
      return 'b';
    }));
    await pumpEventQueue();
    queue().cancel(b);
    expect(state().queued, isEmpty);
    gate.complete();
    await queue().whenIdle();
    expect(bRan, isFalse);
  });

  test('a failure shows its real cause and stays resumable in the journal', () async {
    queue().enqueue(job('a', kind: TransferKind.driveUpload, journaled: true, run: (_) async {
      throw Exception('ClientException: Software caused connection abort');
    }));
    expect(await journal.read(), hasLength(1));
    await queue().whenIdle();
    final n = state().notices.single;
    expect(n.type, TransferNoticeType.failed);
    expect(n.isError, isTrue);
    expect(n.message, 'Upload stopped: ClientException: Software caused connection abort');
    expect(await journal.read(), hasLength(1));

    queue().dismissNotice(n.id);
    expect(state().notices, isEmpty);
  });

  test('a successful run leaves the journal', () async {
    queue().enqueue(job('a', kind: TransferKind.driveUpload, journaled: true, run: (_) async => 'done'));
    await queue().whenIdle();
    expect(await journal.read(), isEmpty);
  });

  test('a job needing the user while the app is hidden pauses with "Open Trip Planner to continue"', () async {
    visible = false;
    queue().enqueue(job('a', kind: TransferKind.driveUpload, journaled: true, run: (ctx) async {
      expect(ctx.isAppVisible(), isFalse);
      throw const TransferNeedsUserException('Sign in again.');
    }));
    await queue().whenIdle();
    final n = state().notices.single;
    expect(n.type, TransferNoticeType.needsUser);
    expect(n.offersResume, isTrue);
    expect(service.lastStop?.title, 'Open Trip Planner to continue');
    expect(service.lastStop?.text, 'Sign in again.');
    expect(await journal.read(), hasLength(1));
  });

  test('finishing in the background leaves a notification; on screen it does not', () async {
    visible = false;
    queue().enqueue(job('a', kind: TransferKind.driveUpload, run: (_) async => 'Uploaded 405 frames.'));
    await queue().whenIdle();
    expect(service.lastStop, (title: 'Frames uploaded', text: 'Uploaded 405 frames.'));

    visible = true;
    queue().enqueue(job('b', run: (_) async => 'Downloaded 3 frames.'));
    await queue().whenIdle();
    expect(service.lastStop, (title: null, text: null));
  });

  test('quiet jobs leave no notice', () async {
    queue().enqueue(job('a', quiet: true, run: (_) async => 'auto'));
    await queue().whenIdle();
    expect(state().notices, isEmpty);
  });

  test('notification updates are throttled while the in-app progress follows every frame', () async {
    final seen = <int>[];
    final sub = container.listen(frameTransferQueueProvider, (_, next) {
      final d = next.current?.done;
      if (d != null) seen.add(d);
    });
    queue().enqueue(job('a', run: (ctx) async {
      for (var i = 1; i <= 200; i++) {
        ctx.progress(i, 200);
      }
      return 'ok';
    }));
    await queue().whenIdle();
    sub.close();
    expect(seen.toSet().length, greaterThanOrEqualTo(200));
    expect(service.updates.length, lessThan(10));
    expect(service.updates.last.done, 200, reason: 'the last frame always reaches the notification');
  });

  test('addNotice replaces the same trip and kind; a new run clears its old notice', () async {
    queue().addNotice(
      kind: TransferKind.driveUpload,
      tripId: 'a',
      tripTitle: 'A',
      type: TransferNoticeType.resumable,
      message: '12 frames left to upload to Google Drive.',
    );
    queue().addNotice(
      kind: TransferKind.driveUpload,
      tripId: 'a',
      tripTitle: 'A',
      type: TransferNoticeType.resumable,
      message: '10 frames left to upload to Google Drive.',
    );
    expect(state().notices.single.message, '10 frames left to upload to Google Drive.');
    final gate = Completer<void>();
    queue().enqueue(job('a', kind: TransferKind.driveUpload, run: (_) async {
      await gate.future;
      return 'done';
    }));
    expect(state().notices, isEmpty);
    gate.complete();
    await queue().whenIdle();
  });

  test('FileTransferJournal survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('journal_test_');
    addTearDown(() => dir.delete(recursive: true));
    final first = FileTransferJournal(dir: () async => dir);
    const entry = TransferJournalEntry(kind: TransferKind.driveUpload, tripId: 't1', tripTitle: 'Kansai');
    await first.add(entry);
    await first.add(const TransferJournalEntry(kind: TransferKind.download, tripId: 't1', tripTitle: 'Kansai'));
    final second = FileTransferJournal(dir: () async => dir);
    expect(await second.read(), hasLength(2));
    await second.remove(entry);
    expect((await FileTransferJournal(dir: () async => dir).read()).single.kind, TransferKind.download);
  });

  test('MethodChannelTransferForegroundService talks to trip_planner/transfers and hears Cancel', () async {
    const channel = MethodChannel(MethodChannelTransferForegroundService.channelName);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'start' || call.method == 'isUnmeteredNetwork' ? true : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final svc = MethodChannelTransferForegroundService();
    var cancelled = false;
    svc.onCancel = () => cancelled = true;
    expect(
      await svc.start(const TransferNotification(jobId: 'j', title: 'Uploading', text: '1 of 2', done: 1, total: 2)),
      isTrue,
    );
    await svc.stop(title: 'Done', text: 'ok');
    expect(await svc.isUnmeteredNetwork(), isTrue);
    expect(calls.map((c) => c.method), ['start', 'stop', 'isUnmeteredNetwork']);
    expect((calls.first.arguments as Map)['total'], 2);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('cancel')),
      (_) {},
    );
    expect(cancelled, isTrue);
  });
}
