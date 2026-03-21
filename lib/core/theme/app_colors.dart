import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary      = Color(0xFF4ADE80);
  static const Color primaryDark  = Color(0xFF22C55E);
  static const Color primaryDeep  = Color(0xFF16A34A);

  // Backgrounds
  static const Color background   = Color(0xFF070D07);
  static const Color surface      = Color(0xFF0F1A0F);
  static const Color surfaceCard  = Color(0xFF162016);
  static const Color surfaceCard2 = Color(0xFF1E2E1E);
  static const Color border       = Color(0xFF243324);

  // Text
  static const Color textPrimary   = Color(0xFFF0FDF4);
  static const Color textSecondary = Color(0xFF86EFAC);
  static const Color textMuted     = Color(0xFF4B7A4B);

  // Semantic
  static const Color error   = Color(0xFFF87171);
  static const Color warning = Color(0xFFFCD34D);
  static const Color success = Color(0xFF4ADE80);
  static const Color info    = Color(0xFF60A5FA);

  // HP Gauge
  static const Color gauge1 = Color(0xFF4ADE80);
  static const Color gauge2 = Color(0xFF86EFAC);
  static const Color gauge3 = Color(0xFFFCD34D);
  static const Color gauge4 = Color(0xFFFB923C);
  static const Color gauge5 = Color(0xFFF87171);

  // NOVA
  static const Color nova1 = Color(0xFF4ADE80);
  static const Color nova2 = Color(0xFF86EFAC);
  static const Color nova3 = Color(0xFFFCD34D);
  static const Color nova4 = Color(0xFFF87171);

  // Risk
  static const Color riskSafe      = Color(0xFF4ADE80);
  static const Color riskLow       = Color(0xFF86EFAC);
  static const Color riskModerate  = Color(0xFFFCD34D);
  static const Color riskHigh      = Color(0xFFFB923C);
  static const Color riskDangerous = Color(0xFFF87171);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF070D07), Color(0xFF0F1A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color gaugeColor(int gauge) => switch (gauge) {
    1 => gauge1,
    2 => gauge2,
    3 => gauge3,
    4 => gauge4,
    _ => gauge5,
  };

  static Color riskColor(int riskLevel) => switch (riskLevel) {
    1 => riskSafe,
    2 => riskLow,
    3 => riskModerate,
    4 => riskHigh,
    _ => riskDangerous,
  };

  static Color novaColor(int novaGroup) => switch (novaGroup) {
    1 => nova1,
    2 => nova2,
    3 => nova3,
    _ => nova4,
  };
}
