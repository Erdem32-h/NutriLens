import 'package:flutter/material.dart';

/// One soft accent: the fill a card sits on, plus the stronger ink used for
/// the icon and the accent label printed on that fill.
///
/// Kept as a pair rather than two loose colours because the two are only
/// ever correct together — a lilac fill with mint ink is not a tint, it is a
/// mistake, and pairing them here makes that unrepresentable at the call
/// site.
@immutable
class CozyTint {
  /// Card fill. Low saturation in light mode, a dark wash of the same hue in
  /// dark mode — never the raw accent, which would shout over the content.
  final Color surface;

  /// Icon and accent-label colour. Carries the hue at full strength so the
  /// tint still reads on a small glyph.
  final Color ink;

  const CozyTint({required this.surface, required this.ink});

  static CozyTint lerp(CozyTint a, CozyTint b, double t) => CozyTint(
    surface: Color.lerp(a.surface, b.surface, t)!,
    ink: Color.lerp(a.ink, b.ink, t)!,
  );
}

/// The cozy layer: five rotating tints plus the warm wash behind a screen's
/// header.
///
/// Five is deliberate — enough that a settings list never repeats a colour
/// within a section, few enough that the app still reads as one palette.
/// Screens pick a tint by meaning (warnings peach, chemistry rose), and fall
/// back to [byIndex] for lists whose length is not known up front.
@immutable
class CozyPalette {
  final CozyTint lilac;
  final CozyTint sky;
  final CozyTint mint;
  final CozyTint peach;
  final CozyTint rose;

  /// Painted behind the large screen headers. Fades to transparent so the
  /// scaffold background takes over below the fold — the wash is a top-of-
  /// screen glow, not a full-page gradient.
  final LinearGradient headerGlow;

  /// Fill for anything that has to read as lifted off the page: the floating
  /// nav bar, the neutral content cards.
  ///
  /// Separate from `surface` because the two themes lift things by opposite
  /// means. In light mode a shadow does the work and the fill is simply
  /// white. In dark mode a shadow is invisible, so separation has to come
  /// from the fill being lighter than the page — and `surface` is not,
  /// by enough to see.
  final Color floating;

  /// Body text on a tinted card.
  ///
  /// Not `textSecondary`: that token is mint green in the dark theme, which
  /// is fine on the app's green-toned surfaces but turns a subtitle on a
  /// lilac or rose card into a colour clash. This one stays neutral in both
  /// themes, which is what a subtitle under a coloured icon needs.
  final Color bodyOnTint;

  const CozyPalette({
    required this.lilac,
    required this.sky,
    required this.mint,
    required this.peach,
    required this.rose,
    required this.headerGlow,
    required this.floating,
    required this.bodyOnTint,
  });

  List<CozyTint> get all => [lilac, sky, mint, peach, rose];

  /// Cycles the five tints, for lists that are built from data rather than
  /// hand-placed.
  CozyTint byIndex(int index) => all[index % all.length];

  static CozyPalette lerp(CozyPalette a, CozyPalette b, double t) =>
      CozyPalette(
        lilac: CozyTint.lerp(a.lilac, b.lilac, t),
        sky: CozyTint.lerp(a.sky, b.sky, t),
        mint: CozyTint.lerp(a.mint, b.mint, t),
        peach: CozyTint.lerp(a.peach, b.peach, t),
        rose: CozyTint.lerp(a.rose, b.rose, t),
        headerGlow: LinearGradient.lerp(a.headerGlow, b.headerGlow, t)!,
        floating: Color.lerp(a.floating, b.floating, t)!,
        bodyOnTint: Color.lerp(a.bodyOnTint, b.bodyOnTint, t)!,
      );

  static const lightPalette = CozyPalette(
    lilac: CozyTint(surface: Color(0xFFEFEAFB), ink: Color(0xFF7C5CE0)),
    sky: CozyTint(surface: Color(0xFFE7F1FD), ink: Color(0xFF3B82F6)),
    mint: CozyTint(surface: Color(0xFFE4F6EC), ink: Color(0xFF10B981)),
    peach: CozyTint(surface: Color(0xFFFDF0DE), ink: Color(0xFFD97F13)),
    rose: CozyTint(surface: Color(0xFFFCE8EE), ink: Color(0xFFDB4E85)),
    headerGlow: LinearGradient(
      colors: [Color(0xFFFBE9F0), Color(0xFFEFEAFB), Color(0x00F8FAFC)],
      stops: [0, 0.45, 1],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    floating: Color(0xFFFFFFFF),
    bodyOnTint: Color(0xFF44506B),
  );

  /// Dark mode keeps the same hues but inverts the relationship: the fill is
  /// a deep wash of the hue and the ink is the bright end of it, so a tinted
  /// card reads as tinted without ever becoming a light rectangle punched
  /// into a dark screen.
  static const darkPalette = CozyPalette(
    lilac: CozyTint(surface: Color(0xFF241F33), ink: Color(0xFFA78BFA)),
    sky: CozyTint(surface: Color(0xFF16233A), ink: Color(0xFF60A5FA)),
    mint: CozyTint(surface: Color(0xFF10291F), ink: Color(0xFF34D399)),
    peach: CozyTint(surface: Color(0xFF2E2416), ink: Color(0xFFFBBF24)),
    rose: CozyTint(surface: Color(0xFF301A24), ink: Color(0xFFF472B6)),
    headerGlow: LinearGradient(
      colors: [Color(0xFF1C1730), Color(0xFF12201A), Color(0x00070D07)],
      stops: [0, 0.45, 1],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    floating: Color(0xFF18231A),
    bodyOnTint: Color(0xFFCBD5CD),
  );
}
