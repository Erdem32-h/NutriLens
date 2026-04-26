import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/meals/domain/services/meal_defaults.dart';

void main() {
  test('defaults breakfast by capture time', () {
    final defaults = mealDefaultsFor(DateTime(2026, 4, 26, 8, 30));

    expect(defaults.name, 'Kahvaltı');
    expect(defaults.type, MealType.breakfast);
    expect(defaults.brand, 'Ev yapımı');
  });

  test('defaults lunch, dinner and snack by capture time', () {
    expect(mealDefaultsFor(DateTime(2026, 4, 26, 12)).name, 'Öğlen Yemeği');
    expect(mealDefaultsFor(DateTime(2026, 4, 26, 19)).name, 'Akşam Yemeği');
    expect(mealDefaultsFor(DateTime(2026, 4, 26, 23)).name, 'Ara Öğün');
  });
}
