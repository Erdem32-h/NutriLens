import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  late AppDatabase db;
  late MealLocalDataSource dataSource;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = MealLocalDataSourceImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  MealEntryEntity meal({
    required String id,
    required DateTime capturedAt,
    required double kcal,
  }) {
    return MealEntryEntity(
      id: id,
      userId: 'user-1',
      mealName: 'Kahvaltı',
      brand: 'Ev yapımı',
      mealType: MealType.breakfast,
      capturedAt: capturedAt,
      ingredientsText: 'Yumurta, peynir',
      nutriments: NutrimentsEntity(energyKcal: kcal, proteins: 20),
      calories: kcal,
      hpScore: 82,
      confidence: 0.8,
      aiRawJson: '{"food_name":"omelet"}',
    );
  }

  test('saves meals and returns them newest first', () async {
    await dataSource.saveMeal(
      meal(id: 'old', capturedAt: DateTime(2026, 4, 25, 9), kcal: 300),
    );
    await dataSource.saveMeal(
      meal(id: 'new', capturedAt: DateTime(2026, 4, 26, 12), kcal: 500),
    );

    final meals = await dataSource.getMeals(userId: 'user-1');

    expect(meals.map((m) => m.id), ['new', 'old']);
    expect(meals.first.nutriments.energyKcal, 500);
  });

  test('summarizes calories for a date range', () async {
    await dataSource.saveMeal(
      meal(id: 'today-1', capturedAt: DateTime(2026, 4, 26, 8), kcal: 350),
    );
    await dataSource.saveMeal(
      meal(id: 'today-2', capturedAt: DateTime(2026, 4, 26, 20), kcal: 650),
    );
    await dataSource.saveMeal(
      meal(id: 'outside', capturedAt: DateTime(2026, 4, 25, 20), kcal: 900),
    );

    final total = await dataSource.totalCalories(
      userId: 'user-1',
      from: DateTime(2026, 4, 26),
      to: DateTime(2026, 4, 27),
    );

    expect(total, 1000);
  });
}
