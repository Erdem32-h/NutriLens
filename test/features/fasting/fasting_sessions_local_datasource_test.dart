import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/fasting/data/fasting_sessions_local_datasource.dart';
import 'package:nutrilens/features/fasting/domain/fasting_session.dart';

void main() {
  late AppDatabase db;
  late FastingSessionsLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = FastingSessionsLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  test('start sonrasi active o oturumu doner', () async {
    final started = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );

    final active = await ds.active('u1');
    expect(active?.id, started.id);
    expect(active?.userId, 'u1');
    expect(active?.targetMinutes, 960);
    expect(active?.endedAt, isNull);
  });

  test('aktif oturum varken ikinci start StateError atar', () async {
    await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );

    expect(
      () => ds.start(
        'u1',
        startedAt: DateTime(2027, 2, 9, 20),
        targetMinutes: 960,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'esZamanli iki start cagrisindan sadece biri kazanir, digeri StateError atar',
    () async {
      final results = await Future.wait<Object>([
        ds
            .start(
              'u1',
              startedAt: DateTime(2027, 2, 8, 20),
              targetMinutes: 960,
            )
            .then<Object>((s) => s)
            .catchError((Object e) => e),
        ds
            .start(
              'u1',
              startedAt: DateTime(2027, 2, 8, 20, 0, 1),
              targetMinutes: 960,
            )
            .then<Object>((s) => s)
            .catchError((Object e) => e),
      ]);

      final errors = results.whereType<StateError>();
      final sessions = results.whereType<FastingSession>();
      expect(errors, hasLength(1));
      expect(sessions, hasLength(1));

      final activeRows =
          await (db.select(
            db.fastingSessions,
          )..where((t) => t.userId.equals('u1') & t.endedAt.isNull())).get();
      expect(activeRows, hasLength(1));
    },
  );

  test('end sonrasi active null, recent icinde gorunur', () async {
    final started = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );
    await ds.end(started.id, DateTime(2027, 2, 9, 12));

    expect(await ds.active('u1'), isNull);
    final recent = await ds.recent('u1');
    expect(recent, hasLength(1));
    expect(recent.first.id, started.id);
    expect(recent.first.endedAt, DateTime(2027, 2, 9, 12));
  });

  test('recent aktif oturumu haric tutar ve endedAt e gore yeniden eskiye siralar', () async {
    final s1 = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 6, 20),
      targetMinutes: 960,
    );
    await ds.end(s1.id, DateTime(2027, 2, 7, 12));

    final s2 = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );
    await ds.end(s2.id, DateTime(2027, 2, 9, 12));

    // Still-active fast started after both.
    await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 10, 20),
      targetMinutes: 960,
    );

    final recent = await ds.recent('u1');
    expect(recent.map((s) => s.id).toList(), [s2.id, s1.id]);
  });

  test('recent limit parametresini uygular', () async {
    for (var day = 1; day <= 5; day++) {
      final s = await ds.start(
        'u1',
        startedAt: DateTime(2027, 2, day, 20),
        targetMinutes: 60,
      );
      await ds.end(s.id, DateTime(2027, 2, day, 21));
    }

    final recent = await ds.recent('u1', limit: 2);
    expect(recent, hasLength(2));
  });

  test('countCompleted hedefe ulasmayan kisa oruclari saymaz', () async {
    final short = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );
    await ds.end(short.id, DateTime(2027, 2, 9, 0)); // 4h < 16h target

    final long = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 9, 20),
      targetMinutes: 960,
    );
    await ds.end(long.id, DateTime(2027, 2, 10, 12)); // 16h >= target

    expect(await ds.countCompleted('u1'), 1);
  });

  test(
    'reassignOwner ikisi de aktifse misafirinki sonlandirilip gecmis olarak tasinir, hesabinki tek aktif kalir',
    () async {
      final guestActive = await ds.start(
        'guest',
        startedAt: DateTime(2027, 2, 8, 20),
        targetMinutes: 960,
      );
      final accountActive = await ds.start(
        'u1',
        startedAt: DateTime(2027, 2, 9, 8),
        targetMinutes: 1080,
      );

      await ds.reassignOwner(fromUserId: 'guest', toUserId: 'u1');

      expect(await ds.active('guest'), isNull);
      final active = await ds.active('u1');
      expect(active?.id, accountActive.id);

      final recent = await ds.recent('u1');
      expect(recent.map((s) => s.id), contains(guestActive.id));
    },
  );

  test(
    'reassignOwner hesapta aktif yoksa misafirin aktif orucunu da oldugu gibi tasir',
    () async {
      final guestActive = await ds.start(
        'guest',
        startedAt: DateTime(2027, 2, 8, 20),
        targetMinutes: 960,
      );

      await ds.reassignOwner(fromUserId: 'guest', toUserId: 'u1');

      expect(await ds.active('guest'), isNull);
      final active = await ds.active('u1');
      expect(active?.id, guestActive.id);
      expect(active?.endedAt, isNull);
    },
  );

  test('reassignOwner sonrasi misafirin satirlari kalmaz', () async {
    final s = await ds.start(
      'guest',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );
    await ds.end(s.id, DateTime(2027, 2, 9, 12));

    await ds.reassignOwner(fromUserId: 'guest', toUserId: 'u1');

    expect(await ds.active('guest'), isNull);
    expect(await ds.recent('guest'), isEmpty);
    expect(await ds.countCompleted('guest'), 0);
  });

  test('deleteFor yalniz o kullaniciyi siler', () async {
    final s1 = await ds.start(
      'u1',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );
    await ds.end(s1.id, DateTime(2027, 2, 9, 12));
    final s2 = await ds.start(
      'u2',
      startedAt: DateTime(2027, 2, 8, 20),
      targetMinutes: 960,
    );
    await ds.end(s2.id, DateTime(2027, 2, 9, 12));

    await ds.deleteFor('u1');

    expect(await ds.recent('u1'), isEmpty);
    expect(await ds.recent('u2'), hasLength(1));
  });
}
