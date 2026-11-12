import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

/// Without an open event there is no way to tell whether a reminder brings
/// anyone back; this pins which reminder each tap is counted as.
void main() {
  late _MockPlugin plugin;
  late NotificationService service;
  DidReceiveNotificationResponseCallback? onTap;

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
  });

  setUp(() {
    plugin = _MockPlugin();
    onTap = null;
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((inv) async {
      onTap =
          inv.namedArguments[#onDidReceiveNotificationResponse]
              as DidReceiveNotificationResponseCallback?;
      return true;
    });
    when(
      () => plugin.getNotificationAppLaunchDetails(),
    ).thenAnswer((_) async => null);
    service = NotificationService(plugin);
  });

  NotificationResponse tap(int id) => NotificationResponse(
    notificationResponseType: NotificationResponseType.selectedNotification,
    id: id,
  );

  test('kimlik araliklari dogru turu verir', () {
    expect(NotificationService.typeForId(1001), 'meal');
    expect(NotificationService.typeForId(2000), 'water');
    expect(NotificationService.typeForId(2013), 'water');
    expect(NotificationService.typeForId(3000), 'ramadan');
    expect(NotificationService.typeForId(3016), 'ramadan');
    expect(NotificationService.typeForId(4000), 'fasting');
    expect(NotificationService.typeForId(null), 'other');
    expect(NotificationService.typeForId(9), 'other');
  });

  test('uygulama acikken dokunma bir kez turuyle bildirilir', () async {
    final opened = <String>[];
    await service.init(onOpened: opened.add);

    onTap!(tap(2003));

    expect(opened, ['water']);
  });

  test('bildirim uygulamayi baslattiysa acilista bildirilir', () async {
    when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
      (_) async =>
          NotificationAppLaunchDetails(true, notificationResponse: tap(1001)),
    );
    final opened = <String>[];

    await service.init(onOpened: opened.add);

    expect(opened, ['meal']);
  });

  test('bildirimsiz normal acilis bir sey bildirmez', () async {
    when(
      () => plugin.getNotificationAppLaunchDetails(),
    ).thenAnswer((_) async => const NotificationAppLaunchDetails(false));
    final opened = <String>[];

    await service.init(onOpened: opened.add);

    expect(opened, isEmpty);
  });
}
