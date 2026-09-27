import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/location_provider.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

/// Same as `water_widget_harness.dart`'s `RecordingAnalytics`, plus the
/// props each event was tracked with — the water harness's version drops
/// them, but the offer card's `location_source` prop and the enable flow
/// are worth asserting on here.
class RecordingAnalytics extends AnalyticsService {
  RecordingAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  final names = <String>[];
  final events = <(String, Map<String, Object?>)>[];

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {
    names.add(name);
    events.add((name, props));
  }
}

/// Mutable box so `ramadanClockProvider`'s override can be moved mid-test
/// (e.g. 20:00 -> 02:00 across a midnight rollover) without re-pumping —
/// the provider itself is a stable `() => _clock.value` closure, only the
/// boxed value changes.
class _ClockBox {
  DateTime value;
  _ClockBox(this.value);
}

class _PositionBox {
  ({double lat, double lng})? value;
  _PositionBox(this.value);
}

class _BoolBox {
  bool value;
  _BoolBox(this.value);
}

class RamadanHarness {
  final AppDatabase db;
  final SharedPreferences prefs;
  final MockNotificationService notifications;
  final RecordingAnalytics analytics;
  final void Function(DateTime) _setNow;
  final void Function(({double lat, double lng})?) _setPosition;
  final void Function(bool) _setNotificationsPermitted;

  RamadanHarness(
    this.db,
    this.prefs,
    this.notifications,
    this.analytics,
    this._setNow,
    this._setPosition,
    this._setNotificationsPermitted,
  );

  void setNow(DateTime value) => _setNow(value);

  /// Overrides what `currentPositionProvider` resolves to on the next call
  /// — null simulates a denied permission / GPS failure.
  void setPosition(({double lat, double lng})? value) => _setPosition(value);

  /// Overrides what `notifications.notificationsPermitted()` resolves to on
  /// its next call — read lazily, so flipping this after a tap that
  /// invalidates `notificationsPermittedProvider` (see
  /// `RamadanCountdownCard._enableNotifications`) simulates the OS granting
  /// permission mid-test.
  void setNotificationsPermitted(bool value) =>
      _setNotificationsPermitted(value);
}

Future<RamadanHarness> pumpRamadanWidget(
  WidgetTester tester,
  Widget child, {
  DateTime? now,
  ({double lat, double lng})? initialPosition,
  bool notificationsPermitted = true,
  // Untyped like `daily_target_summary_test.dart`'s `extraOverrides`:
  // `Override` comes from `riverpod`, a transitive-only dependency here
  // (not in pubspec.yaml), so it can't be named as an explicit type — the
  // list's element type is inferred from `ProviderScope.overrides` below.
  List overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  registerFallbackValue(<DateTime>[]);
  final notifications = MockNotificationService();
  when(() => notifications.requestPermission()).thenAnswer((_) async => true);
  // Default: exact alarms already granted, so enable() never needs to ask
  // (D3) — tests covering that permission flow override this per-test.
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

  final clock = _ClockBox(now ?? DateTime(2027, 2, 5));
  final position = _PositionBox(initialPosition);
  final permitted = _BoolBox(notificationsPermitted);
  when(
    () => notifications.notificationsPermitted(),
  ).thenAnswer((_) async => permitted.value);
  final analytics = RecordingAnalytics();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveUserIdProvider.overrideWithValue('user-1'),
        notificationServiceProvider.overrideWithValue(notifications),
        analyticsServiceProvider.overrideWithValue(analytics),
        ramadanClockProvider.overrideWithValue(() => clock.value),
        currentPositionProvider.overrideWithValue(() async => position.value),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return RamadanHarness(
    db,
    prefs,
    notifications,
    analytics,
    (value) => clock.value = value,
    (value) => position.value = value,
    (value) => permitted.value = value,
  );
}
