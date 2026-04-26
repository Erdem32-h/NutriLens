import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../../../product/data/models/nutriments_dto.dart';
import '../../domain/entities/meal_entry_entity.dart';

abstract interface class MealLocalDataSource {
  Future<void> saveMeal(MealEntryEntity meal);
  Future<List<MealEntryEntity>> getMeals({
    required String userId,
    int limit = 100,
  });
  Future<double> totalCalories({
    required String userId,
    required DateTime from,
    required DateTime to,
  });
  Future<void> deleteMeal(String id);
}

final class MealLocalDataSourceImpl implements MealLocalDataSource {
  final AppDatabase _db;

  const MealLocalDataSourceImpl(this._db);

  @override
  Future<void> saveMeal(MealEntryEntity meal) async {
    try {
      await _db
          .into(_db.mealEntries)
          .insertOnConflictUpdate(
            MealEntriesCompanion.insert(
              id: meal.id,
              userId: meal.userId,
              mealName: meal.mealName,
              mealType: meal.mealType.name,
              capturedAt: meal.capturedAt,
              photoThumbnailPath: Value(meal.photoThumbnailPath),
              brand: Value(meal.brand),
              ingredientsText: Value(meal.ingredientsText),
              nutriments: Value(NutrimentsDto.toJsonString(meal.nutriments)),
              calories: Value(meal.calories),
              hpScore: Value(meal.hpScore),
              confidence: Value(meal.confidence),
              aiRawJson: Value(meal.aiRawJson),
              syncStatus: Value(meal.syncStatus),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } catch (e) {
      throw CacheException('Failed to save meal: $e');
    }
  }

  @override
  Future<List<MealEntryEntity>> getMeals({
    required String userId,
    int limit = 100,
  }) async {
    try {
      final query = _db.select(_db.mealEntries)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.desc(t.capturedAt)])
        ..limit(limit);

      final rows = await query.get();
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw CacheException('Failed to read meals: $e');
    }
  }

  @override
  Future<double> totalCalories({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows =
          await (_db.select(_db.mealEntries)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.capturedAt.isBiggerOrEqualValue(from) &
                    t.capturedAt.isSmallerThanValue(to),
              ))
              .get();
      return rows.fold<double>(0, (sum, row) => sum + row.calories);
    } catch (e) {
      throw CacheException('Failed to summarize meal calories: $e');
    }
  }

  @override
  Future<void> deleteMeal(String id) async {
    try {
      await (_db.delete(_db.mealEntries)..where((t) => t.id.equals(id))).go();
    } catch (e) {
      throw CacheException('Failed to delete meal: $e');
    }
  }

  MealEntryEntity _fromRow(MealEntry row) {
    return MealEntryEntity(
      id: row.id,
      userId: row.userId,
      photoThumbnailPath: row.photoThumbnailPath,
      mealName: row.mealName,
      brand: row.brand,
      mealType: mealTypeFromString(row.mealType),
      capturedAt: row.capturedAt,
      ingredientsText: row.ingredientsText,
      nutriments: NutrimentsDto.fromJsonString(row.nutriments),
      calories: row.calories,
      hpScore: row.hpScore,
      confidence: row.confidence,
      aiRawJson: row.aiRawJson,
      syncStatus: row.syncStatus,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
