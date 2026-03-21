import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  // Brand
  final Color primary;
  final Color primaryDark;
  final Color primaryDeep;

  // Backgrounds
  final Color background;
  final Color surface;
  final Color surfaceCard;
  final Color surfaceCard2;
  final Color border;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Semantic
  final Color error;
  final Color warning;
  final Color success;
  final Color info;

  // HP Gauge
  final Color gauge1;
  final Color gauge2;
  final Color gauge3;
  final Color gauge4;
  final Color gauge5;

  // NOVA
  final Color nova1;
  final Color nova2;
  final Color nova3;
  final Color nova4;

  // Risk
  final Color riskSafe;
  final Color riskLow;
  final Color riskModerate;
  final Color riskHigh;
  final Color riskDangerous;

  // Gradient
  final LinearGradient primaryGradient;
  final LinearGradient backgroundGradient;

  const AppColorsExtension({
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.background,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceCard2,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.error,
    required this.warning,
    required this.success,
    required this.info,
    required this.gauge1,
    required this.gauge2,
    required this.gauge3,
    required this.gauge4,
    required this.gauge5,
    required this.nova1,
    required this.nova2,
    required this.nova3,
    required this.nova4,
    required this.riskSafe,
    required this.riskLow,
    required this.riskModerate,
    required this.riskHigh,
    required this.riskDangerous,
    required this.primaryGradient,
    required this.backgroundGradient,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryDeep,
    Color? background,
    Color? surface,
    Color? surfaceCard,
    Color? surfaceCard2,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? error,
    Color? warning,
    Color? success,
    Color? info,
    Color? gauge1,
    Color? gauge2,
    Color? gauge3,
    Color? gauge4,
    Color? gauge5,
    Color? nova1,
    Color? nova2,
    Color? nova3,
    Color? nova4,
    Color? riskSafe,
    Color? riskLow,
    Color? riskModerate,
    Color? riskHigh,
    Color? riskDangerous,
    LinearGradient? primaryGradient,
    LinearGradient? backgroundGradient,
  }) {
    return AppColorsExtension(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCard2: surfaceCard2 ?? this.surfaceCard2,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      info: info ?? this.info,
      gauge1: gauge1 ?? this.gauge1,
      gauge2: gauge2 ?? this.gauge2,
      gauge3: gauge3 ?? this.gauge3,
      gauge4: gauge4 ?? this.gauge4,
      gauge5: gauge5 ?? this.gauge5,
      nova1: nova1 ?? this.nova1,
      nova2: nova2 ?? this.nova2,
      nova3: nova3 ?? this.nova3,
      nova4: nova4 ?? this.nova4,
      riskSafe: riskSafe ?? this.riskSafe,
      riskLow: riskLow ?? this.riskLow,
      riskModerate: riskModerate ?? this.riskModerate,
      riskHigh: riskHigh ?? this.riskHigh,
      riskDangerous: riskDangerous ?? this.riskDangerous,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCard2: Color.lerp(surfaceCard2, other.surfaceCard2, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      gauge1: Color.lerp(gauge1, other.gauge1, t)!,
      gauge2: Color.lerp(gauge2, other.gauge2, t)!,
      gauge3: Color.lerp(gauge3, other.gauge3, t)!,
      gauge4: Color.lerp(gauge4, other.gauge4, t)!,
      gauge5: Color.lerp(gauge5, other.gauge5, t)!,
      nova1: Color.lerp(nova1, other.nova1, t)!,
      nova2: Color.lerp(nova2, other.nova2, t)!,
      nova3: Color.lerp(nova3, other.nova3, t)!,
      nova4: Color.lerp(nova4, other.nova4, t)!,
      riskSafe: Color.lerp(riskSafe, other.riskSafe, t)!,
      riskLow: Color.lerp(riskLow, other.riskLow, t)!,
      riskModerate: Color.lerp(riskModerate, other.riskModerate, t)!,
      riskHigh: Color.lerp(riskHigh, other.riskHigh, t)!,
      riskDangerous: Color.lerp(riskDangerous, other.riskDangerous, t)!,
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      backgroundGradient: LinearGradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
    );
  }

  Color gaugeColor(int gauge) => switch (gauge) {
    1 => gauge1,
    2 => gauge2,
    3 => gauge3,
    4 => gauge4,
    _ => gauge5,
  };

  Color riskColor(int riskLevel) => switch (riskLevel) {
    1 => riskSafe,
    2 => riskLow,
    3 => riskModerate,
    4 => riskHigh,
    _ => riskDangerous,
  };

  Color novaColor(int novaGroup) => switch (novaGroup) {
    1 => nova1,
    2 => nova2,
    3 => nova3,
    _ => nova4,
  };

  static const dark = AppColorsExtension(
    primary: Color(0xFF4ADE80),
    primaryDark: Color(0xFF22C55E),
    primaryDeep: Color(0xFF16A34A),
    background: Color(0xFF070D07),
    surface: Color(0xFF0F1A0F),
    surfaceCard: Color(0xFF162016),
    surfaceCard2: Color(0xFF1E2E1E),
    border: Color(0xFF243324),
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFF86EFAC),
    textMuted: Color(0xFF4B7A4B),
    error: Color(0xFFF87171),
    warning: Color(0xFFFCD34D),
    success: Color(0xFF4ADE80),
    info: Color(0xFF60A5FA),
    gauge1: Color(0xFF4ADE80),
    gauge2: Color(0xFF86EFAC),
    gauge3: Color(0xFFFCD34D),
    gauge4: Color(0xFFFB923C),
    gauge5: Color(0xFFF87171),
    nova1: Color(0xFF4ADE80),
    nova2: Color(0xFF86EFAC),
    nova3: Color(0xFFFCD34D),
    nova4: Color(0xFFF87171),
    riskSafe: Color(0xFF4ADE80),
    riskLow: Color(0xFF86EFAC),
    riskModerate: Color(0xFFFCD34D),
    riskHigh: Color(0xFFFB923C),
    riskDangerous: Color(0xFFF87171),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF070D07), Color(0xFF0F1A0F)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const light = AppColorsExtension(
    primary: Color(0xFF16A34A), // Deep green primary in light mode for contrast
    primaryDark: Color(0xFF15803D), // Darker green
    primaryDeep: Color(0xFF166534), // Even darker for deep primary
    background: Color(0xFFF8FAFC), // Off-white/slate-50 background
    surface: Color(0xFFFFFFFF), // Pure white surface
    surfaceCard: Color(0xFFF1F5F9), // Slate-100 card surface
    surfaceCard2: Color(0xFFE2E8F0), // Slate-200 alternate card surface
    border: Color(0xFFCBD5E1), // Slate-300 borders
    textPrimary: Color(0xFF0F172A), // Slate-900 primary text
    textSecondary: Color(0xFF334155), // Slate-700 secondary text
    textMuted: Color(0xFF64748B), // Slate-500 muted text
    error: Color(0xFFEF4444), // Slightly darker red for contrast
    warning: Color(0xFFF59E0B), // Slightly darker amber for contrast
    success: Color(0xFF10B981), // Emerald success color
    info: Color(0xFF3B82F6), // Blue info
    gauge1: Color(0xFF10B981),
    gauge2: Color(0xFF34D399),
    gauge3: Color(0xFFFBBF24),
    gauge4: Color(0xFFF97316),
    gauge5: Color(0xFFEF4444),
    nova1: Color(0xFF10B981),
    nova2: Color(0xFF34D399),
    nova3: Color(0xFFFBBF24),
    nova4: Color(0xFFEF4444),
    riskSafe: Color(0xFF10B981),
    riskLow: Color(0xFF34D399),
    riskModerate: Color(0xFFFBBF24),
    riskHigh: Color(0xFFF97316),
    riskDangerous: Color(0xFFEF4444),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

extension AppColorsContextExtension on BuildContext {
  AppColorsExtension get colors {
    final ext = Theme.of(this).extension<AppColorsExtension>();
    assert(ext != null, 'AppColorsExtension not found in theme. Add it to ThemeData.extensions.');
    return ext ?? AppColorsExtension.dark;
  }
}
