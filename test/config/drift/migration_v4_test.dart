import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('sema surumu 4', () {
    expect(db.schemaVersion, 4);
  });

  test('user_metrics tablosu bos baslar ve tek satir tutar', () async {
    expect(await db.select(db.userMetrics).get(), isEmpty);

    await db
        .into(db.userMetrics)
        .insertOnConflictUpdate(
          UserMetricsCompanion.insert(
            userId: 'guest',
            sex: 'female',
            birthYear: 1990,
            heightCm: 165,
            weightKg: 60,
            activityLevel: 'moderate',
            updatedAt: DateTime(2026, 8, 14),
          ),
        );

    final rows = await db.select(db.userMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.targetWeightKg, isNull);
  });

  test('meal_entries.portionGrams nullable ve varsayilan null', () async {
    await db
        .into(db.mealEntries)
        .insert(
          MealEntriesCompanion.insert(
            id: 'm1',
            userId: 'guest',
            mealName: 'Test',
            mealType: 'lunch',
            capturedAt: DateTime(2026, 8, 14),
          ),
        );

    final row = await db.select(db.mealEntries).getSingle();
    expect(row.portionGrams, isNull);
  });
}
