import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF60AD5E);
  static const Color primaryDark = Color(0xFF005005);

  // HP Gauge colors
  static const Color gauge1 = Color(0xFF2E7D32); // Best - Green
  static const Color gauge2 = Color(0xFF66BB6A); // Good - Light Green
  static const Color gauge3 = Color(0xFFFDD835); // Moderate - Yellow
  static const Color gauge4 = Color(0xFFFF9800); // Poor - Orange
  static const Color gauge5 = Color(0xFFD32F2F); // Worst - Red

  // Risk indicator colors
  static const Color riskSafe = Color(0xFF4CAF50);
  static const Color riskLow = Color(0xFF8BC34A);
  static const Color riskModerate = Color(0xFFFFC107);
  static const Color riskHigh = Color(0xFFFF5722);
  static const Color riskDangerous = Color(0xFFB71C1C);

  // NOVA group colors
  static const Color nova1 = Color(0xFF2E7D32);
  static const Color nova2 = Color(0xFF689F38);
  static const Color nova3 = Color(0xFFF9A825);
  static const Color nova4 = Color(0xFFD32F2F);

  // Semantic colors
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color info = Color(0xFF1976D2);

  // Surface colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color backgroundDark = Color(0xFF1E1E1E);

  static Color gaugeColor(int gauge) {
    return switch (gauge) {
      1 => gauge1,
      2 => gauge2,
      3 => gauge3,
      4 => gauge4,
      _ => gauge5,
    };
  }

  static Color riskColor(int riskLevel) {
    return switch (riskLevel) {
      1 => riskSafe,
      2 => riskLow,
      3 => riskModerate,
      4 => riskHigh,
      _ => riskDangerous,
    };
  }

  static Color novaColor(int novaGroup) {
    return switch (novaGroup) {
      1 => nova1,
      2 => nova2,
      3 => nova3,
      _ => nova4,
    };
  }
}
