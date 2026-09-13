/// One glass on the counter.
const int kGlassMl = 200;

const int kDefaultWaterGoalGlasses = 10;

/// Bounds for the manual goal stepper.
const int kMinGoalGlasses = 1;
const int kMaxGoalGlasses = 20;

const double _mlPerKg = 35;
const int _minSuggested = 6;
const int _maxSuggested = 16;

/// Goal suggestion from body weight; default when weight is unknown.
int suggestedWaterGoal(double? weightKg) {
  if (weightKg == null || weightKg <= 0) return kDefaultWaterGoalGlasses;
  final glasses = (weightKg * _mlPerKg / kGlassMl).round();
  return glasses.clamp(_minSuggested, _maxSuggested);
}
