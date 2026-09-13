import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'water_widget_harness.dart';

const WaterReminderCopy _copy = (title: 't', body: 'b');

void main() {
  late AppDatabase db;
  late MockNotificationService notifications;
  late RecordingAnalytics analytics;
  late DateTime now;

  setUpAll(() => registerFallbackValue(<DateTime>[]));

  Future<ProviderContainer> makeContainer({
    String? userId = 'user-1',
    bool permission = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    when(
      () => notifications.requestPermission(),
    ).thenAnswer((_) async => permission);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveUserIdProvider.overrideWithValue(userId),
        notificationServiceProvider.overrideWithValue(notifications),
        analyticsServiceProvider.overrideWithValue(analytics),
        waterClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = MockNotificationService();
    analytics = RecordingAnalytics();
    now = DateTime(2026, 9, 13, 10, 30);
    when(() => notifications.cancelWaterReminders()).thenAnswer((_) async {});
    when(
      () => notifications.rescheduleWaterReminders(
        times: any(named: 'times'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  test(
    'bardak ekler, analitik yollar; hatirlatma kapaliyken iptal eder',
    () async {
      final c = await makeContainer();

      final day = await c.read(waterControllerProvider).addGlass(_copy);

      expect(day!.glasses, 1);
      expect((await c.read(waterTodayProvider.future)).glasses, 1);
      expect(analytics.names, [FunnelEvents.waterGlassAdded]);
      verify(() => notifications.cancelWaterReminders()).called(1);
      verifyNever(
        () => notifications.rescheduleWaterReminders(
          times: any(named: 'times'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      );
    },
  );

  test('hatirlatma acikken 10:30 bardagi 11:00i atlatir', () async {
    final c = await makeContainer();
    final controller = c.read(waterControllerProvider);

    expect(await controller.setReminderEnabled(true, _copy), isTrue);
    await controller.addGlass(_copy);

    final times =
        verify(
              () => notifications.rescheduleWaterReminders(
                times: captureAny(named: 'times'),
                title: 't',
                body: 'b',
              ),
            ).captured.last
            as List<DateTime>;
    expect(times.first, DateTime(2026, 9, 13, 13));
    expect(c.read(waterSettingsProvider).reminderEnabled, isTrue);
    expect(analytics.names, contains(FunnelEvents.waterReminderEnabled));
  });

  test('izin reddedilirse false doner ve kapali kalir', () async {
    final c = await makeContainer(permission: false);

    final ok = await c
        .read(waterControllerProvider)
        .setReminderEnabled(true, _copy);

    expect(ok, isFalse);
    expect(c.read(waterSettingsProvider).reminderEnabled, isFalse);
  });

  test('cikarma 0in altina inmez', () async {
    final c = await makeContainer();
    final day = await c.read(waterControllerProvider).removeGlass(_copy);
    expect(day!.glasses, 0);
  });

  test(
    'hedef degisince bugunun satiri ve waterGoalProvider guncellenir',
    () async {
      final c = await makeContainer();
      final controller = c.read(waterControllerProvider);
      await controller.addGlass(_copy);

      await controller.setGoal(8, _copy);

      expect(c.read(waterGoalProvider), 8);
      expect((await c.read(waterTodayProvider.future)).goalGlasses, 8);
    },
  );

  test('kilo yoksa hedef 10', () async {
    final c = await makeContainer();
    expect(await c.read(waterMetricsWeightProvider.future), isNull);
    expect(c.read(waterGoalProvider), 10);
  });

  test(
    'metrics henuz yuklenirken bardak eklenirse kilo bazli hedef yazilir',
    () async {
      await UserMetricsLocalDataSourceImpl(db).save(
        UserMetricsEntity(
          userId: 'user-1',
          sex: BiologicalSex.male,
          birthYear: 1990,
          heightCm: 180,
          weightKg: 70,
          activity: ActivityLevel.moderate,
          updatedAt: DateTime(2026, 8, 14),
        ),
      );
      final c = await makeContainer();

      // Metrics future'i once beklemeden dogrudan bardak ekleniyor —
      // waterGoalProvider.value henuz null olabilecegi pencereyi kapsar.
      final day = await c.read(waterControllerProvider).addGlass(_copy);

      expect(day!.goalGlasses, 12);
    },
  );

  test('hafta 7 gun doner, eksik gunler 0 bardak', () async {
    final c = await makeContainer();
    await c.read(waterControllerProvider).addGlass(_copy);

    final week = await c.read(waterWeekProvider.future);

    expect(week.map((d) => d.day), [
      '2026-09-07',
      '2026-09-08',
      '2026-09-09',
      '2026-09-10',
      '2026-09-11',
      '2026-09-12',
      '2026-09-13',
    ]);
    expect(week.last.glasses, 1);
    expect(week.first.glasses, 0);
  });

  test('oturum yoksa yazmaz ve hatirlatmalari iptal eder', () async {
    final c = await makeContainer(userId: null);

    final day = await c.read(waterControllerProvider).addGlass(_copy);

    expect(day, isNull);
    expect(await db.select(db.waterLogs).get(), isEmpty);
    verify(() => notifications.cancelWaterReminders()).called(1);
  });

  test('oturum yokken cikarma da hatirlatmalari iptal eder', () async {
    final c = await makeContainer(userId: null);

    final day = await c.read(waterControllerProvider).removeGlass(_copy);

    expect(day, isNull);
    verify(() => notifications.cancelWaterReminders()).called(1);
  });
}
