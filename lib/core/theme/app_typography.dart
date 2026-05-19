import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Fallback chain ensures Turkish characters (ş, ğ, ı, ö, ü, ç) and emoji
/// always render even when Plus Jakarta Sans hasn't finished downloading or
/// when its Latin Extended-A glyphs aren't packed in the cached weight.
const _fontFallback = <String>['Roboto', 'sans-serif'];

abstract final class AppTypography {
  static TextStyle _jakarta({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    ).copyWith(fontFamilyFallback: _fontFallback);
  }

  static TextTheme textTheme(AppColorsExtension colors) {
    final base = GoogleFonts.plusJakartaSansTextTheme().apply(
      fontFamilyFallback: _fontFallback,
    );
    return base.copyWith(
      displayLarge: _jakarta(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: colors.textPrimary,
      ),
      displayMedium: _jakarta(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: colors.textPrimary,
      ),
      headlineLarge: _jakarta(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: colors.textPrimary,
      ),
      headlineMedium: _jakarta(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleLarge: _jakarta(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleMedium: _jakarta(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: _jakarta(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.6,
      ),
      bodyMedium: _jakarta(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.5,
      ),
      bodySmall: _jakarta(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textMuted,
      ),
      labelLarge: _jakarta(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: colors.textPrimary,
      ),
      labelMedium: _jakarta(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      labelSmall: _jakarta(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colors.textMuted,
      ),
    );
  }
}
