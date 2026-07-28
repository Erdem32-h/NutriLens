import 'package:flutter/material.dart';

import '../constants/macro_reference_constants.dart';

/// Makro KİMLİK renkleri — "hangi makro" bilgisini taşır.
/// gaugeColor/riskColor ile karıştırma: onlar kalite/risk taşır (spec §6.2).
/// Sabit renklerdir; iki temada da aynı kalırlar (grafikte tutarlılık).
abstract final class MacroColors {
  static const Color protein = Color(0xFF6366F1); // indigo
  static const Color carbs = Color(0xFFF59E0B); // amber
  static const Color fat = Color(0xFFEC4899); // pembe

  /// Düşük/Normal/Yüksek etiket renkleri (referans: mavi/yeşil/turuncu).
  static Color levelColor(MacroLevel level) => switch (level) {
        MacroLevel.low => const Color(0xFF38BDF8),
        MacroLevel.normal => const Color(0xFF4ADE80),
        MacroLevel.high => const Color(0xFFFB923C),
      };
}
