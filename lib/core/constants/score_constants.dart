abstract final class ScoreConstants {
  // HP formula weights
  static const double chemicalWeight = 0.50;
  static const double riskWeight = 0.30;
  static const double nutriWeight = 0.20;

  // Chemical Load penalties per additive risk level
  static const Map<int, double> additivePenalties = {
    1: 0.0,   // safe
    2: 5.0,   // low risk
    3: 12.0,  // moderate
    4: 20.0,  // high risk
    5: 30.0,  // dangerous
  };

  // Risk Factor reference values (per 100g)
  static const double sugarMaxRef = 45.0;
  static const double saltMaxRef = 6.0;
  static const double saturatedFatMaxRef = 20.0;

  // Risk Factor sub-weights
  static const double sugarWeight = 0.40;
  static const double saltWeight = 0.30;
  static const double saturatedFatWeight = 0.30;

  // Nutri Factor reference values (per 100g)
  static const double fiberExcellent = 8.0;
  static const double proteinExcellent = 20.0;

  // Nutri Factor sub-weights
  static const double fiberWeight = 0.30;
  static const double proteinWeight = 0.30;
  static const double naturalnessWeight = 0.40;

  // NOVA naturalness scores
  static const Map<int, double> novaNaturalness = {
    1: 100.0,
    2: 66.0,
    3: 33.0,
    4: 0.0,
  };

  // HP to Gauge mapping thresholds
  static const double gauge1Threshold = 80.0; // Best - Green
  static const double gauge2Threshold = 60.0; // Good - Light Green
  static const double gauge3Threshold = 40.0; // Moderate - Yellow
  static const double gauge4Threshold = 20.0; // Poor - Orange
  // Below 20 -> Gauge 5 (Worst - Red)

  static int hpToGauge(double hp) {
    if (hp >= gauge1Threshold) return 1;
    if (hp >= gauge2Threshold) return 2;
    if (hp >= gauge3Threshold) return 3;
    if (hp >= gauge4Threshold) return 4;
    return 5;
  }
}
