import 'package:flutter/material.dart';

/// Fixed light/brand palette for share cards — intentionally independent of
/// the app's (dark) theme so shared images read consistently on social feeds.
abstract final class ShareCardPalette {
  static const bg = Color(0xFFF6F8F4);
  static const surface = Color(0xFFFFFFFF);
  static const brand = Color(0xFF0E7A3B);
  static const textPrimary = Color(0xFF14201A);
  static const textMuted = Color(0xFF6B756E);
  static const border = Color(0xFFE2E8E2);

  // Gauge 1 (best) → 5 (worst).
  static const _gauge = <Color>[
    Color(0xFF2E9E5B),
    Color(0xFF7CB342),
    Color(0xFFF5A623),
    Color(0xFFEF6C00),
    Color(0xFFD7263D),
  ];

  static Color gaugeColor(int gauge) => _gauge[(gauge - 1).clamp(0, 4)];
}
