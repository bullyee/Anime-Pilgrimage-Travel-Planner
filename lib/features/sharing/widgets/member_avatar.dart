import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// A person in a trip: their Google photo when there is one, over the first
/// letter of their name in a soft circle. The letter shows while the photo
/// loads, and stays when it can't load, such as offline.
class MemberAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const MemberAvatar({super.key, required this.name, this.avatarUrl, this.radius = 22});

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
    final url = avatarUrl?.trim();
    final photo = url == null || url.isEmpty ? null : NetworkImage(url);
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundImage: photo,
      // Without a handler a failed load is reported as an error; the letter
      // underneath is the fallback.
      onForegroundImageError: photo == null ? null : (_, _) {},
      child: Text(
        letter,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
      ),
    );
  }
}
