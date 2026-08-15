import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_remote_datasource.dart';
import 'package:nutrilens/features/meals/data/services/meal_sync_service.dart';
import 'package:nutrilens/features/meals/data/services/meal_thumbnail_service.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/product/data/models/nutriments_dto.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

class _MockMealRemoteDataSource extends Mock implements MealRemoteDataSource {}

void main() {
  late AppDatabase db;
  late MealLocalDataSource local;
  late _MockMealRemoteDataSource remote;
  late MealSyncService service;

  const userId = 'user-1';
  const mealId = 'meal-1';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = MealLocalDataSourceImpl(db);
    remote = _MockMealRemoteDataSource();
    service = MealSyncService(local, remote, const MealThumbnailService());
  });

  tearDown(() => db.close());

  Map<String, dynamic> cloudRow({int? portionGrams, required DateTime updatedAt}) {
    return {
      'id': mealId,
      'user_id': userId,
      'meal_name': 'Tavuk göğsü',
      'brand': 'Ev yapımı',
      'meal_type': 'lunch',
      'captured_at': DateTime(2026, 8, 10, 12).toUtc().toIso8601String(),
      'ingredients_text': null,
      'nutriments': NutrimentsDto.toMap(const NutrimentsEntity()),
      'calories': 500.0,
      'hp_score': null,
      'confidence': null,
      'portion_grams': portionGrams,
      'ai_raw_json': null,
      'photo_url': null,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  test(
    'pullAndMerge: yerelde portionGrams dolu, uzaktan bu satirda '
    'portion_grams null gelirse yerel deger korunur (null-ezme korumasi)',
    () async {
      await local.saveMeal(
        MealEntryEntity(
          id: mealId,
          userId: userId,
          mealName: 'Tavuk göğsü',
          mealType: MealType.lunch,
          capturedAt: DateTime(2026, 8, 10, 12),
          portionGrams: 350,
          calories: 500,
          updatedAt: DateTime(2026, 8, 10, 12),
        ),
      );

      // Cloud row is newer (so the merge actually overwrites the local row)
      // but its portion_grams is null — the pre-Task-9 shape of every
      // existing cloud row, since the column didn't exist until now.
      when(() => remote.fetchAll(userId)).thenAnswer(
        (_) async => [
          cloudRow(portionGrams: null, updatedAt: DateTime(2026, 8, 11, 12)),
        ],
      );

      await service.pullAndMerge(userId);

      final merged = await local.getMealById(mealId);
      expect(merged, isNotNull);
      expect(
        merged!.portionGrams,
        350,
        reason:
            'sync silmemeli: uzak satirda portion_grams henuz yoksa yerel '
            'deger cihazdaki dogru gramaji temsil eder',
      );
    },
  );

  test(
    'pullAndMerge: uzaktan gelen portion_grams dolu ise onu kullanir '
    '(gercek bir guncelleme ezilmemeli)',
    () async {
      await local.saveMeal(
        MealEntryEntity(
          id: mealId,
          userId: userId,
          mealName: 'Tavuk göğsü',
          mealType: MealType.lunch,
          capturedAt: DateTime(2026, 8, 10, 12),
          portionGrams: 350,
          calories: 500,
          updatedAt: DateTime(2026, 8, 10, 12),
        ),
      );

      when(() => remote.fetchAll(userId)).thenAnswer(
        (_) async => [
          cloudRow(portionGrams: 420, updatedAt: DateTime(2026, 8, 11, 12)),
        ],
      );

      await service.pullAndMerge(userId);

      final merged = await local.getMealById(mealId);
      expect(merged!.portionGrams, 420);
    },
  );
}
