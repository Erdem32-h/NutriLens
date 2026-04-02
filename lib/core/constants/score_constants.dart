abstract final class ScoreConstants {
  // ── HP Formula Weights ──────────────────────────────────────────────
  // These weights define how much each component contributes to the
  // final 1-5 gauge score. They are applied as PENALTY multipliers,
  // not percentage weights.
  //
  // Formula: hpScore = 100 - chemPenalty - riskPenalty + nutriBonus
  //
  // chemPenalty = chemicalLoad * 0.45  → max ~45 points lost
  // riskPenalty = riskFactor * 0.40    → max ~40 points lost
  // nutriBonus  = nutriFactor * 0.15   → max ~15 points gained
  //
  // This means a product with ZERO additives but terrible nutrition
  // can still score as low as 60 (100 - 0 - 40 + 0) → Gauge 3,
  // and with even moderate additives it drops further.

  static const double chemicalWeight = 0.45;
  static const double riskWeight = 0.40;
  static const double nutriWeight = 0.15;

  // ── Chemical Load ───────────────────────────────────────────────────
  // Penalties per additive risk level (summed, capped at 100)
  static const Map<int, double> additivePenalties = {
    1: 0.0, // safe / natural
    2: 4.0, // low risk
    3: 10.0, // moderate
    4: 18.0, // high risk
    5: 28.0, // dangerous
  };

  // ── Risk Factor ─────────────────────────────────────────────────────
  // Reference values (per 100g) — when a nutrient hits this value,
  // its sub-score maxes out at 100.
  static const double sugarMaxRef = 22.5; // WHO: <25g free sugar/day
  static const double saltMaxRef = 2.4; // WHO: <5g salt/day → ~2.4g/100g threshold
  static const double saturatedFatMaxRef = 10.0; // ~10g/100g is very high

  // Sub-weights inside risk factor (must sum to 1.0)
  static const double sugarWeight = 0.40;
  static const double saltWeight = 0.25;
  static const double saturatedFatWeight = 0.35;

  // ── Nutri Factor ────────────────────────────────────────────────────
  // "Excellent" reference values — hitting these gives max bonus
  static const double fiberExcellent = 6.0; // 6g/100g = high-fiber
  static const double proteinExcellent = 15.0; // 15g/100g = good protein

  // Sub-weights inside nutri factor (must sum to 1.0)
  static const double fiberWeight = 0.30;
  static const double proteinWeight = 0.30;
  static const double naturalnessWeight = 0.40;

  // NOVA naturalness scores (used in nutri factor)
  static const Map<int, double> novaNaturalness = {
    1: 100.0, // Unprocessed / minimally processed
    2: 60.0, // Processed culinary ingredients
    3: 30.0, // Processed foods
    4: 0.0, // Ultra-processed
  };

  // Default naturalness when NOVA group is unknown
  static const double novaUnknownNaturalness = 15.0;

  // ── Gauge Mapping ───────────────────────────────────────────────────
  // Single 1-5 gauge: 1 = best, 5 = worst
  static const double gauge1Threshold = 75.0; // Excellent
  static const double gauge2Threshold = 55.0; // Good
  static const double gauge3Threshold = 35.0; // Moderate
  static const double gauge4Threshold = 18.0; // Poor
  // Below 18 → Gauge 5 (Very Poor)

  static int hpToGauge(double? hp) {
    if (hp == null) return 3; // Unknown → moderate
    if (hp >= gauge1Threshold) return 1;
    if (hp >= gauge2Threshold) return 2;
    if (hp >= gauge3Threshold) return 3;
    if (hp >= gauge4Threshold) return 4;
    return 5;
  }

  /// Normalizes Turkish characters and handles case conversion for reliable string matching.
  static String normalizeTurkish(String text) {
    return text
        .toLowerCase()
        .replaceAll('i̇', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  /// Centralized critical ingredient patterns, pre-normalized.
  static const List<String> criticalPatterns = [
    'palm yag', 'palm oil', 'palmiye yag',
    'invert seker', 'invert sugar',
    'glikoz surubu', 'glikoz surub', 'glucose syrup', 'glukoz surubu',
    'fruktoz surubu', 'fruktoz surub', 'fructose syrup',
    'misir surubu', 'misir surub', 'corn syrup',
    'yuksek fruktozlu', 'high fructose corn syrup', 'hfcs',
    'seker surubu', 'seker surub', 'sugar syrup',
  ];
}
