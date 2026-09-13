import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';
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
    'once 2000-2013 iptal edilir, ogun hatirlatmasina (1001) dokunulmaz',
    () async {
      await service.rescheduleWaterReminders(
        times: const [],
        title: 't',
        body: 'b',
      );
      for (var id = 2000; id <= 2013; id++) {
        verify(() => plugin.cancel(id: id)).called(1);
      }
      verifyNever(() => plugin.cancel(id: 1001));
      verifyNever(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      );
    },
  );

  test('her zaman sirali id ile kurulur, duvar saati korunur', () async {
    await service.rescheduleWaterReminders(
      times: [DateTime(2026, 9, 13, 13), DateTime(2026, 9, 14, 9)],
      title: 'Su içme zamanı',
      body: 'b',
    );
    final captured = verify(
      () => plugin.zonedSchedule(
        id: captureAny(named: 'id'),
        title: 'Su içme zamanı',
        body: 'b',
        scheduledDate: captureAny(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      ),
    ).captured;
    expect(captured[0], 2000);
    expect((captured[1] as tz.TZDateTime).hour, 13);
    expect(captured[2], 2001);
    expect((captured[3] as tz.TZDateTime).day, 14);
  });

  test('14ten fazla zaman verilirse yalniz ilk 14 kurulur', () async {
    await service.rescheduleWaterReminders(
      times: [for (var h = 0; h < 20; h++) DateTime(2026, 9, 13, h)],
      title: 't',
      body: 'b',
    );
    verify(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).called(14);
  });

  test('cancelWaterReminders yalniz su idlerini iptal eder', () async {
    await service.cancelWaterReminders();
    verify(() => plugin.cancel(id: any(named: 'id'))).called(14);
    verifyNever(() => plugin.cancel(id: 1001));
  });
}
