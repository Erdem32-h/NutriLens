import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';

MealEntryEntity _entry({int? portionGrams}) => MealEntryEntity(
      id: 'm1',
      userId: 'user-1',
      mealName: 'Kahvaltı',
      mealType: MealType.breakfast,
      capturedAt: DateTime(2026, 8, 14),
      calories: 400,
      portionGrams: portionGrams,
    );

void main() {
  test('copyWith argumansiz cagrildiginda tum alanlari korur (== esittir)', () {
    final original = _entry(portionGrams: 150);
    expect(original.copyWith(), original);
  });

  test('copyWith tek alani degistirir, digerlerine dokunmaz', () {
    final original = _entry(portionGrams: null);
    final updated = original.copyWith(portionGrams: 200);

    expect(updated.portionGrams, 200);
    expect(updated.id, original.id);
    expect(updated.userId, original.userId);
    expect(updated.mealName, original.mealName);
    expect(updated.calories, original.calories);
  });
}
