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
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

class SilentAnalytics extends AnalyticsService {
  SilentAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {}
}

class WaterHarness {
  final AppDatabase db;
  final SharedPreferences prefs;
  final MockNotificationService notifications;

  const WaterHarness(this.db, this.prefs, this.notifications);
}

Future<WaterHarness> pumpWaterWidget(
  WidgetTester tester,
  Widget child, {
  bool permissionGranted = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  registerFallbackValue(<DateTime>[]);
  final notifications = MockNotificationService();
  when(
    () => notifications.requestPermission(),
  ).thenAnswer((_) async => permissionGranted);
  when(() => notifications.cancelWaterReminders()).thenAnswer((_) async {});
  when(
    () => notifications.rescheduleWaterReminders(
      times: any(named: 'times'),
      title: any(named: 'title'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async {});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveUserIdProvider.overrideWithValue('user-1'),
        notificationServiceProvider.overrideWithValue(notifications),
        analyticsServiceProvider.overrideWithValue(SilentAnalytics()),
        waterClockProvider.overrideWithValue(
          () => DateTime(2026, 9, 13, 10, 30),
        ),
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
  return WaterHarness(db, prefs, notifications);
}
