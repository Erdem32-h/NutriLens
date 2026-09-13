import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../domain/water_day.dart';

abstract interface class WaterLocalDataSource {
  Future<WaterDay?> getDay(String userId, String day);

  /// Upserts today's row: +1 glass, `lastGlassAt = now`. [goal] is only
  /// written when the row is created.
  Future<WaterDay> addGlass({
    required String userId,
    required DateTime now,
    required int goal,
  });

  /// −1 glass, floored at 0. Never creates a row.
  Future<WaterDay> removeGlass({
    required String userId,
    required DateTime now,
    required int goal,
  });

  /// Refreshes the goal snapshot of an existing row; no-op without a row.
  Future<void> setGoalForDay({
    required String userId,
    required String day,
    required int goal,
  });

  /// Inclusive `yyyy-MM-dd` range, ascending. Missing days are absent.
  Future<List<WaterDay>> getRange({
    required String userId,
    required String fromDay,
    required String toDay,
  });

  Future<int> countDays(String userId);

  /// Guest → account. On a same-day conflict the account's row wins; guest
  /// rows are always deleted so they cannot leak to a later guest.
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  });

  Future<void> deleteFor(String userId);
}

final class WaterLocalDataSourceImpl implements WaterLocalDataSource {
  final AppDatabase _db;

  const WaterLocalDataSourceImpl(this._db);

  WaterDay _toEntity(WaterLog row) => WaterDay(
    day: row.day,
    glasses: row.glasses,
    goalGlasses: row.goalGlasses,
    lastGlassAt: row.lastGlassAt,
  );

  Expression<bool> _isDay($WaterLogsTable t, String userId, String day) =>
      t.userId.equals(userId) & t.day.equals(day);

  @override
  Future<WaterDay?> getDay(String userId, String day) async {
    final row = await (_db.select(
      _db.waterLogs,
    )..where((t) => _isDay(t, userId, day))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<WaterDay> addGlass({
    required String userId,
    required DateTime now,
    required int goal,
  }) {
    final day = waterDayKey(now);
    return _db.transaction(() async {
      final existing = await getDay(userId, day);
      if (existing == null) {
        await _db
            .into(_db.waterLogs)
            .insert(
              WaterLogsCompanion.insert(
                userId: userId,
                day: day,
                glasses: const Value(1),
                goalGlasses: goal,
                lastGlassAt: Value(now),
              ),
            );
      } else {
        await (_db.update(
          _db.waterLogs,
        )..where((t) => _isDay(t, userId, day))).write(
          WaterLogsCompanion(
            glasses: Value(existing.glasses + 1),
            lastGlassAt: Value(now),
          ),
        );
      }
      return (await getDay(userId, day))!;
    });
  }

  @override
  Future<WaterDay> removeGlass({
    required String userId,
    required DateTime now,
    required int goal,
  }) {
    final day = waterDayKey(now);
    return _db.transaction(() async {
      final existing = await getDay(userId, day);
      if (existing == null) {
        return WaterDay(day: day, glasses: 0, goalGlasses: goal);
      }
      if (existing.glasses == 0) return existing;
      await (_db.update(_db.waterLogs)..where((t) => _isDay(t, userId, day)))
          .write(WaterLogsCompanion(glasses: Value(existing.glasses - 1)));
      return (await getDay(userId, day))!;
    });
  }

  @override
  Future<void> setGoalForDay({
    required String userId,
    required String day,
    required int goal,
  }) async {
    await (_db.update(_db.waterLogs)..where((t) => _isDay(t, userId, day)))
        .write(WaterLogsCompanion(goalGlasses: Value(goal)));
  }

  @override
  Future<List<WaterDay>> getRange({
    required String userId,
    required String fromDay,
    required String toDay,
  }) async {
    final rows =
        await (_db.select(_db.waterLogs)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.day.isBetweenValues(fromDay, toDay),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.day)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<int> countDays(String userId) async {
    final rows = await (_db.select(
      _db.waterLogs,
    )..where((t) => t.userId.equals(userId))).get();
    return rows.length;
  }

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) {
    return _db.transaction(() async {
      final guestRows = await (_db.select(
        _db.waterLogs,
      )..where((t) => t.userId.equals(fromUserId))).get();
      for (final row in guestRows) {
        await _db
            .into(_db.waterLogs)
            .insert(
              row.copyWith(userId: toUserId),
              mode: InsertMode.insertOrIgnore,
            );
      }
      await deleteFor(fromUserId);
    });
  }

  @override
  Future<void> deleteFor(String userId) async {
    await (_db.delete(
      _db.waterLogs,
    )..where((t) => t.userId.equals(userId))).go();
  }
}
