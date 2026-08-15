import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  late AppDatabase db;
  late MealLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = MealLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  MealEntryEntity meal({int? portionGrams}) => MealEntryEntity(
    id: 'm1',
    userId: 'guest',
    mealName: 'Mercimek çorbası',
    mealType: MealType.lunch,
    capturedAt: DateTime(2026, 8, 14),
    nutriments: const NutrimentsEntity(energyKcal: 320),
    calories: 320,
    portionGrams: portionGrams,
    syncStatus: 'local_only',
  );

  test('porsiyon gramaji kaydedilir ve geri okunur', () async {
    await ds.saveMeal(meal(portionGrams: 350));
    final read = await ds.getMealById('m1');
    expect(read!.portionGrams, 350);
  });

  test('gramaj verilmezse null kalir, kayit yine calisir', () async {
    await ds.saveMeal(meal());
    final read = await ds.getMealById('m1');
    expect(read!.portionGrams, isNull);
    expect(read.calories, 320);
  });
}
