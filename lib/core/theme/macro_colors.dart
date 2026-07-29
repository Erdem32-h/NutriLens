import 'package:flutter/material.dart';

import '../constants/macro_reference_constants.dart';

/// Makro KİMLİK renkleri — "hangi makro" bilgisini taşır.
/// gaugeColor/riskColor ile karıştırma: onlar kalite/risk taşır (spec §6.2).
/// Kimlik renkleri (protein/carbs/fat) sabittir; iki temada da aynı kalır
/// (grafikte tutarlılık). levelColor bunun dışındadır — bkz. aşağıdaki not.
abstract final class MacroColors {
  static const Color protein = Color(0xFF6366F1); // indigo
  static const Color carbs = Color(0xFFF59E0B); // amber
  static const Color fat = Color(0xFFEC4899); // pembe

  /// Düşük/Normal/Yüksek etiket renkleri (referans: mavi/yeşil/turuncu).
  /// Tema bazlı değişir: açık temada koyu tonlar kullanılır, çünkü bu
  /// renkler surfaceCard üzerinde %15 alpha dolgulu 11px metin olarak
  /// render ediliyor — koyu tema tonları açık temada WCAG AA kontrastının
  /// çok altında kalıyordu (~1.7-2.2:1).
  static Color levelColor(MacroLevel level, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (level) {
      MacroLevel.low =>
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
      MacroLevel.normal =>
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      MacroLevel.high =>
        isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
    };
  }
}
