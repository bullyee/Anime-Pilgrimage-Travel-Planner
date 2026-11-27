import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

/// The longest trip note, in UTF-16 code units: Dart's `String.length`, and
/// what the Firestore rules' `size()` counts. The rules refuse a longer note,
/// and with it the rest of the trip's upload.
const maxTripNoteLength = 2000;

/// The longest note of a spot (a frame's `note`), counted the same way; the
/// rules refuse a longer one in `frameShots`.
const maxFrameNoteLength = 100;

/// [text] cut to at most [max] UTF-16 code units, without splitting a
/// surrogate pair.
String clampText(String text, int max) {
  if (text.length <= max) return text;
  var end = max;
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return text.substring(0, end).trimRight();
}

/// The longest group name, in characters. The Firestore rules refuse a
/// longer `stops.area`, and with it the rest of the trip's upload.
const maxGroupNameLength = 100;

/// The group [stop] is in, or null when it's in none. A group is the stops of
/// a trip that share the same `area`, and the group's name is that `area`,
/// trimmed: one café can come into a trip as several stops, one per scene,
/// and grouping keeps them together as one slot of the plan.
String? stopGroup(Stop stop) {
  final area = stop.area?.trim();
  return area == null || area.isEmpty ? null : area;
}

/// A name to offer for a group of stops named [names]: the start they share
/// ("莵道高校" for "莵道高校 正門" and "莵道高校 校外", "Cafe Rose" for its
/// scenes), else the first name. A shared start of one character, or one
/// that only cuts a word, isn't offered.
String suggestedGroupName(List<String> names) {
  final first = names.first.trim();
  if (names.length < 2) return first;
  var prefix = first;
  for (final n in names.skip(1)) {
    final name = n.trim();
    var i = 0;
    while (i < prefix.length && i < name.length && prefix.codeUnitAt(i) == name.codeUnitAt(i)) {
      i++;
    }
    prefix = prefix.substring(0, i);
  }
  final separator = RegExp(r'[\s,、・·\-–—/(（:：]');
  bool endsWord(String name) => name.trim().length == prefix.length || separator.hasMatch(name.trim()[prefix.length]);
  // The shared start ends a word in every name ("Uji Bridge" and "Uji Bridge,
  // west") or else is cut back to the last separator ("Cafe Rose 1" and
  // "Cafe Rose 2" share "Cafe Rose ").
  final whole = names.every(endsWord);
  final cut = prefix.lastIndexOf(separator);
  // With no separator to cut at, a Latin start is half a word ("Kamo" of
  // "Kamo river" and "Kamogawa"); Japanese has no spaces, so "京都" of
  // "京都タワー" and "京都駅" is fine.
  final halfWord = !whole && cut <= 0 && RegExp(r'[A-Za-z0-9]$').hasMatch(prefix);
  if (halfWord) return first;
  var name = whole ? prefix : (cut > 0 ? prefix.substring(0, cut) : prefix);
  name = name.replaceFirst(RegExp(r'[\s,、・·\-–—/(（:：]+$'), '').trim();
  return name.length >= 2 ? name : first;
}

/// "1 stop", "7 stops".
String stopCount(int n) => n == 1 ? '1 stop' : '$n stops';

final _spotSeparators = RegExp(r'^[\s,、・·\-–—/(（:：]+');

/// What a spot in [group] is called on its place's page: its note, else its
/// name without the group's name in front ("三の間" for "宇治橋 三の間" in
/// "宇治橋"), else its whole name. It's also the note a stop's frames take
/// when the stop becomes a spot of another (see [frameAsSpotOf]).
String spotLabel(Stop stop, String? group) {
  final note = stop.note?.trim();
  if (note != null && note.isNotEmpty) return clampText(note.split('\n').first.trim(), maxFrameNoteLength);
  final name = stop.name.trim();
  if (group != null && name.startsWith(group)) {
    final rest = name.substring(group.length).replaceFirst(_spotSeparators, '').trim();
    if (rest.isNotEmpty) return clampText(rest, maxFrameNoteLength);
  }
  return clampText(name, maxFrameNoteLength);
}

/// What [frame] of [stop] takes on when [stop] is merged into another stop
/// and becomes one of its spots: [stop]'s position unless the frame has one,
/// and [spotLabel] as its note unless it has one. Absent fields when the
/// frame already says both, so the write changes nothing.
NewReferenceImagesCompanion frameAsSpotOf(NewReferenceImage frame, Stop stop, String? group) {
  final placed = frame.lat != null && frame.lng != null;
  final noted = frame.note?.trim().isNotEmpty ?? false;
  return NewReferenceImagesCompanion(
    lat: placed ? const Value.absent() : Value(stop.lat),
    lng: placed ? const Value.absent() : Value(stop.lng),
    note: noted ? const Value.absent() : Value(spotLabel(stop, group)),
  );
}
