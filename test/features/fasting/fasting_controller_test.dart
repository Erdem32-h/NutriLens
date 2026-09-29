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
import 'package:nutrilens/features/fasting/domain/fasting_protocol.dart';
import 'package:nutrilens/features/fasting/presentation/fasting_actions.dart';
import 'package:nutrilens/features/fasting/presentation/providers/fasting_provider.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../water/water_widget_harness.dart';

String _body(int hours) => 'body-$hours';
const FastingCopy _copy = (title: 'title', body: _body);

void main() {
  late AppDatabase db;
  late MockNotificationService notifications;
  late RecordingAnalytics analytics;
  late DateTime now;

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
        fastingClockProvider.overrideWithValue(() => now),
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
    when(
      () => notifications.scheduleFastingTarget(
        at: any(named: 'at'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    when(() => notifications.cancelFastingTarget()).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  test('start: oruc satiri eklenir, hedef bildirimi startedAt+target icin '
      'kurulur, if_fast_started yollanir', () async {
    final c = await makeContainer();

    final started = await c.read(fastingControllerProvider).start(_copy);

    expect(started, isTrue);
    final active = await c.read(activeFastProvider.future);
    expect(active, isNotNull);
    expect(active!.startedAt, now);
    expect(active.targetMinutes, FastingProtocol.p16_8.fastMinutes);

    verify(
      () => notifications.scheduleFastingTarget(
        at: now.add(const Duration(minutes: 16 * 60)),
        title: 'title',
        body: 'body-16',
      ),
    ).called(1);
    expect(analytics.names, contains(FunnelEvents.ifFastStarted));
    expect(analytics.props[FunnelEvents.ifFastStarted]!['protocol'], '16:8');
  });

  test('start_ramazanda_reddedilir: Ramazan acik ve icindeyken start false '
      'doner, satir eklenmez', () async {
    now = DateTime(2027, 2, 10, 12);
    final c = await makeContainer();
    await c
        .read(ramadanSettingsProvider.notifier)
        .setLocation(lat: 39.9334, lng: 32.8597, label: 'Ankara');
    await c.read(ramadanSettingsProvider.notifier).setEnabled(true);

    final started = await c.read(fastingControllerProvider).start(_copy);

    expect(started, isFalse);
    expect(await c.read(activeFastProvider.future), isNull);
    verifyNever(
      () => notifications.scheduleFastingTarget(
        at: any(named: 'at'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });

  test('start: kullanici yoksa false doner, hicbir sey planlanmaz', () async {
    final c = await makeContainer(userId: null);

    final started = await c.read(fastingControllerProvider).start(_copy);

    expect(started, isFalse);
    verifyNever(
      () => notifications.scheduleFastingTarget(
        at: any(named: 'at'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });

  test('start: gece boyunca acik kalan uygulama (onResume cagrilmadan) '
      'Ramazan gunune girince engellenir — blocked provider cache '
      'yaniltmaz', () async {
    now = DateTime(2027, 2, 7, 12); // Ramazan'dan (8 Sub) bir gun once
    final c = await makeContainer();
    await c
        .read(ramadanSettingsProvider.notifier)
        .setLocation(lat: 39.9334, lng: 32.8597, label: 'Ankara');
    await c.read(ramadanSettingsProvider.notifier).setEnabled(true);
    expect(c.read(fastingBlockedByRamadanProvider), isFalse);

    // Saat Ramazan'in icine ilerler ama onResume() hic cagrilmaz (uygulama
    // arka planda degil, sadece gece boyunca acik kalmis).
    now = DateTime(2027, 2, 10, 12);

    final started = await c.read(fastingControllerProvider).start(_copy);

    expect(started, isFalse);
  });

  test('start iki kez ust uste: ikincisi false doner', () async {
    final c = await makeContainer();
    expect(await c.read(fastingControllerProvider).start(_copy), isTrue);

    final second = await c.read(fastingControllerProvider).start(_copy);

    expect(second, isFalse);
  });

  test('end: bildirimi iptal eder, tamamlanma durumunu ve suresini dogru '
      'yollar', () async {
    final c = await makeContainer();
    await c.read(fastingControllerProvider).start(_copy);
    now = now.add(const Duration(hours: 17)); // hedefi (16sa) gecti

    await c.read(fastingControllerProvider).end(source: 'button');

    verify(() => notifications.cancelFastingTarget()).called(1);
    expect(await c.read(activeFastProvider.future), isNull);
    final props = analytics.props[FunnelEvents.ifFastEnded]!;
    expect(props['completed'], isTrue);
    expect(props['minutes'], 17 * 60);
    expect(props['source'], 'button');
  });

  test('end: aktif oruc yoksa hicbir sey yapmaz', () async {
    final c = await makeContainer();

    await c.read(fastingControllerProvider).end(source: 'button');

    verifyNever(() => notifications.cancelFastingTarget());
    expect(analytics.names, isNot(contains(FunnelEvents.ifFastEnded)));
  });

  test('setProtocol_aktif_oruc_varken_degismez', () async {
    final c = await makeContainer();
    await c.read(fastingControllerProvider).start(_copy);

    await c.read(fastingControllerProvider).setProtocol(FastingProtocol.omad);

    expect(c.read(fastingProtocolProvider), FastingProtocol.p16_8);
  });

  test('setProtocol: aktif oruc yokken degisir ve izlenir', () async {
    final c = await makeContainer();

    await c.read(fastingControllerProvider).setProtocol(FastingProtocol.omad);

    expect(c.read(fastingProtocolProvider), FastingProtocol.omad);
    expect(analytics.names, contains(FunnelEvents.ifProtocolChanged));
  });

  test('onResume_aktif_orucun_bildirimini_yeniden_kurar', () async {
    final c = await makeContainer();
    await c.read(fastingControllerProvider).start(_copy);
    // Clears the call `start()` itself made, so the verify below can only
    // be satisfied by a call from `onResume` — without this the assertion
    // would pass even if `onResume` scheduled nothing at all.
    clearInteractions(notifications);

    await c.read(fastingControllerProvider).onResume(_copy);

    verify(
      () => notifications.scheduleFastingTarget(
        at: now.add(const Duration(minutes: 16 * 60)),
        title: 'title',
        body: 'body-16',
      ),
    ).called(1);
  });

  test('onResume: aktif oruc yoksa hicbir bildirim planlanmaz', () async {
    final c = await makeContainer();

    await c.read(fastingControllerProvider).onResume(_copy);

    verifyNever(
      () => notifications.scheduleFastingTarget(
        at: any(named: 'at'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
    // Stale alert (guest discard / account switch) must not linger.
    verify(() => notifications.cancelFastingTarget()).called(1);
  });

  test('onResume: hedef gecmisse yeni bildirim planlanmaz', () async {
    final c = await makeContainer();
    await c.read(fastingControllerProvider).start(_copy);
    now = now.add(const Duration(hours: 17));

    await c.read(fastingControllerProvider).onResume(_copy);

    // Only the call made by start() itself — none from onResume.
    verify(
      () => notifications.scheduleFastingTarget(
        at: any(named: 'at'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).called(1);
  });

  test('end: iki es zamanli cagri tek if_fast_ended uretir', () async {
    final c = await makeContainer();
    await c.read(fastingControllerProvider).start(_copy);
    now = now.add(const Duration(hours: 17));

    final ctrl = c.read(fastingControllerProvider);
    await Future.wait([ctrl.end(source: 'button'), ctrl.end(source: 'button')]);

    expect(
      analytics.names.where((n) => n == FunnelEvents.ifFastEnded),
      hasLength(1),
    );
  });

  test(
    'veri silme: satirlar silinip providerlar invalidate edilince aktif '
    'oruc null okunur (profile_screen ayni invalidate setini calistirir)',
    () async {
      final c = await makeContainer();
      await c.read(fastingControllerProvider).start(_copy);
      expect(await c.read(activeFastProvider.future), isNotNull);

      await db.delete(db.fastingSessions).go();
      c
        ..invalidate(activeFastProvider)
        ..invalidate(fastingHistoryProvider)
        ..invalidate(fastingProtocolProvider);

      expect(await c.read(activeFastProvider.future), isNull);
      expect(await c.read(fastingHistoryProvider.future), isEmpty);
    },
  );
}
