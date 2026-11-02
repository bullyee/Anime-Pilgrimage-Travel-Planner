import 'package:flutter/material.dart';

class AppTheme {
  /// The tea green of the trip planner design.
  static const _seed = Color(0xFF2C6A51);

  static ThemeData get light => _theme(Brightness.light, TripPalette.light);

  static ThemeData get dark => _theme(Brightness.dark, TripPalette.dark);

  static ThemeData _theme(Brightness brightness, TripPalette palette) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
      extensions: [palette],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }
}

/// The accent colors of the trip planner design: tea for actions, today and
/// progress; wisteria for people and what's coming up; vermilion for pinned
/// dates and conflicts. Each has a soft tint for backgrounds.
@immutable
class TripPalette extends ThemeExtension<TripPalette> {
  final Color tea;
  final Color teaSoft;
  final Color wisteria;
  final Color wisteriaSoft;
  final Color vermilion;
  final Color vermilionSoft;

  const TripPalette({
    required this.tea,
    required this.teaSoft,
    required this.wisteria,
    required this.wisteriaSoft,
    required this.vermilion,
    required this.vermilionSoft,
  });

  static const light = TripPalette(
    tea: Color(0xFF2C6A51),
    teaSoft: Color(0xFFDAE9E1),
    wisteria: Color(0xFF6956B4),
    wisteriaSoft: Color(0xFFEBE7F8),
    vermilion: Color(0xFFC0402A),
    vermilionSoft: Color(0xFFF7DFD9),
  );

  static const dark = TripPalette(
    tea: Color(0xFF73C6A0),
    teaSoft: Color(0xFF1C392D),
    wisteria: Color(0xFFAB9CF2),
    wisteriaSoft: Color(0xFF252042),
    vermilion: Color(0xFFF1816A),
    vermilionSoft: Color(0xFF3B221C),
  );

  @override
  TripPalette copyWith({
    Color? tea,
    Color? teaSoft,
    Color? wisteria,
    Color? wisteriaSoft,
    Color? vermilion,
    Color? vermilionSoft,
  }) =>
      TripPalette(
        tea: tea ?? this.tea,
        teaSoft: teaSoft ?? this.teaSoft,
        wisteria: wisteria ?? this.wisteria,
        wisteriaSoft: wisteriaSoft ?? this.wisteriaSoft,
        vermilion: vermilion ?? this.vermilion,
        vermilionSoft: vermilionSoft ?? this.vermilionSoft,
      );

  @override
  TripPalette lerp(TripPalette? other, double t) {
    if (other == null) return this;
    return TripPalette(
      tea: Color.lerp(tea, other.tea, t)!,
      teaSoft: Color.lerp(teaSoft, other.teaSoft, t)!,
      wisteria: Color.lerp(wisteria, other.wisteria, t)!,
      wisteriaSoft: Color.lerp(wisteriaSoft, other.wisteriaSoft, t)!,
      vermilion: Color.lerp(vermilion, other.vermilion, t)!,
      vermilionSoft: Color.lerp(vermilionSoft, other.vermilionSoft, t)!,
    );
  }
}

extension TripPaletteOf on ThemeData {
  /// The trip palette, falling back to the defaults for themes without it
  /// (tests use a plain [ThemeData]).
  TripPalette get trip =>
      extension<TripPalette>() ?? (brightness == Brightness.dark ? TripPalette.dark : TripPalette.light);
}
