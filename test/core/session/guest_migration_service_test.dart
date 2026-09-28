import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/services/guest_scan_counter.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/session/guest_migration_service.dart';
import 'package:nutrilens/features/fasting/data/fasting_sessions_local_datasource.dart';
import 'package:nutrilens/features/history/data/datasources/scan_history_local_datasource.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/ramadan/data/fasting_days_local_datasource.dart';
import 'package:nutrilens/features/water/data/datasources/water_local_datasource.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGuestScanCounter extends Mock implements GuestScanCounter {}

void main() {
  late AppDatabase db;
  late UserMetricsLocalDataSource metricsDs;
  late WaterLocalDataSource waterDs;
  late FastingDaysLocalDataSource fastingDs;
  late FastingSessionsLocalDataSource fastingSessionsDs;
  late GuestMigrationService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    metricsDs = UserMetricsLocalDataSourceImpl(db);
    waterDs = WaterLocalDataSourceImpl(db);
    fastingDs = FastingDaysLocalDataSourceImpl(db);
    fastingSessionsDs = FastingSessionsLocalDataSourceImpl(db);
    final counter = _MockGuestScanCounter();
    when(() => counter.reset()).thenAnswer((_) async {});
    service = GuestMigrationService(
      scanDs: ScanHistoryLocalDataSourceImpl(db),
      mealDs: MealLocalDataSourceImpl(db),
      metricsDs: metricsDs,
      waterDs: waterDs,
      fastingDs: fastingDs,
      fastingSessionsDs: fastingSessionsDs,
      supabase: _MockSupabaseClient(),
      counter: counter,
    );
  });

  tearDown(() => db.close());

  test('discard() misafirin olcum verisini de siler — bir sonraki misafir '
      'oturumu baskasinin boy/kilo/yasini devralmamali', () async {
    await metricsDs.save(
      UserMetricsEntity(
        userId: kGuestUserId,
        sex: BiologicalSex.female,
        birthYear: 1990,
        heightCm: 165,
        weightKg: 60,
        activity: ActivityLevel.moderate,
        updatedAt: DateTime(2026, 8, 14),
      ),
    );

    await service.discard();

    expect(await metricsDs.get(kGuestUserId), isNull);
  });

  test('inspectPending su gunlerini sayar ve bos saymaz', () async {
    await waterDs.addGlass(
      userId: kGuestUserId,
      now: DateTime(2026, 9, 13, 10),
      goal: 10,
    );
    final summary = await service.inspectPending();
    expect(summary.waterDayCount, 1);
    expect(summary.isEmpty, isFalse);
  });

  test('migrate su kayitlarini yeni hesaba tasir', () async {
    await waterDs.addGlass(
      userId: kGuestUserId,
      now: DateTime(2026, 9, 13, 10),
      goal: 10,
    );
    await service.migrate(newUserId: 'user-1');
    expect(await waterDs.countDays(kGuestUserId), 0);
    expect((await waterDs.getDay('user-1', '2026-09-13'))!.glasses, 1);
  });

  test('discard misafirin su kayitlarini siler', () async {
    await waterDs.addGlass(
      userId: kGuestUserId,
      now: DateTime(2026, 9, 13, 10),
      goal: 10,
    );
    await service.discard();
    expect(await waterDs.countDays(kGuestUserId), 0);
  });

  test('inspectPending oruc gunlerini sayar ve bos saymaz', () async {
    await fastingDs.setFasted(kGuestUserId, '2027-02-19', true);
    await fastingDs.setFasted(kGuestUserId, '2027-02-20', true);
    final summary = await service.inspectPending();
    expect(summary.fastingDayCount, 2);
    expect(summary.isEmpty, isFalse);
  });

  test('migrate oruc kayitlarini yeni hesaba tasir', () async {
    await fastingDs.setFasted(kGuestUserId, '2027-02-19', true);
    await fastingDs.setFasted(kGuestUserId, '2027-02-20', true);
    await service.migrate(newUserId: 'user-1');
    expect(await fastingDs.countDays(kGuestUserId), 0);
    expect(
      await fastingDs.getDays(
        'user-1',
        from: '2027-02-01',
        toExclusive: '2027-03-01',
      ),
      {'2027-02-19', '2027-02-20'},
    );
  });

  test('discard misafirin oruc kayitlarini siler', () async {
    await fastingDs.setFasted(kGuestUserId, '2027-02-19', true);
    await service.discard();
    expect(await fastingDs.countDays(kGuestUserId), 0);
  });

  test(
    'inspectPending tamamlanmis oruc oturumu sayisini sayar ve bos saymaz',
    () async {
      final s = await fastingSessionsDs.start(
        kGuestUserId,
        startedAt: DateTime(2027, 2, 19, 20),
        targetMinutes: 16 * 60,
      );
      await fastingSessionsDs.end(s.id, DateTime(2027, 2, 20, 12));

      final summary = await service.inspectPending();

      expect(summary.completedFastCount, 1);
      expect(summary.isEmpty, isFalse);
    },
  );

  test('migrate tamamlanmis oruc oturumlarini yeni hesaba tasir', () async {
    final s = await fastingSessionsDs.start(
      kGuestUserId,
      startedAt: DateTime(2027, 2, 19, 20),
      targetMinutes: 16 * 60,
    );
    await fastingSessionsDs.end(s.id, DateTime(2027, 2, 20, 12));

    await service.migrate(newUserId: 'user-1');

    expect(await fastingSessionsDs.countCompleted(kGuestUserId), 0);
    expect(await fastingSessionsDs.countCompleted('user-1'), 1);
  });

  test('discard misafirin oruc oturumu kayitlarini siler', () async {
    await fastingSessionsDs.start(
      kGuestUserId,
      startedAt: DateTime(2027, 2, 19, 20),
      targetMinutes: 16 * 60,
    );

    await service.discard();

    expect(await fastingSessionsDs.active(kGuestUserId), isNull);
  });
}
