import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/water/data/datasources/water_local_datasource.dart';

void main() {
  late AppDatabase db;
  late WaterLocalDataSource ds;
  final morning = DateTime(2026, 9, 13, 9, 15);
  final noon = DateTime(2026, 9, 13, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = WaterLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  test('ilk bardak satiri hedefle olusturur', () async {
    final day = await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    expect(day.day, '2026-09-13');
    expect(day.glasses, 1);
    expect(day.goalGlasses, 10);
    expect(day.lastGlassAt, morning);
  });

  test(
    'sonraki bardak sayar ve lastGlassAt gunceller, hedef degismez',
    () async {
      await ds.addGlass(userId: 'u1', now: morning, goal: 10);
      final day = await ds.addGlass(userId: 'u1', now: noon, goal: 12);
      expect(day.glasses, 2);
      expect(day.goalGlasses, 10);
      expect(day.lastGlassAt, noon);
    },
  );

  test('cikarma sifirin altina inmez ve lastGlassAt degismez', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    await ds.removeGlass(userId: 'u1', now: noon, goal: 10);
    final day = await ds.removeGlass(userId: 'u1', now: noon, goal: 10);
    expect(day.glasses, 0);
    expect(day.lastGlassAt, morning);
  });

  test('satir yokken cikarma yazmadan sifir doner', () async {
    final day = await ds.removeGlass(userId: 'u1', now: noon, goal: 10);
    expect(day.glasses, 0);
    expect(await db.select(db.waterLogs).get(), isEmpty);
  });

  test('kullanicilar birbirinin gununu gormez', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    expect(await ds.getDay('u2', '2026-09-13'), isNull);
  });

  test('setGoalForDay yalniz var olan satiri gunceller', () async {
    await ds.setGoalForDay(userId: 'u1', day: '2026-09-13', goal: 8);
    expect(await ds.getDay('u1', '2026-09-13'), isNull);
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    await ds.setGoalForDay(userId: 'u1', day: '2026-09-13', goal: 8);
    expect((await ds.getDay('u1', '2026-09-13'))!.goalGlasses, 8);
  });

  test('getRange araliktaki gunleri artan sirada doner', () async {
    for (final d in [11, 13, 9]) {
      await ds.addGlass(userId: 'u1', now: DateTime(2026, 9, d, 10), goal: 10);
    }
    await ds.addGlass(userId: 'u2', now: DateTime(2026, 9, 12, 10), goal: 10);
    final days = await ds.getRange(
      userId: 'u1',
      fromDay: '2026-09-10',
      toDay: '2026-09-13',
    );
    expect(days.map((d) => d.day), ['2026-09-11', '2026-09-13']);
    expect(await ds.countDays('u1'), 3);
  });

  test(
    'reassignOwner cakisan gunde hesabinkini korur, misafiri siler',
    () async {
      await ds.addGlass(
        userId: 'guest',
        now: DateTime(2026, 9, 12, 10),
        goal: 10,
      );
      await ds.addGlass(userId: 'guest', now: morning, goal: 10);
      await ds.addGlass(userId: 'guest', now: noon, goal: 10);
      await ds.addGlass(userId: 'u1', now: morning, goal: 6);

      await ds.reassignOwner(fromUserId: 'guest', toUserId: 'u1');

      expect(await ds.countDays('guest'), 0);
      expect((await ds.getDay('u1', '2026-09-12'))!.glasses, 1);
      final conflict = (await ds.getDay('u1', '2026-09-13'))!;
      expect(conflict.glasses, 1);
      expect(conflict.goalGlasses, 6);
    },
  );

  test('deleteFor yalniz o kullaniciyi siler', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    await ds.addGlass(userId: 'u2', now: morning, goal: 10);
    await ds.deleteFor('u1');
    expect(await ds.countDays('u1'), 0);
    expect(await ds.countDays('u2'), 1);
  });
}
