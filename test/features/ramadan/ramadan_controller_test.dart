import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/ramadan/domain/fasting_times.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_schedule.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:nutrilens/features/ramadan/presentation/ramadan_actions.dart';
import 'package:nutrilens/features/water/domain/water_reminder_schedule.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../water/water_widget_harness.dart';

String _sahurBody(DateTime imsak) => 'sb';

const RamadanCopy _copy = (
  sahurTitle: 'st',
  sahurBody: _sahurBody,
  iftarTitle: 'it',
  iftarBody: 'ib',
);
const WaterReminderCopy _waterCopy = (title: 'wt', body: 'wb');

// Ankara — matches the coordinates used in fasting_times_test.dart and
// ramadan_schedule_test.dart so the expected times line up: 8 Feb iftar
// ~18:23, so the first Ramadan water slot (iftar + 30) is ~18:53.
const _lat = 39.9334;
const _lng = 32.8597;
const _label = 'Ankara';
const _plate = 6;

void main() {
  late AppDatabase db;
  late MockNotificationService notifications;
  late RecordingAnalytics analytics;
  late DateTime now;

  setUpAll(() => registerFallbackValue(<RamadanNotification>[]));

  Future<ProviderContainer> makeContainer({String? userId = 'user-1'}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveUserIdProvider.overrideWithValue(userId),
        notificationServiceProvider.overrideWithValue(notifications),
        analyticsServiceProvider.overrideWithValue(analytics),
        waterClockProvider.overrideWithValue(() => now),
        ramadanClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = MockNotificationService();
    analytics = RecordingAnalytics();
    now = DateTime(2027, 2, 8, 12);
    when(() => notifications.requestPermission()).thenAnswer((_) async => true);
    // Default: exact alarms already granted, so enable() never needs to ask.
    // Tests for the D3 permission-request path override this.
    when(() => notifications.canScheduleExact()).thenAnswer((_) async => true);
    when(() => notifications.requestExactAlarms()).thenAnswer((_) async {});
    when(() => notifications.cancelWaterReminders()).thenAnswer((_) async {});
    when(
      () => notifications.rescheduleWaterReminders(
        times: any(named: 'times'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.cancelRamadanNotifications(),
    ).thenAnswer((_) async {});
    when(
      () => notifications.rescheduleRamadanNotifications(
        items: any(named: 'items'),
        sahurTitle: any(named: 'sahurTitle'),
        sahurBody: any(named: 'sahurBody'),
        iftarTitle: any(named: 'iftarTitle'),
        iftarBody: any(named: 'iftarBody'),
      ),
    ).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  test(
    'enable 8 Sub 12:00: iftar 3010 planlanir, su acikken Ramazan slotlariyla, '
    'analitik location_source ile yollanir',
    () async {
      final c = await makeContainer();
      await c.read(waterSettingsProvider.notifier).setReminderEnabled(true);

      await c.read(ramadanControllerProvider).enable(
        lat: _lat,
        lng: _lng,
        label: _label,
        plate: _plate,
        source: 'city',
        copy: _copy,
        waterCopy: _waterCopy,
      );

      final items =
          verify(
                () => notifications.rescheduleRamadanNotifications(
                  items: captureAny(named: 'items'),
                  sahurTitle: 'st',
                  sahurBody: _sahurBody,
                  iftarTitle: 'it',
                  iftarBody: 'ib',
                ),
              ).captured.last
              as List<RamadanNotification>;
      expect(items.any((n) => n.id == 3010), isTrue);

      final times =
          verify(
                () => notifications.rescheduleWaterReminders(
                  times: captureAny(named: 'times'),
                  title: 'wt',
                  body: 'wb',
                ),
              ).captured.last
              as List<DateTime>;
      expect(times.first, DateTime(2027, 2, 8, 18, 53));

      expect(analytics.names, contains(FunnelEvents.ramadanEnabled));
    },
  );

  test(
    'enable: canScheduleExact false ise requestExactAlarms cagirilir (D3)',
    () async {
      when(
        () => notifications.canScheduleExact(),
      ).thenAnswer((_) async => false);
      final c = await makeContainer();

      await c.read(ramadanControllerProvider).enable(
        lat: _lat,
        lng: _lng,
        label: _label,
        plate: _plate,
        source: 'city',
        copy: _copy,
        waterCopy: _waterCopy,
      );

      verify(() => notifications.requestExactAlarms()).called(1);
    },
  );

  test(
    'enable: canScheduleExact true ise requestExactAlarms cagirilmaz (D3)',
    () async {
      // canScheduleExact -> true is the setUp() default.
      final c = await makeContainer();

      await c.read(ramadanControllerProvider).enable(
        lat: _lat,
        lng: _lng,
        label: _label,
        plate: _plate,
        source: 'city',
        copy: _copy,
        waterCopy: _waterCopy,
      );

      verifyNever(() => notifications.requestExactAlarms());
    },
  );

  test('su hatirlaticisi kapali + mod acik: bildirim iptal edilir, su planlanmaz', () async {
    final c = await makeContainer();

    await c.read(ramadanControllerProvider).enable(
      lat: _lat,
      lng: _lng,
      label: _label,
      source: 'gps',
      copy: _copy,
      waterCopy: _waterCopy,
    );

    verify(() => notifications.cancelWaterReminders()).called(1);
    verifyNever(
      () => notifications.rescheduleWaterReminders(
        times: any(named: 'times'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });

  test(
    'teklif penceresinde 7 Sub 20:00 etkinlestirme: 8 Subat sahur (3001) ve '
    'iftar (3011) planlanir, 7 Subat icin hic yok; su bugun normal, yarin '
    'Ramazan slotlari',
    () async {
      now = DateTime(2027, 2, 7, 20);
      final c = await makeContainer();
      await c.read(waterSettingsProvider.notifier).setReminderEnabled(true);

      await c.read(ramadanControllerProvider).enable(
        lat: _lat,
        lng: _lng,
        label: _label,
        source: 'city',
        copy: _copy,
        waterCopy: _waterCopy,
      );

      final items =
          verify(
                () => notifications.rescheduleRamadanNotifications(
                  items: captureAny(named: 'items'),
                  sahurTitle: 'st',
                  sahurBody: _sahurBody,
                  iftarTitle: 'it',
                  iftarBody: 'ib',
                ),
              ).captured.last
              as List<RamadanNotification>;
      final ids = items.map((n) => n.id).toList();
      expect(ids, containsAll([3001, 3011]));
      expect(ids, isNot(contains(3000)));
      expect(ids, isNot(contains(3010)));
      expect(items.every((n) => !n.at.isBefore(DateTime(2027, 2, 8))), isTrue);

      final times =
          verify(
                () => notifications.rescheduleWaterReminders(
                  times: captureAny(named: 'times'),
                  title: 'wt',
                  body: 'wb',
                ),
              ).captured.last
              as List<DateTime>;
      expect(times.where((d) => d.day == 7), [DateTime(2027, 2, 7, 21)]);
      expect(times.where((d) => d.day == 8).first, DateTime(2027, 2, 8, 18, 53));
    },
  );

  test(
    'son gun 8 Mart 20:00: 9 Mart (Bayram) icin bildirim yok, 9 Mart suyu '
    'normal saatlerde, bugunun suyu iftar sonrasi',
    () async {
      now = DateTime(2027, 3, 8, 20);
      final c = await makeContainer();
      await c.read(waterSettingsProvider.notifier).setReminderEnabled(true);

      await c.read(ramadanControllerProvider).enable(
        lat: _lat,
        lng: _lng,
        label: _label,
        source: 'city',
        copy: _copy,
        waterCopy: _waterCopy,
      );

      final items =
          verify(
                () => notifications.rescheduleRamadanNotifications(
                  items: captureAny(named: 'items'),
                  sahurTitle: 'st',
                  sahurBody: _sahurBody,
                  iftarTitle: 'it',
                  iftarBody: 'ib',
                ),
              ).captured.last
              as List<RamadanNotification>;
      expect(items, isEmpty);

      final times =
          verify(
                () => notifications.rescheduleWaterReminders(
                  times: captureAny(named: 'times'),
                  title: 'wt',
                  body: 'wb',
                ),
              ).captured.last
              as List<DateTime>;
      final iftar = fastingTimes(DateTime(2027, 3, 8), _lat, _lng).iftar;
      final expectedToday = [
        for (
          var slot = iftar.add(const Duration(minutes: 30));
          slot.hour * 60 + slot.minute <= 23 * 60 + 30 && slot.day == 8;
          slot = slot.add(const Duration(hours: 2))
        )
          if (slot.isAfter(now)) slot,
      ];
      expect(times.where((d) => d.day == 8), expectedToday);
      expect(times.where((d) => d.day == 9), [
        for (final h in waterReminderHours) DateTime(2027, 3, 9, h),
      ]);
    },
  );

  test(
    'onResume 15 Mart: mod otomatik kapanir, Ramazan bildirimleri iptal edilir, '
    'su normal saatlere doner',
    () async {
      final c = await makeContainer();
      await c.read(ramadanSettingsProvider.notifier).setLocation(
        lat: _lat,
        lng: _lng,
        label: _label,
        plate: _plate,
      );
      await c.read(ramadanSettingsProvider.notifier).setEnabled(true);
      await c.read(waterSettingsProvider.notifier).setReminderEnabled(true);

      now = DateTime(2027, 3, 15, 10, 30);
      await c.read(ramadanControllerProvider).onResume(_copy, _waterCopy);

      expect(c.read(ramadanSettingsProvider).enabled, isFalse);
      verify(() => notifications.cancelRamadanNotifications()).called(1);

      final times =
          verify(
                () => notifications.rescheduleWaterReminders(
                  times: captureAny(named: 'times'),
                  title: 'wt',
                  body: 'wb',
                ),
              ).captured.last
              as List<DateTime>;
      expect(
        times,
        waterReminderTimes(
          now: now,
          lastGlassAt: null,
          glassesToday: 0,
          goal: 10,
        ),
      );
    },
  );

  test(
    'sicak resume: 6 Subat etkinlestirip saati 8 Subata almak eski '
    'fasting degerlerini birakmaz',
    () async {
      now = DateTime(2027, 2, 6, 10, 30);
      final c = await makeContainer();
      await c.read(waterSettingsProvider.notifier).setReminderEnabled(true);
      await c.read(ramadanControllerProvider).enable(
        lat: _lat,
        lng: _lng,
        label: _label,
        source: 'city',
        copy: _copy,
        waterCopy: _waterCopy,
      );
      // Sicak resume: uygulama kapanmadan saat degisir (6 -> 8 Subat).
      now = DateTime(2027, 2, 8, 12);
      await c.read(ramadanControllerProvider).onResume(_copy, _waterCopy);

      final items =
          verify(
                () => notifications.rescheduleRamadanNotifications(
                  items: captureAny(named: 'items'),
                  sahurTitle: 'st',
                  sahurBody: _sahurBody,
                  iftarTitle: 'it',
                  iftarBody: 'ib',
                ),
              ).captured.last
              as List<RamadanNotification>;
      expect(items.any((n) => n.id == 3010), isTrue);

      final times =
          verify(
                () => notifications.rescheduleWaterReminders(
                  times: captureAny(named: 'times'),
                  title: 'wt',
                  body: 'wb',
                ),
              ).captured.last
              as List<DateTime>;
      expect(times.first, DateTime(2027, 2, 8, 18, 53));
    },
  );

  test(
    'mod acik, konum silinmis: reschedule hicbir sey planlamaz ve firlatmaz',
    () async {
      final c = await makeContainer();
      await c.read(ramadanSettingsProvider.notifier).setEnabled(true);

      await expectLater(
        c.read(ramadanControllerProvider).reschedule(_copy),
        completes,
      );

      verify(() => notifications.cancelRamadanNotifications()).called(1);
      verifyNever(
        () => notifications.rescheduleRamadanNotifications(
          items: any(named: 'items'),
          sahurTitle: any(named: 'sahurTitle'),
          sahurBody: any(named: 'sahurBody'),
          iftarTitle: any(named: 'iftarTitle'),
          iftarBody: any(named: 'iftarBody'),
        ),
      );
    },
  );

  test('onResume bildirim izni durumunu tazeler', () async {
    var permitted = false;
    when(
      () => notifications.notificationsPermitted(),
    ).thenAnswer((_) async => permitted);
    final c = await makeContainer();
    expect(await c.read(notificationsPermittedProvider.future), isFalse);

    permitted = true; // user turned notifications on in OS Settings
    await c.read(ramadanControllerProvider).onResume(_copy, _waterCopy);

    expect(await c.read(notificationsPermittedProvider.future), isTrue);
  });

  test('disable: Ramazan idleri iptal eder, su normal saatlere doner', () async {
    final c = await makeContainer();
    await c.read(ramadanSettingsProvider.notifier).setLocation(
      lat: _lat,
      lng: _lng,
      label: _label,
      plate: _plate,
    );
    await c.read(ramadanSettingsProvider.notifier).setEnabled(true);
    await c.read(waterSettingsProvider.notifier).setReminderEnabled(true);

    await c.read(ramadanControllerProvider).disable(_waterCopy);

    expect(c.read(ramadanSettingsProvider).enabled, isFalse);
    verify(() => notifications.cancelRamadanNotifications()).called(1);

    final times =
        verify(
              () => notifications.rescheduleWaterReminders(
                times: captureAny(named: 'times'),
                title: 'wt',
                body: 'wb',
              ),
            ).captured.last
            as List<DateTime>;
    expect(
      times,
      waterReminderTimes(now: now, lastGlassAt: null, glassesToday: 0, goal: 10),
    );
  });
}
