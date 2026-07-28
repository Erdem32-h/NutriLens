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
}
