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
import 'package:nutrilens/features/profile/data/datasources/user_metrics_remote_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';
import 'package:nutrilens/features/profile/presentation/screens/metrics_wizard_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kaydedilen degeri yakalar — gercek Drift/AppDatabase kurmadan sihirbazin
/// datasource'a ne yolladigini dogrudan gozlemlemek icin. [existing] verilirse
/// "mevcut kayit varsa alanlar dolu acilir" senaryosunu simule eder — gercek
/// datasource'ta oldugu gibi `get()` gercekten async (mikrotask'ta cozulur),
/// boylece build() sirasinda seed etmenin dogurdugu crash riski testte de
/// gercekci sekilde tetiklenir.
class _FakeUserMetricsLocalDataSource implements UserMetricsLocalDataSource {
  _FakeUserMetricsLocalDataSource({this.existing});

  final UserMetricsEntity? existing;
  UserMetricsEntity? saved;

  @override
  Future<UserMetricsEntity?> get(String userId) async => existing;

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

/// Cagri sayisi + son gonderilen entity'yi yakalar — "girisli kullaniciyi
/// yalnizca yerel kayittan sonra ek olarak buluta yazar, misafirde hic ag
/// cagrisi yapmaz" davranisini gercek Supabase kurmadan dogrulamak icin.
class _FakeUserMetricsRemoteDataSource implements UserMetricsRemoteDataSource {
  UserMetricsEntity? upserted;
  int upsertCallCount = 0;

  @override
  Future<void> upsert(UserMetricsEntity m) async {
    upsertCallCount++;
    upserted = m;
  }
}

/// Her cagriyi patlatir — "uzak yazma basarisiz olursa kullaniciya hata
/// gostermez, sihirbaz normal akisina devam eder" davranisini dogrulamak
/// icin.
class _ThrowingUserMetricsRemoteDataSource
    implements UserMetricsRemoteDataSource {
  @override
  Future<void> upsert(UserMetricsEntity m) async {
    throw Exception('network down');
  }
}

/// Bir alanin gorunen metnini okur. Key, alani saran `_NumberField`
/// widget'ina verilmis (metric*Field), gercek `TextFormField`'a degil —
/// bu yuzden `find.byKey` dogrudan `TextFormField`'a cast edilemez, once
/// descendant olarak asagi inmek gerekiyor.
String _fieldText(WidgetTester tester, String key) {
  final finder = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextFormField),
  );
  return tester.widget<TextFormField>(finder).controller!.text;
}

Future<_FakeUserMetricsLocalDataSource> _pumpWizard(
  WidgetTester tester, {
  UserMetricsEntity? existingMetrics,
  AppSessionState session = AppSessionState.authenticated,
  UserMetricsRemoteDataSource? remote,
}) async {
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

  final fakeDataSource = _FakeUserMetricsLocalDataSource(
    existing: existingMetrics,
  );

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      analyticsServiceProvider.overrideWithValue(analytics),
      appSessionProvider.overrideWithValue(session),
      effectiveUserIdProvider.overrideWithValue('test-user'),
      userMetricsLocalDataSourceProvider.overrideWithValue(fakeDataSource),
      userMetricsRemoteDataSourceProvider.overrideWithValue(
        remote ?? _FakeUserMetricsRemoteDataSource(),
      ),
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

  testWidgets('mevcut kayit varsa alanlar dolu acilir', (tester) async {
    final existing = UserMetricsEntity(
      userId: 'test-user',
      sex: BiologicalSex.male,
      birthYear: DateTime.now().year - 28,
      heightCm: 182,
      weightKg: 78,
      targetWeightKg: 75,
      activity: ActivityLevel.light,
      updatedAt: DateTime(2026, 1, 1),
    );
    await _pumpWizard(tester, existingMetrics: existing);

    // Cinsiyet onceden "Erkek" olarak seed edilmis olmali: "Devam" butonu
    // hicbir sey secmeden dogrudan basilabilir olur (aksi halde null secim
    // butonu devre disi birakir ve bu tap hicbir sey yapmaz).
    await tester.tap(find.byKey(const Key('metricsSexNext')));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'metricsAgeField'), '28');
    expect(_fieldText(tester, 'metricsHeightField'), '182');
    expect(_fieldText(tester, 'metricsWeightField'), '78');

    await tester.tap(find.byKey(const Key('metricsBodyNext')));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'metricsTargetWeightField'), '75');

    await tester.tap(find.byKey(const Key('metricsTargetNext')));
    await tester.pumpAndSettle();

    // Aktivite onceden "Az hareketli" (light) secilmis olmali.
    await tester.tap(find.byKey(const Key('metricsActivityNext')));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'misafirken tamamlaninca olculer yine de kaydedilir ve /register\'a yonlendirilir',
    (tester) async {
      final fakeDataSource = await _pumpWizard(
        tester,
        session: AppSessionState.guest,
      );

      await tester.tap(find.text('Kadın'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('metricsAgeField')),
        '22',
      );
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '165',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '60',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Şu anki kilomu korumak istiyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsTargetNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Az hareketli'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsActivityNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('metricsFinish')));
      await tester.pumpAndSettle();

      // Yonlendirme kaydin yerine gecmemeli: olcumler yine kaydedilmis
      // olmali, misafir olmak bunu engellememeli.
      final saved = fakeDataSource.saved;
      expect(saved, isNotNull);
      expect(saved!.userId, 'test-user');
      expect(saved.activity, ActivityLevel.light);

      // Router /register'a gitmis olmali.
      expect(find.text('register'), findsOneWidget);
    },
  );

  testWidgets(
    'girisli kullanicida tamamlaninca yerel kayittan sonra buluta da yazilir',
    (tester) async {
      final fakeRemote = _FakeUserMetricsRemoteDataSource();
      await _pumpWizard(
        tester,
        session: AppSessionState.authenticated,
        remote: fakeRemote,
      );

      await tester.tap(find.text('Kadın'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('metricsAgeField')), '31');
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '168',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '62',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Şu anki kilomu korumak istiyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsTargetNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Orta hareketli'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsActivityNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('metricsFinish')));
      await tester.pumpAndSettle();

      expect(fakeRemote.upsertCallCount, 1);
      expect(fakeRemote.upserted?.userId, 'test-user');
      expect(fakeRemote.upserted?.sex, BiologicalSex.female);
      expect(fakeRemote.upserted?.heightCm, 168);
      expect(fakeRemote.upserted?.weightKg, 62);
      expect(fakeRemote.upserted?.activity, ActivityLevel.moderate);
    },
  );

  testWidgets(
    'misafirken tamamlaninca buluta hicbir ag cagrisi yapilmaz',
    (tester) async {
      final fakeRemote = _FakeUserMetricsRemoteDataSource();
      await _pumpWizard(
        tester,
        session: AppSessionState.guest,
        remote: fakeRemote,
      );

      await tester.tap(find.text('Erkek'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('metricsAgeField')), '25');
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '178',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '80',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

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

      expect(fakeRemote.upsertCallCount, 0);
    },
  );

  testWidgets(
    'bulut yazma hata verirse kullaniciya hata gosterilmez, akis normal devam eder',
    (tester) async {
      await _pumpWizard(
        tester,
        session: AppSessionState.authenticated,
        remote: _ThrowingUserMetricsRemoteDataSource(),
      );

      await tester.tap(find.text('Kadın'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsSexNext')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('metricsAgeField')), '29');
      await tester.enterText(
        find.byKey(const Key('metricsHeightField')),
        '170',
      );
      await tester.enterText(
        find.byKey(const Key('metricsWeightField')),
        '58',
      );
      await tester.tap(find.byKey(const Key('metricsBodyNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Şu anki kilomu korumak istiyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsTargetNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Az hareketli'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('metricsActivityNext')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('metricsFinish')));
      await tester.pumpAndSettle();

      // Wizard normalde kapanir (base'e doner) — hata popup'i, snackbar,
      // exception vs. hicbiri gorunmemeli.
      expect(find.text('base'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
