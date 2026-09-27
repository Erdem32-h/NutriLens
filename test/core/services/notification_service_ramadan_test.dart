import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_schedule.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class _MockIOSPlugin extends Mock implements IOSFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin plugin;
  late NotificationService service;

  setUpAll(() {
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
  });

  setUp(() {
    plugin = _MockPlugin();
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).thenAnswer((_) async {});
    service = NotificationService(plugin);
  });

  test(
    '2 ogun ile rescheduleRamadanNotifications cagrildiginda, 14 cancel ve 2 zonedSchedule cagilir',
    () async {
      await service.rescheduleRamadanNotifications(
        items: [
          (
            id: 3001,
            at: DateTime(2099, 9, 13, 4, 30),
            kind: RamadanNotificationKind.sahur,
            imsakAt: DateTime(2099, 9, 13, 5, 15),
          ),
          (
            id: 3011,
            at: DateTime(2099, 9, 13, 18, 45),
            kind: RamadanNotificationKind.iftar,
            imsakAt: null,
          ),
        ],
        sahurTitle: 'Sahur Vakti',
        sahurBody: (imsak) => 'Sahura dakika kaldi',
        iftarTitle: 'Iftar Vakti',
        iftarBody: 'Iftar zamani',
      );

      // Verify 14 cancels (3000-3006 and 3010-3016)
      for (var id = 3000; id <= 3006; id++) {
        verify(() => plugin.cancel(id: id)).called(1);
      }
      for (var id = 3010; id <= 3016; id++) {
        verify(() => plugin.cancel(id: id)).called(1);
      }

      // Verify meal reminder is not touched
      verifyNever(() => plugin.cancel(id: 1001));

      // Verify exactly 2 zonedSchedule calls with ids 3001 and 3011
      final capturedIds = verify(
        () => plugin.zonedSchedule(
          id: captureAny(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).captured;

      expect(capturedIds.length, 2);
      expect(capturedIds[0], 3001); // First sahur
      expect(capturedIds[1], 3011); // First iftar
    },
  );

  test('cancelRamadanNotifications 3000-3006 ve 3010-3016 iptal eder', () async {
    await service.cancelRamadanNotifications();

    for (var id = 3000; id <= 3006; id++) {
      verify(() => plugin.cancel(id: id)).called(1);
    }
    for (var id = 3010; id <= 3016; id++) {
      verify(() => plugin.cancel(id: id)).called(1);
    }

    // Meal and water reminders are not touched
    verifyNever(() => plugin.cancel(id: 1001));
    verifyNever(() => plugin.cancel(id: 2000));
  });

  test('gecmiste kalan slot atlanir', () async {
    final past = DateTime(2000, 1, 1, 4, 30);
    final future = DateTime(2099, 9, 13, 4, 30);

    await service.rescheduleRamadanNotifications(
      items: [
        (
          id: 3000,
          at: past,
          kind: RamadanNotificationKind.sahur,
          imsakAt: DateTime(2000, 1, 1, 5, 15),
        ),
        (id: 3010, at: future, kind: RamadanNotificationKind.iftar, imsakAt: null),
      ],
      sahurTitle: 'Sahur',
      sahurBody: (imsak) => 'Sahura dakika kaldi',
      iftarTitle: 'Iftar',
      iftarBody: 'Iftar',
    );

    final capturedIds = verify(
      () => plugin.zonedSchedule(
        id: captureAny(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).captured;

    // Only the future iftar should be scheduled
    expect(capturedIds, [3010]);
  });

  test('sahur ve iftar basliklari dogru kanalda gonderilir', () async {
    await service.rescheduleRamadanNotifications(
      items: [
        (
          id: 3001,
          at: DateTime(2099, 9, 13, 4, 30),
          kind: RamadanNotificationKind.sahur,
          imsakAt: DateTime(2099, 9, 13, 5, 15),
        ),
        (
          id: 3011,
          at: DateTime(2099, 9, 13, 18, 45),
          kind: RamadanNotificationKind.iftar,
          imsakAt: null,
        ),
      ],
      sahurTitle: 'Sahur Vakti',
      sahurBody: (imsak) => 'Sahura dakika kaldi',
      iftarTitle: 'Iftar Vakti',
      iftarBody: 'Iftar zamani',
    );

    final captured = verify(
      () => plugin.zonedSchedule(
        id: captureAny(named: 'id'),
        title: captureAny(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).captured;

    // First call: sahur
    expect(captured[0], 3001);
    expect(captured[1], 'Sahur Vakti');

    // Second call: iftar
    expect(captured[2], 3011);
    expect(captured[3], 'Iftar Vakti');
  });

  test('sahur govdesi o gunun imsak saatini icerir', () async {
    // 8 Feb Ankara imsak — matches the example in device-fix-findings.md.
    final imsak = DateTime(2027, 2, 8, 6, 18);

    await service.rescheduleRamadanNotifications(
      items: [
        (
          id: 3000,
          at: DateTime(2099, 9, 13, 4, 30), // far future so it isn't skipped
          kind: RamadanNotificationKind.sahur,
          imsakAt: imsak,
        ),
      ],
      sahurTitle: 'Sahur',
      sahurBody: (i) =>
          'İmsak ${i.hour.toString().padLeft(2, '0')}:${i.minute.toString().padLeft(2, '0')}. '
          'Sahurda 2 bardak su icmeyi unutma.',
      iftarTitle: 'Iftar',
      iftarBody: 'Iftar',
    );

    final body = verify(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: captureAny(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).captured.single as String;

    expect(body, contains('06:18'));
  });

  group('exact alarm mode (D1/D3)', () {
    test(
      'canScheduleExactNotifications true ise exactAllowWhileIdle kullanilir',
      () async {
        final android = _MockAndroidPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(android);
        when(
          () => android.canScheduleExactNotifications(),
        ).thenAnswer((_) async => true);

        await service.rescheduleRamadanNotifications(
          items: [
            (
              id: 3000,
              at: DateTime(2099, 9, 13, 4, 30),
              kind: RamadanNotificationKind.sahur,
              imsakAt: DateTime(2099, 9, 13, 5, 15),
            ),
          ],
          sahurTitle: 'Sahur',
          sahurBody: (imsak) => 'body',
          iftarTitle: 'Iftar',
          iftarBody: 'Iftar',
        );

        final mode = verify(
          () => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: captureAny(named: 'androidScheduleMode'),
          ),
        ).captured.single;

        expect(mode, AndroidScheduleMode.exactAllowWhileIdle);
      },
    );

    test(
      'canScheduleExactNotifications false ise inexactAllowWhileIdle kullanilir',
      () async {
        final android = _MockAndroidPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(android);
        when(
          () => android.canScheduleExactNotifications(),
        ).thenAnswer((_) async => false);

        await service.rescheduleRamadanNotifications(
          items: [
            (
              id: 3000,
              at: DateTime(2099, 9, 13, 4, 30),
              kind: RamadanNotificationKind.sahur,
              imsakAt: DateTime(2099, 9, 13, 5, 15),
            ),
          ],
          sahurTitle: 'Sahur',
          sahurBody: (imsak) => 'body',
          iftarTitle: 'Iftar',
          iftarBody: 'Iftar',
        );

        final mode = verify(
          () => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: captureAny(named: 'androidScheduleMode'),
          ),
        ).captured.single;

        expect(mode, AndroidScheduleMode.inexactAllowWhileIdle);
      },
    );

    test('canScheduleExact(): Android true doner', () async {
      final android = _MockAndroidPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => android.canScheduleExactNotifications(),
      ).thenAnswer((_) async => true);

      expect(await service.canScheduleExact(), isTrue);
    });

    test('canScheduleExact(): Android yoksa (iOS) false doner', () async {
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(null);

      expect(await service.canScheduleExact(), isFalse);
    });

    test('requestExactAlarms(): Android varsa plugin metodunu cagirir', () async {
      final android = _MockAndroidPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => android.requestExactAlarmsPermission(),
      ).thenAnswer((_) async => true);

      await service.requestExactAlarms();

      verify(() => android.requestExactAlarmsPermission()).called(1);
    });
  });

  group('notificationsPermitted', () {
    test('Android: areNotificationsEnabled true -> true doner', () async {
      final android = _MockAndroidPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => android.areNotificationsEnabled(),
      ).thenAnswer((_) async => true);

      expect(await service.notificationsPermitted(), isTrue);
    });

    test('Android: areNotificationsEnabled false -> false doner', () async {
      final android = _MockAndroidPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => android.areNotificationsEnabled(),
      ).thenAnswer((_) async => false);

      expect(await service.notificationsPermitted(), isFalse);
    });

    test('Android: areNotificationsEnabled null -> false doner', () async {
      final android = _MockAndroidPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(android);
      when(
        () => android.areNotificationsEnabled(),
      ).thenAnswer((_) async => null);

      expect(await service.notificationsPermitted(), isFalse);
    });

    test('iOS: checkPermissions().isEnabled true -> true doner', () async {
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(null);
      final ios = _MockIOSPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(ios);
      when(() => ios.checkPermissions()).thenAnswer(
        (_) async => const NotificationsEnabledOptions(
          isEnabled: true,
          isSoundEnabled: true,
          isAlertEnabled: true,
          isBadgeEnabled: true,
          isProvisionalEnabled: false,
          isCriticalEnabled: false,
          isProvidesAppNotificationSettingsEnabled: false,
        ),
      );

      expect(await service.notificationsPermitted(), isTrue);
    });

    test('iOS: checkPermissions null -> false doner', () async {
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(null);
      final ios = _MockIOSPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(ios);
      when(() => ios.checkPermissions()).thenAnswer((_) async => null);

      expect(await service.notificationsPermitted(), isFalse);
    });

    test(
      'ne Android ne iOS platform implementasyonu yoksa false doner',
      () async {
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(null);
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(null);

        expect(await service.notificationsPermitted(), isFalse);
      },
    );
  });
}
