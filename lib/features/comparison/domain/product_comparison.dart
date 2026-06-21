import '../../product/domain/entities/product_entity.dart';

/// Metrics compared, in fixed display order.
enum ComparisonMetric {
  hpScore,
  energy,
  fat,
  saturatedFat,
  sugar,
  salt,
  protein,
  fiber,
  nova,
  additives,
  nutriScore,
}

/// Which product wins a metric (or neither).
enum BetterSide { a, b, none }

/// One comparison row. [displayA]/[displayB] are formatted numbers/letters
/// WITHOUT units (the UI adds " g" / " kcal" and the localized label). A
/// missing value renders as "—" and forces [betterSide] = none.
class ComparisonRow {
  final ComparisonMetric metric;
  final String displayA;
  final String displayB;
  final BetterSide betterSide;

  const ComparisonRow({
    required this.metric,
    required this.displayA,
    required this.displayB,
    required this.betterSide,
  });
}

/// Pure, locale-independent comparison of two products. Returns one row per
/// [ComparisonMetric] in a fixed order. Direction ("higher better" vs "lower
/// better") and number formatting live here so they are unit-testable.
List<ComparisonRow> comparisonMetrics(ProductEntity a, ProductEntity b) {
  final na = a.nutriments;
  final nb = b.nutriments;
  return [
    _numRow(ComparisonMetric.hpScore, a.calculatedHpScore, b.calculatedHpScore,
        higherBetter: true, format: _fmtInt),
    _numRow(ComparisonMetric.energy, na.energyKcal, nb.energyKcal,
        higherBetter: false, format: _fmtInt),
    _numRow(ComparisonMetric.fat, na.fat, nb.fat,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.saturatedFat, na.saturatedFat, nb.saturatedFat,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.sugar, na.sugars, nb.sugars,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.salt, na.salt, nb.salt,
        higherBetter: false, format: _fmtG),
    _numRow(ComparisonMetric.protein, na.proteins, nb.proteins,
        higherBetter: true, format: _fmtG),
    _numRow(ComparisonMetric.fiber, na.fiber, nb.fiber,
        higherBetter: true, format: _fmtG),
    _numRow(ComparisonMetric.nova, a.novaGroup?.toDouble(),
        b.novaGroup?.toDouble(), higherBetter: false, format: _fmtInt),
    _numRow(
        ComparisonMetric.additives,
        a.additivesTags.length.toDouble(),
        b.additivesTags.length.toDouble(),
        higherBetter: false,
        format: _fmtInt),
    _nutriScoreRow(a.nutriscoreGrade, b.nutriscoreGrade),
  ];
}

ComparisonRow _numRow(
  ComparisonMetric metric,
  double? a,
  double? b, {
  required bool higherBetter,
  required String Function(double?) format,
}) {
  return ComparisonRow(
    metric: metric,
    displayA: format(a),
    displayB: format(b),
    betterSide: _better(a, b, higherBetter: higherBetter),
  );
}

ComparisonRow _nutriScoreRow(String? a, String? b) {
  return ComparisonRow(
    metric: ComparisonMetric.nutriScore,
    displayA: _fmtGrade(a),
    displayB: _fmtGrade(b),
    // Nutri-Score: A(1) is best → lower ordinal wins.
    betterSide: _better(
      _nutriOrdinal(a)?.toDouble(),
      _nutriOrdinal(b)?.toDouble(),
      higherBetter: false,
    ),
  );
}

BetterSide _better(double? a, double? b, {required bool higherBetter}) {
  if (a == null || b == null) return BetterSide.none;
  if (a == b) return BetterSide.none;
  final aWins = higherBetter ? a > b : a < b;
  return aWins ? BetterSide.a : BetterSide.b;
}

String _fmtInt(double? v) => v == null ? '—' : v.round().toString();

String _fmtG(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

int? _nutriOrdinal(String? grade) {
  if (grade == null) return null;
  switch (grade.trim().toLowerCase()) {
    case 'a':
      return 1;
    case 'b':
      return 2;
    case 'c':
      return 3;
    case 'd':
      return 4;
    case 'e':
      return 5;
    default:
      return null;
  }
}

String _fmtGrade(String? grade) {
  if (grade == null || grade.trim().isEmpty) return '—';
  return _nutriOrdinal(grade) == null ? '—' : grade.trim().toUpperCase();
}
