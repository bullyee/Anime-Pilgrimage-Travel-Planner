import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// A person in a trip, as the first letter of their name in a soft circle.
/// Photos come with avatars on the trip cards, in a later round.
class MemberAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const MemberAvatar({super.key, required this.name, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).trip;
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
    // The same name always gets the same one of the three colors.
    final (background, foreground) = switch (trimmed.codeUnits.fold(0, (sum, unit) => sum + unit) % 3) {
      0 => (p.teaSoft, p.tea),
      1 => (p.wisteriaSoft, p.wisteria),
      _ => (p.vermilionSoft, p.vermilion),
    };
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        letter,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
      ),
    );
  }
}
