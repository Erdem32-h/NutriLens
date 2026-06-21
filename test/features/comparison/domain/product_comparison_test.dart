import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/comparison/domain/product_comparison.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

ProductEntity _p({
  required String barcode,
  double? hp,
  NutrimentsEntity nutriments = const NutrimentsEntity(),
  int? nova,
  String? nutriscore,
  List<String> additives = const [],
}) {
  return ProductEntity(
    barcode: barcode,
    productName: barcode,
    nutriments: nutriments,
    novaGroup: nova,
    nutriscoreGrade: nutriscore,
    additivesTags: additives,
    hpScore: hp,
  );
}

ComparisonRow _row(List<ComparisonRow> rows, ComparisonMetric m) =>
    rows.firstWhere((r) => r.metric == m);

void main() {
  group('comparisonMetrics', () {
    test('returns one row per metric in fixed order', () {
      final rows = comparisonMetrics(_p(barcode: 'a'), _p(barcode: 'b'));
      expect(rows.map((r) => r.metric).toList(), [
        ComparisonMetric.hpScore,
        ComparisonMetric.energy,
        ComparisonMetric.fat,
        ComparisonMetric.saturatedFat,
        ComparisonMetric.sugar,
        ComparisonMetric.salt,
        ComparisonMetric.protein,
        ComparisonMetric.fiber,
        ComparisonMetric.nova,
        ComparisonMetric.additives,
        ComparisonMetric.nutriScore,
      ]);
    });

    test('HP score: higher wins (side A)', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', hp: 82),
        _p(barcode: 'b', hp: 40),
      );
      final hp = _row(rows, ComparisonMetric.hpScore);
      expect(hp.displayA, '82');
      expect(hp.displayB, '40');
      expect(hp.betterSide, BetterSide.a);
    });

    test('energy: lower wins (side B)', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(energyKcal: 540)),
        _p(barcode: 'b', nutriments: const NutrimentsEntity(energyKcal: 120)),
      );
      final e = _row(rows, ComparisonMetric.energy);
      expect(e.displayA, '540');
      expect(e.displayB, '120');
      expect(e.betterSide, BetterSide.b);
    });

    test('protein: higher wins; grams trim trailing .0', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(proteins: 12)),
        _p(barcode: 'b', nutriments: const NutrimentsEntity(proteins: 3.2)),
      );
      final p = _row(rows, ComparisonMetric.protein);
      expect(p.displayA, '12');
      expect(p.displayB, '3.2');
      expect(p.betterSide, BetterSide.a);
    });

    test('nova: lower group wins', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nova: 4),
        _p(barcode: 'b', nova: 1),
      );
      expect(_row(rows, ComparisonMetric.nova).betterSide, BetterSide.b);
    });

    test('additive count: fewer wins, never dashed', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', additives: const ['e1', 'e2', 'e3']),
        _p(barcode: 'b', additives: const ['e1']),
      );
      final ad = _row(rows, ComparisonMetric.additives);
      expect(ad.displayA, '3');
      expect(ad.displayB, '1');
      expect(ad.betterSide, BetterSide.b);
    });

    test('nutri-score: A beats C; display is uppercase letter', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriscore: 'a'),
        _p(barcode: 'b', nutriscore: 'c'),
      );
      final ns = _row(rows, ComparisonMetric.nutriScore);
      expect(ns.displayA, 'A');
      expect(ns.displayB, 'C');
      expect(ns.betterSide, BetterSide.a);
    });

    test('missing value: dash + no highlight', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(sugars: 9)),
        _p(barcode: 'b'),
      );
      final s = _row(rows, ComparisonMetric.sugar);
      expect(s.displayA, '9');
      expect(s.displayB, '—');
      expect(s.betterSide, BetterSide.none);
    });

    test('equal values: no highlight', () {
      final rows = comparisonMetrics(
        _p(barcode: 'a', nutriments: const NutrimentsEntity(salt: 1)),
        _p(barcode: 'b', nutriments: const NutrimentsEntity(salt: 1)),
      );
      expect(_row(rows, ComparisonMetric.salt).betterSide, BetterSide.none);
    });
  });
}
