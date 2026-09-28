import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../config/drift/app_database.dart';
import '../domain/fasting_session.dart';

abstract interface class FastingSessionsLocalDataSource {
  /// The user's currently running fast, if any.
  Future<FastingSession?> active(String userId);

  /// Starts a new fast. Throws [StateError] if the user already has one
  /// running.
  Future<FastingSession> start(
    String userId, {
    required DateTime startedAt,
    required int targetMinutes,
  });

  Future<void> end(String id, DateTime endedAt);

  /// Ended fasts only, newest `endedAt` first.
  Future<List<FastingSession>> recent(String userId, {int limit = 30});

  /// Ended fasts whose actual duration reached their target.
  Future<int> countCompleted(String userId);

  /// Guest → account, in one transaction. If both already have an active
  /// fast, the guest's is ended (`endedAt = now`) before moving, so it
  /// becomes history and the account's active row stays the only one.
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  });

  Future<void> deleteFor(String userId);
}

final class FastingSessionsLocalDataSourceImpl
    implements FastingSessionsLocalDataSource {
  final AppDatabase _db;

  const FastingSessionsLocalDataSourceImpl(this._db);

  @override
  Future<FastingSession?> active(String userId) async {
    final row =
        await (_db.select(_db.fastingSessions)..where(
              (t) => t.userId.equals(userId) & t.endedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<FastingSession> start(
    String userId, {
    required DateTime startedAt,
    required int targetMinutes,
  }) async {
    if (await active(userId) != null) {
      throw StateError('$userId already has an active fast');
    }
    final id = const Uuid().v4();
    await _db
        .into(_db.fastingSessions)
        .insert(
          FastingSessionsCompanion.insert(
            id: id,
            userId: userId,
            startedAt: startedAt,
            targetMinutes: targetMinutes,
          ),
        );
    return FastingSession(
      id: id,
      userId: userId,
      startedAt: startedAt,
      targetMinutes: targetMinutes,
    );
  }

  @override
  Future<void> end(String id, DateTime endedAt) async {
    await (_db.update(
      _db.fastingSessions,
    )..where((t) => t.id.equals(id))).write(
      FastingSessionsCompanion(endedAt: Value(endedAt)),
    );
  }

  @override
  Future<List<FastingSession>> recent(String userId, {int limit = 30}) async {
    final rows =
        await (_db.select(_db.fastingSessions)
              ..where(
                (t) => t.userId.equals(userId) & t.endedAt.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.endedAt)])
              ..limit(limit))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<int> countCompleted(String userId) async {
    final rows =
        await (_db.select(_db.fastingSessions)..where(
              (t) => t.userId.equals(userId) & t.endedAt.isNotNull(),
            ))
            .get();
    return rows.map(_toDomain).where((s) => s.isCompleted).length;
  }

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) {
    // Sessions keyed by `id` alone (unlike fasting_days' {userId, day} PK),
    // so rows are moved with an UPDATE, not copy+delete — a copy would
    // collide with the still-present original on the same primary key.
    return _db.transaction(() async {
      final guestActive = await active(fromUserId);
      final accountActive = await active(toUserId);
      if (guestActive != null && accountActive != null) {
        await end(guestActive.id, DateTime.now());
      }

      await (_db.update(
        _db.fastingSessions,
      )..where((t) => t.userId.equals(fromUserId))).write(
        FastingSessionsCompanion(userId: Value(toUserId)),
      );
    });
  }

  @override
  Future<void> deleteFor(String userId) async {
    await (_db.delete(
      _db.fastingSessions,
    )..where((t) => t.userId.equals(userId))).go();
  }

  FastingSession _toDomain(FastingSessionRow row) => FastingSession(
    id: row.id,
    userId: row.userId,
    startedAt: row.startedAt,
    targetMinutes: row.targetMinutes,
    endedAt: row.endedAt,
  );
}
