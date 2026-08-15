import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/services/calorie_target_calculator.dart';
import '../../domain/entities/user_metrics_entity.dart';

abstract interface class UserMetricsLocalDataSource {
  Future<UserMetricsEntity?> get(String userId);
  Future<void> save(UserMetricsEntity metrics);

  /// Misafir satırını gerçek hesaba taşır. Hedef kullanıcıda zaten kayıt
  /// varsa onu KORUR ve yalnızca misafir satırını siler — hesabında ölçü
  /// girmiş biri, misafirken girdiği eski değerlerle ezilmemeli.
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  });

  /// Bir kullanıcının satırını koşulsuz siler. `reassignOwner`'ın kullandığı
  /// aynı silme yolunu paylaşır — misafir devri reddedildiğinde
  /// (`GuestMigrationService.discard`) de bu kullanılır.
  Future<void> deleteFor(String userId);
}

final class UserMetricsLocalDataSourceImpl
    implements UserMetricsLocalDataSource {
  final AppDatabase _db;

  const UserMetricsLocalDataSourceImpl(this._db);

  @override
  Future<UserMetricsEntity?> get(String userId) async {
    final row = await (_db.select(
      _db.userMetrics,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    if (row == null) return null;
    return UserMetricsEntity(
      userId: row.userId,
      sex: BiologicalSex.values.firstWhere(
        (e) => e.name == row.sex,
        orElse: () => BiologicalSex.unspecified,
      ),
      birthYear: row.birthYear,
      heightCm: row.heightCm,
      weightKg: row.weightKg,
      targetWeightKg: row.targetWeightKg,
      activity: ActivityLevel.values.firstWhere(
        (e) => e.name == row.activityLevel,
        orElse: () => ActivityLevel.sedentary,
      ),
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(UserMetricsEntity m) async {
    await _db
        .into(_db.userMetrics)
        .insertOnConflictUpdate(
          UserMetricsCompanion.insert(
            userId: m.userId,
            sex: m.sex.name,
            birthYear: m.birthYear,
            heightCm: m.heightCm,
            weightKg: m.weightKg,
            targetWeightKg: Value(m.targetWeightKg),
            activityLevel: m.activity.name,
            updatedAt: m.updatedAt,
          ),
        );
  }

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) async {
    final existing = await get(toUserId);
    final guestRow = await get(fromUserId);
    if (guestRow != null && existing == null) {
      await save(guestRow.copyWith(userId: toUserId));
    }
    await deleteFor(fromUserId);
  }

  @override
  Future<void> deleteFor(String userId) async {
    await (_db.delete(
      _db.userMetrics,
    )..where((t) => t.userId.equals(userId))).go();
  }
}
