import '../../../core/database/database.dart';

/// Maximum UTF-16 code-unit length accepted for external frame image links.
const maxFrameUrlLength = 2000;

/// Whether [f] lives only as a local file on this device (no `remoteUrl`).
bool isLocalOnlyFrame(NewReferenceImage f) =>
    (f.localPath?.trim().isNotEmpty ?? false) && (f.remoteUrl?.trim().isEmpty ?? true);

/// Validates an external HTTP/HTTPS image URL entered for a reference frame.
({String? url, String? error}) validateFrameImageUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return (url: null, error: 'Enter an image link.');
  }
  if (trimmed.length > maxFrameUrlLength) {
    return (url: null, error: 'Image link must be at most $maxFrameUrlLength characters.');
  }
  if (RegExp(r'\s').hasMatch(trimmed)) {
    return (url: null, error: 'Image link cannot contain spaces.');
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return (url: null, error: 'Enter a valid http:// or https:// image link.');
  }
  return (url: trimmed, error: null);
}

/// "Ep 3 · 12:34", from what is known of a frame, or null.
String? frameCaption(NewReferenceImage f) {
  final parts = <String>[
    if (f.episode?.trim().isNotEmpty ?? false) 'Ep ${f.episode!.trim()}',
    if (f.timestampS != null) '${f.timestampS! ~/ 60}:${(f.timestampS! % 60).toString().padLeft(2, '0')}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
