import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/core/utils/platform_media.dart';

void main() {
  test('isRemoteOrMemoryUri classifies network, blob, data, and file paths', () {
    expect(isRemoteOrMemoryUri('https://example.com/a.jpg'), isTrue);
    expect(isRemoteOrMemoryUri('HTTP://example.com/a.jpg'), isTrue);
    expect(isRemoteOrMemoryUri('blob:https://app.example/1234'), isTrue);
    expect(isRemoteOrMemoryUri('data:image/png;base64,iVBORw0='), isTrue);
    expect(isRemoteOrMemoryUri('/data/user/0/app/photo.jpg'), isFalse);
    expect(isRemoteOrMemoryUri(r'C:\Users\test\photo.jpg'), isFalse);
  });

  test('encodeDataUrl and readMediaBytes round-trip bytes', () async {
    final original = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
    final uri = encodeDataUrl(original);
    expect(uri, startsWith('data:image/jpeg;base64,'));
    expect(await readMediaBytes(uri), orderedEquals(original));
  });

  test('readMediaBytes reads local files and HTTP responses and rejects non-200', () async {
    final tmp = await Directory.systemTemp.createTemp('platform_media_test');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File('${tmp.path}/sample.jpg')..writeAsBytesSync([9, 8, 7]);
    expect(await readMediaBytes(file.path), orderedEquals([9, 8, 7]));

    final okClient = MockClient((_) async => http.Response.bytes([4, 5, 6], 200));
    expect(
      await readMediaBytes('https://example.com/img.jpg', client: okClient),
      orderedEquals([4, 5, 6]),
    );

    final errClient = MockClient((_) async => http.Response('forbidden', 403));
    await expectLater(
      readMediaBytes('https://example.com/img.jpg', client: errClient),
      throwsStateError,
    );
  });

  test('mediaExists handles null, empty, URIs, and missing files', () async {
    final tmp = await Directory.systemTemp.createTemp('platform_media_exists');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File('${tmp.path}/present.jpg')..writeAsBytesSync([1]);

    expect(await mediaExists(null), isFalse);
    expect(await mediaExists(''), isFalse);
    expect(await mediaExists('https://example.com/frame.jpg'), isTrue);
    expect(await mediaExists('blob:https://example.com/uuid'), isTrue);
    expect(await mediaExists('data:image/jpeg;base64,AQ=='), isTrue);
    expect(await mediaExists(file.path), isTrue);
    expect(await mediaExists('${tmp.path}/missing.jpg'), isFalse);
  });

  testWidgets('PlatformImage renders valid data URI and calls errorBuilder on malformed data URI', (tester) async {
    // Minimal 1x1 transparent PNG.
    const png1x1 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    await tester.pumpWidget(
      const MaterialApp(
        home: PlatformImage(png1x1, cacheWidth: 64),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformImage(
          'data:image/jpeg;base64,!!!invalid-base64!!!',
          errorBuilder: (_, _, _) => const Text('fallback'),
        ),
      ),
    );
    expect(find.text('fallback'), findsOneWidget);
  });
}
