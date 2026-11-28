import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/home_widget_service.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  test('makro yüzdeleri Atwater kcal paylarından hesaplanır', () {
    final result = HomeWidgetService.macroPercentages([
      // 25g P=100kcal, 50g K=200kcal, ~11.1g Y=100kcal → 25/50/25
      NutrimentsEntity(proteins: 25, carbohydrates: 50, fat: 100 / 9),
    ]);
    expect(result.protein, 25);
    expect(result.carb, 50);
    expect(result.fat, 25);
  });

  test('veri yoksa hepsi 0', () {
    final result = HomeWidgetService.macroPercentages(const []);
    expect(result.protein, 0);
    expect(result.carb, 0);
    expect(result.fat, 0);
  });

  test('null alanlar 0 sayılır', () {
    final result = HomeWidgetService.macroPercentages(
      [const NutrimentsEntity(proteins: 10)],
    );
    expect(result.protein, 100);
    expect(result.carb, 0);
    expect(result.fat, 0);
  });

  group('pending water queue', () {
    test('boş veya null girdi boş harita döner', () {
      expect(HomeWidgetService.parsePendingWaterQueue(null), isEmpty);
      expect(HomeWidgetService.parsePendingWaterQueue(''), isEmpty);
      expect(HomeWidgetService.parsePendingWaterQueue('   '), isEmpty);
    });

    test('günlük sayaçları parse eder ve aynı günü toplar', () {
      final parsed = HomeWidgetService.parsePendingWaterQueue(
        '2026-11-27:2, 2026-11-28:3, 2026-11-28:1, bozuk, 2026-11-29:0',
      );
      expect(parsed, {'2026-11-27': 2, '2026-11-28': 4});
    });

    test('encode sıralı ve pozitif kayıtları yazar', () {
      final encoded = HomeWidgetService.encodePendingWaterQueue({
        '2026-11-28': 3,
        '2026-11-27': 1,
        '2026-11-29': 0,
      });
      expect(encoded, '2026-11-27:1,2026-11-28:3');
    });
  });
}
