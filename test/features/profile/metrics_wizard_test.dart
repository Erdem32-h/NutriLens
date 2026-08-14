import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/services/device_id_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';
import 'package:nutrilens/features/profile/presentation/screens/metrics_wizard_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kaydedilen degeri yakalar — gercek Drift/AppDatabase kurmadan sihirbazin
/// datasource'a ne yolladigini dogrudan gozlemlemek icin.
class _FakeUserMetricsLocalDataSource implements UserMetricsLocalDataSource {
  UserMetricsEntity? saved;

  @override
  Future<UserMetricsEntity?> get(String userId) async => null;

  @override
  Future<void> save(UserMetricsEntity metrics) async {
    saved = metrics;
  }

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) async {}

  @override
  Future<void> deleteFor(String userId) async {}
}

Future<_FakeUserMetricsLocalDataSource> _pumpWizard(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // flushInterval sifir: flutter_test widget agacindan uzun yasayan bir
  // timer'a izin vermiyor (bkz. onboarding_screen_test.dart, ayni desen).
  final analytics = AnalyticsService(
    client: null,
    deviceId: DeviceIdService(prefs),
    prefs: prefs,
    flushInterval: Duration.zero,
  );
  addTearDown(analytics.dispose);

  final fakeDataSource = _FakeUserMetricsLocalDataSource();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      analyticsServiceProvider.overrideWithValue(analytics),
      appSessionProvider.overrideWithValue(AppSessionState.authenticated),
      effectiveUserIdProvider.overrideWithValue('test-user'),
      userMetricsLocalDataSourceProvider.overrideWithValue(fakeDataSource),
    ],
  );
  addTearDown(container.dispose);

  // Gercek bir GoRouter, gercek uretim sekliyle: sihirbaz kendi baslangic
  // rotasi DEGIL, mevcut bir ekranin ustune push edilir (Task 8'in yapacagi
  // gibi). Sihirbaz kendi rotasi olsaydi, tamamlanma aninda attigi
  // Navigator.pop() go_router'in tum yigitini bosaltip assertion firlatirdi.
  final router = GoRouter(
    initialLocation: '/base',
    routes: [
      GoRoute(
        path: '/base',
        builder: (_, _) => const Scaffold(body: Text('base')),
      ),
      GoRoute(
        path: '/wizard',
        builder: (_, _) => const MetricsWizardScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('register')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/wizard');
  await tester.pumpAndSettle();
  return fakeDataSource;
}

void main() {
  testWidgets(
    '5 adim bastan sona tamamlaninca girilen degerler kaydedilir',
    (tester) async {
      final fakeDataSource = await _pumpWizard(tester);

      // 1) Cinsiyet
      await tester.tap(find.text('Kadın'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      // 2) Vucut
      await tester.enterText(
        find.byKey(const Key('metricsAgeField')),
        '30',
      );
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '175',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '70',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

      // 3) Hedef kilo
      await tester.enterText(
        find.byKey(const Key('metricsTargetWeightField')),
        '65',
      );
      await tester.tap(find.byKey(const Key('metricsTargetNext')));
      await tester.pumpAndSettle();

      // 4) Aktivite
      await tester.tap(find.text('Orta hareketli'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsActivityNext')));
      await tester.pumpAndSettle();

      // 5) Sonuc -> kaydet
      await tester.tap(find.byKey(const Key('metricsFinish')));
      await tester.pumpAndSettle();

      final saved = fakeDataSource.saved;
      expect(saved, isNotNull);
      expect(saved!.userId, 'test-user');
      expect(saved.sex, BiologicalSex.female);
      expect(saved.birthYear, DateTime.now().year - 30);
      expect(saved.heightCm, 175);
      expect(saved.weightKg, 70);
      expect(saved.targetWeightKg, 65);
      expect(saved.activity, ActivityLevel.moderate);
    },
  );

  testWidgets(
    'aralik disi kilo (500) girilince hata metni gorunur ve ileri gidilemez',
    (tester) async {
      await _pumpWizard(tester);

      await tester.tap(find.text('Kadın'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('metricsAgeField')),
        '30',
      );
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '175',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '500',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

      // Kilo icin gecerli aralik 30-300 (bkz. calorie_target_calculator.dart).
      expect(find.text('30-300 arasında bir değer gir'), findsOneWidget);

      // Hedef adimina hic gecmedik: onun basligi ekranda degil, vucut
      // adiminin basligi hala hit-testable (yani gercekten gorunur).
      expect(find.text('Hedef kilon').hitTestable(), findsNothing);
      expect(find.text('Vücut ölçülerin').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    '"kilomu korumak istiyorum" secilince hedef kilo null kaydedilir',
    (tester) async {
      final fakeDataSource = await _pumpWizard(tester);

      await tester.tap(find.text('Erkek'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('metricsAgeField')),
        '40',
      );
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '180',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '85',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

      // Hedef kilo alanini bos birak, korumayi sec: alan formdan cikar,
      // bu yuzden validate() bu adimda hicbir sey dogrulamadan gecer.
      await tester.tap(find.text('Şu anki kilomu korumak istiyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsTargetNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hareketsiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsActivityNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('metricsFinish')));
      await tester.pumpAndSettle();

      final saved = fakeDataSource.saved;
      expect(saved, isNotNull);
      expect(saved!.targetWeightKg, isNull);
      expect(saved.activity, ActivityLevel.sedentary);
    },
  );
}
