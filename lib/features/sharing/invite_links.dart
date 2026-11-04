import 'package:intl/intl.dart';

import 'models/trip_invite.dart';

/// The hosts whose `/join` links open the app (see the App Link intent filter
/// in `AndroidManifest.xml`). The web page there, `public/index.html`, shows
/// the code to people who don't have the app yet.
const inviteLinkHosts = {'trip-planner-2775c.web.app', 'trip-planner-2775c.firebaseapp.com'};

/// The link an invite is shared as. It carries the invite's long token rather
/// than its 6-letter code, which is short enough to guess. The code is only
/// for typing in.
String inviteLink(String token) => Uri.https(inviteLinkHosts.first, '/join', {'token': token}).toString();

/// The message "Share invite" sends: the link, plus the code for typing in.
String inviteShareText(TripInvite invite) {
  return 'Join “${invite.tripTitle}” in Trip Planner: ${inviteLink(invite.token)}\n'
      'Or enter the code ${formatShortCode(invite.shortCode)} in the app. '
      'It works until ${DateFormat.MMMd().format(invite.expiresAt)}.';
}

/// "K7M Q2P": a short code split in half, so it's easier to read out.
String formatShortCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

final _shortCode = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');
final _token = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
final _link = RegExp(r'https?://[^\s<>"“”]+');

/// Whether [code] is a whole short code, in the alphabet
/// `GroupSharingService.generateShortCode` uses (no 0, O, 1 or I).
bool isShortCode(String code) => _shortCode.hasMatch(code);

/// The invite a link's query names, as `/join?token=` or `/join?code=`
/// (the web page's "open in the app" button sends both). The token wins.
String? inviteFromQuery(Map<String, String> query) {
  final token = query['token']?.trim();
  if (token != null && _token.hasMatch(token)) return token;
  final code = query['code']?.trim().toUpperCase();
  if (code != null && isShortCode(code)) return code;
  return null;
}

/// The invite in some pasted text: the token or code of an invite link in it,
/// or a bare code ("k7m q2p" works too). Null when there's none.
String? inviteFromText(String text) {
  for (final match in _link.allMatches(text)) {
    // A link at the end of a sentence keeps the sentence's full stop.
    final uri = Uri.tryParse(match.group(0)!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), ''));
    if (uri == null || !inviteLinkHosts.contains(uri.host)) continue;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.first != 'join') continue;
    final fromQuery = inviteFromQuery(uri.queryParameters);
    if (fromQuery != null) return fromQuery;
    // `/join/K7MQ2P` or `/join/<token>`, which the web page also understands.
    if (segments.length > 1) return inviteFromQuery({'token': segments[1], 'code': segments[1]});
  }
  final bare = text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (isShortCode(bare)) return bare;
  final trimmed = text.trim();
  return _token.hasMatch(trimmed) ? trimmed : null;
}
