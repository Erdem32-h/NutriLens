import 'package:drift/drift.dart';

import '../../../config/drift/app_database.dart';

abstract interface class FastingDaysLocalDataSource {
  /// Half-open `[from, toExclusive)` range of `yyyy-MM-dd` days the user
  /// marked as fasted.
  Future<Set<String>> getDays(
    String userId, {
    required String from,
    required String toExclusive,
  });

  /// [fasted] true inserts (or ignores if already present); false deletes.
  Future<void> setFasted(String userId, String day, bool fasted);

  Future<int> countDays(String userId);

  /// Guest → account. On a same-day conflict the account's row wins (the
  /// day is already fasted either way); guest rows are always deleted so
  /// they cannot leak to a later guest.
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  });

  Future<void> deleteFor(String userId);
}

final class FastingDaysLocalDataSourceImpl
    implements FastingDaysLocalDataSource {
  final AppDatabase _db;

  const FastingDaysLocalDataSourceImpl(this._db);

  @override
  Future<Set<String>> getDays(
    String userId, {
    required String from,
    required String toExclusive,
  }) async {
    final rows =
        await (_db.select(_db.fastingDays)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.day.isBiggerOrEqualValue(from) &
                  t.day.isSmallerThanValue(toExclusive),
            ))
            .get();
    return rows.map((r) => r.day).toSet();
  }

  @override
  Future<void> setFasted(String userId, String day, bool fasted) async {
    if (fasted) {
      await _db
          .into(_db.fastingDays)
          .insert(
            FastingDaysCompanion.insert(userId: userId, day: day),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(_db.fastingDays)..where(
            (t) => t.userId.equals(userId) & t.day.equals(day),
          ))
          .go();
    }
  }

  @override
  Future<int> countDays(String userId) async {
    final rows = await (_db.select(
      _db.fastingDays,
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
        _db.fastingDays,
      )..where((t) => t.userId.equals(fromUserId))).get();
      for (final row in guestRows) {
        await _db
            .into(_db.fastingDays)
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
      _db.fastingDays,
    )..where((t) => t.userId.equals(userId))).go();
  }
}
