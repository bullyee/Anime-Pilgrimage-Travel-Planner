import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/sharing/invite_links.dart';
import 'package:trip_planner/features/sharing/models/trip_invite.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';

void main() {
  const token = '8f3c41d2-5b6e-4a7f-9c0d-1e2f3a4b5c6d';

  test('an invite link carries the token, not the code', () {
    expect(inviteLink(token), 'https://trip-planner-2775c.web.app/join?token=$token');
  });

  test('a short code is shown in two halves', () {
    expect(formatShortCode('K7MQ2P'), 'K7M Q2P');
    expect(formatShortCode('K7M'), 'K7M');
  });

  test('short codes use the alphabet without 0, O, 1 and I', () {
    expect(isShortCode('K7MQ2P'), isTrue);
    expect(isShortCode('K7MQ2O'), isFalse);
    expect(isShortCode('K7MQ21'), isFalse);
    expect(isShortCode('k7mq2p'), isFalse);
    expect(isShortCode('K7MQ2'), isFalse);
  });

  group('a link query', () {
    test('prefers the token', () {
      expect(inviteFromQuery({'token': token, 'code': 'K7MQ2P'}), token);
    });

    test('falls back to the code, upper-cased', () {
      expect(inviteFromQuery({'code': 'k7mq2p'}), 'K7MQ2P');
    });

    test('ignores what is neither', () {
      expect(inviteFromQuery({'token': 'nope', 'code': 'TOOLONG'}), isNull);
      expect(inviteFromQuery({}), isNull);
    });
  });

  group('pasted text', () {
    test('finds the token in the shared message', () {
      final invite = TripInvite(
        token: token,
        shortCode: 'K7MQ2P',
        tripId: 't1',
        role: TripMemberRole.editor,
        createdBy: 'u1',
        inviterName: 'Bea',
        tripTitle: 'Uji day trip',
        stopCount: 3,
        createdAt: DateTime(2026, 11, 3),
        expiresAt: DateTime(2026, 11, 10),
      );
      final text = inviteShareText(invite);
      expect(text, contains('K7M Q2P'));
      expect(inviteFromText(text), token);
    });

    test('reads a link at the end of a sentence', () {
      expect(inviteFromText('Join here: https://trip-planner-2775c.web.app/join?token=$token.'), token);
    });

    test('reads codes in the path and from the other host', () {
      expect(inviteFromText('https://trip-planner-2775c.firebaseapp.com/join/K7MQ2P'), 'K7MQ2P');
      expect(inviteFromText('https://trip-planner-2775c.web.app/join/$token'), token);
      expect(inviteFromText('https://trip-planner-2775c.web.app/join?code=k7mq2p'), 'K7MQ2P');
    });

    test('takes a bare code with spaces or in lower case', () {
      expect(inviteFromText('k7m q2p'), 'K7MQ2P');
      expect(inviteFromText(' K7M-Q2P '), 'K7MQ2P');
      expect(inviteFromText(token), token);
    });

    test("ignores other sites' links and other text", () {
      expect(inviteFromText('https://example.com/join?token=$token'), isNull);
      expect(inviteFromText('https://trip-planner-2775c.web.app/library'), isNull);
      expect(inviteFromText('see you tomorrow'), isNull);
      expect(inviteFromText(''), isNull);
    });
  });
}
