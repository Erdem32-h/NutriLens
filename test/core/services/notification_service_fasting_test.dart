import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

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
    'gelecekteki at ile id 4000 fasting_reminder kanalinda planlanir',
    () async {
      final future = DateTime(2099, 9, 13, 20, 0);

      await service.scheduleFastingTarget(
        at: future,
        title: 'Oruc Tamamlandi',
        body: '16 saatlik orucunu tamamladin',
      );

      verify(() => plugin.cancel(id: 4000)).called(1);

      // Captured in one verify() call — Invocation.namedArguments order is
      // not guaranteed to match call-site order, so pick each value out by
      // type/content instead of relying on a fixed captured[i] index.
      final captured = verify(
        () => plugin.zonedSchedule(
          id: captureAny(named: 'id'),
          title: captureAny(named: 'title'),
          body: captureAny(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: captureAny(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).captured;

      expect(captured.whereType<int>().single, 4000);
      expect(
        captured.whereType<String>(),
        containsAll(<String>['Oruc Tamamlandi', '16 saatlik orucunu tamamladin']),
      );
      final details = captured.whereType<NotificationDetails>().single;
      expect(details.android?.channelId, 'fasting_reminder');
      expect(details.android?.channelName, 'Oruç Hatırlatma');
    },
  );

  test('gecmiste kalan at hicbir sey planlamaz', () async {
    final past = DateTime(2000, 1, 1, 20, 0);

    await service.scheduleFastingTarget(
      at: past,
      title: 'Oruc Tamamlandi',
      body: '16 saatlik orucunu tamamladin',
    );

    verify(() => plugin.cancel(id: 4000)).called(1);
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
  });

  test('cancelFastingTarget id 4000 iptal eder', () async {
    await service.cancelFastingTarget();

    verify(() => plugin.cancel(id: 4000)).called(1);
  });

  group('exact alarm mode (D1/D3, ramadan ile ayni davranis)', () {
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

        await service.scheduleFastingTarget(
          at: DateTime(2099, 9, 13, 20, 0),
          title: 'title',
          body: 'body',
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

        await service.scheduleFastingTarget(
          at: DateTime(2099, 9, 13, 20, 0),
          title: 'title',
          body: 'body',
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
  });
}
