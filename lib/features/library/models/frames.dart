import '../../../core/database/database.dart';

/// "Ep 3 · 12:34", from what is known of a frame, or null.
String? frameCaption(NewReferenceImage f) {
  final parts = <String>[
    if (f.episode?.trim().isNotEmpty ?? false) 'Ep ${f.episode!.trim()}',
    if (f.timestampS != null) '${f.timestampS! ~/ 60}:${(f.timestampS! % 60).toString().padLeft(2, '0')}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
