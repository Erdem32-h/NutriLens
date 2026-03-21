import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme textTheme(AppColorsExtension colors) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 36, fontWeight: FontWeight.w800,
        letterSpacing: -1.0, color: colors.textPrimary,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 30, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: colors.textPrimary,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 26, fontWeight: FontWeight.w700,
        letterSpacing: -0.25, color: colors.textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: colors.textPrimary, height: 1.6,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: colors.textSecondary, height: 1.5,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: colors.textMuted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w600,
        letterSpacing: 0.2, color: colors.textPrimary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 10, fontWeight: FontWeight.w500,
        letterSpacing: 0.5, color: colors.textMuted,
      ),
    );
  }
}
