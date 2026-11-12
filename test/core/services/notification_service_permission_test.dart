import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// NUTRILENS-14: two callers asking at once made the plugin throw
/// `permissionRequestInProgress`. Concurrent calls must share one request.
void main() {
  late _MockPlugin plugin;
  late _MockAndroidPlugin android;
  late NotificationService service;

  setUp(() {
    plugin = _MockPlugin();
    android = _MockAndroidPlugin();
    when(
      () => plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >(),
    ).thenReturn(android);
    service = NotificationService(plugin);
  });

  test('es zamanli iki cagri tek sistem istegini paylasir', () async {
    final pending = Completer<bool?>();
    when(
      () => android.requestNotificationsPermission(),
    ).thenAnswer((_) => pending.future);

    final first = service.requestPermission();
    final second = service.requestPermission();
    pending.complete(true);

    expect(await first, isTrue);
    expect(await second, isTrue);
    verify(() => android.requestNotificationsPermission()).called(1);
  });

  test('istek bittikten sonraki cagri yeniden sorar', () async {
    when(
      () => android.requestNotificationsPermission(),
    ).thenAnswer((_) async => false);

    expect(await service.requestPermission(), isFalse);
    expect(await service.requestPermission(), isFalse);
    verify(() => android.requestNotificationsPermission()).called(2);
  });

  test('hata veren istek sonraki cagriyi kilitlemez', () async {
    var calls = 0;
    when(() => android.requestNotificationsPermission()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw StateError('boom');
      return true;
    });

    await expectLater(service.requestPermission(), throwsStateError);
    expect(await service.requestPermission(), isTrue);
  });
}
