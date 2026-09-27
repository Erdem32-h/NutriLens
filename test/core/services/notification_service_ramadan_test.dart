import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_schedule.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

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
          (id: 3001, at: DateTime(2099, 9, 13, 4, 30), kind: RamadanNotificationKind.sahur),
          (id: 3011, at: DateTime(2099, 9, 13, 18, 45), kind: RamadanNotificationKind.iftar),
        ],
        sahurTitle: 'Sahur Vakti',
        sahurBody: 'Sahura {min} dakika kaldi',
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
        (id: 3000, at: past, kind: RamadanNotificationKind.sahur),
        (id: 3010, at: future, kind: RamadanNotificationKind.iftar),
      ],
      sahurTitle: 'Sahur',
      sahurBody: 'Sahura {min} dakika kaldi',
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
        (id: 3001, at: DateTime(2099, 9, 13, 4, 30), kind: RamadanNotificationKind.sahur),
        (id: 3011, at: DateTime(2099, 9, 13, 18, 45), kind: RamadanNotificationKind.iftar),
      ],
      sahurTitle: 'Sahur Vakti',
      sahurBody: 'Sahura {min} dakika kaldi',
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
}
