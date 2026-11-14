import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trip_planner/core/utils/archive_isolate.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';

/// A Drive whose uploads never answer until they are aborted, except the
/// ones [answer] lets through.
class _SlowDrive extends http.BaseClient {
  int uploads = 0;
  int aborted = 0;

  /// Which upload attempts (1-based) get an answer.
  final Set<int> answer;
  _SlowDrive({this.answer = const {}});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    http.StreamedResponse json(Object body) =>
        http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200, request: request);
    if (request.method == 'GET') {
      return json({
        'files': [
          {'id': 'folder'}
        ]
      });
    }
    final n = ++uploads;
    if (answer.contains(n)) {
      return json({
        'id': 'file_$n',
        'permissions': [
          {'type': 'anyone', 'role': 'reader'}
        ]
      });
    }
    final trigger = request is http.Abortable ? (request as http.Abortable).abortTrigger : null;
    if (trigger == null) return Completer<http.StreamedResponse>().future; // hangs for good
    await trigger;
    aborted++;
    throw http.RequestAbortedException(request.url);
  }
}

void main() {
  final frame = Uint8List.fromList(List.filled(1000, 7));

  test('cancel stops an upload in flight at once', () async {
    final drive = _SlowDrive();
    final svc = GoogleDriveFrameService(
      client: drive,
      getToken: ({bool interactive = true}) async => 't',
      compress: (b) async => b,
    );
    final cancel = BackupCancel();
    final upload = svc.uploadImageBytes(rawBytes: frame, frameId: 'a', cancel: cancel);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(drive.uploads, 1);
    cancel.cancel();
    await expectLater(upload.timeout(const Duration(seconds: 2)), throwsA(isA<BackupCancelled>()));
    expect(drive.aborted, 1, reason: 'the request itself was aborted');
    expect(drive.uploads, 1, reason: 'no retry after cancel');
  });

  test('an upload that runs out of time is aborted, then tried again', () async {
    final drive = _SlowDrive(answer: {2});
    final svc = GoogleDriveFrameService(
      client: drive,
      getToken: ({bool interactive = true}) async => 't',
      compress: (b) async => b,
      uploadTimeout: (_) => const Duration(milliseconds: 100),
      retryDelays: const [Duration.zero],
    );
    final res = await svc.uploadImageBytes(rawBytes: frame, frameId: 'a').timeout(const Duration(seconds: 2));
    expect(res.fileId, 'file_2');
    expect(drive.aborted, 1, reason: "the first attempt doesn't keep sending next to the retry");
  });

  test('the time limit grows with the size of the frame', () {
    expect(GoogleDriveFrameService.uploadTimeoutFor(0), const Duration(seconds: 30));
    expect(GoogleDriveFrameService.uploadTimeoutFor(300000), const Duration(seconds: 48));
    expect(GoogleDriveFrameService.uploadTimeoutFor(3000000).inSeconds, greaterThan(200));
  });

  test('a silent token request that never answers gives up instead of hanging', () async {
    final svc = GoogleDriveFrameService(
      client: _SlowDrive(answer: {1}),
      getToken: ({bool interactive = true}) => Completer<String>().future,
      compress: (b) async => b,
      silentTokenTimeout: const Duration(milliseconds: 100),
    );
    // Non-interactive uploads wrap the failure as "Google needs the user".
    await expectLater(
      svc.uploadImageBytes(rawBytes: frame, frameId: 'a', interactive: false),
      throwsA(isA<DriveAuthRequiredException>()),
    );
  });
}
