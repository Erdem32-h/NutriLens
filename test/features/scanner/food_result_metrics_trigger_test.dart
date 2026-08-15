import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/anthropic_ai_service.dart';
import 'package:nutrilens/core/services/gemini_ai_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';
import 'package:nutrilens/features/profile/presentation/screens/metrics_wizard_screen.dart';
import 'package:nutrilens/features/scanner/presentation/screens/food_result_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

/// food_result_screen.dart'in _saveMeal sonrasi metrics-sihirbaz
/// tetikleyicisini test eder (Task 8, Step 1).
///
/// Bu test kasitli olarak brief'te "Test:" olarak adi gecen dosyada degil
/// (daily_target_summary_test.dart yalnizca meals_screen ozetini kapsiyor);
/// gorev talimatindaki iki RED kontrolunden biri ("reddettikten sonra
/// sihirbaz acilmaz") bu tetikleyicinin kendisini dogrulayan bir test
/// gerektirdigi icin ayri bir dosyada eklendi.

class MockSupabaseClient extends Mock implements SupabaseClient {}

class _RecordingAnalytics extends AnalyticsService {
  _RecordingAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  final calls = <(String, Map<String, Object?>)>[];

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {
    calls.add((name, props));
  }

  bool wasTracked(String name) => calls.any((c) => c.$1 == name);
}

/// Her zaman basariyla doner — analiz sonucu ekrani Save butonuna kadar
/// hizlica getirmek icin.
class _SucceedingGemini extends GeminiAiService {
  _SucceedingGemini() : super(MockSupabaseClient());

  @override
  Future<MealAnalysisResult> analyzeMeal(
    String base64Image, {
    String languageCode = 'tr',
    required String deviceHash,
  }) async {
    return const MealAnalysisResult(
      foodName: 'Mercimek çorbası',
      portionGrams: 300,
      nutriments: NutrimentsEntity(energyKcal: 250),
      confidence: 0.9,
      description: 'test',
      rawJson: '{}',
    );
  }
}

/// [UserMetricsLocalDataSource.get] her zaman firlar — code review bulgusu
/// olan "tetikleyici hatasi kayit basarisi gibi gorunuyor" senaryosunu
/// tetiklemek icin. `Override` tipi bilerek yazilmiyor (bkz.
/// daily_target_summary_test.dart'taki ayni gerekce) — `extraOverrides`
/// `.cast()` ile hedef tipe donusturuluyor.
class _ThrowingUserMetricsDataSource implements UserMetricsLocalDataSource {
  @override
  Future<UserMetricsEntity?> get(String userId) async {
    throw StateError('Drift sorgusu koptu (test)');
  }

  @override
  Future<void> save(UserMetricsEntity metrics) async {}

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) async {}

  @override
  Future<void> deleteFor(String userId) async {}
}

Widget _subject({
  required _RecordingAnalytics analytics,
  required SharedPreferences prefs,
  required AppDatabase db,
  required Uint8List image,
  required GoRouter router,
  List extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      geminiAiServiceProvider.overrideWithValue(_SucceedingGemini()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      effectiveUserIdProvider.overrideWithValue('trigger-test-user'),
      isPremiumProvider.overrideWithValue(false),
      ...extraOverrides,
    ].cast(),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
    ),
  );
}

GoRouter _routerFor(Uint8List image) => GoRouter(
      initialLocation: '/base',
      routes: [
        GoRoute(
          path: '/base',
          builder: (_, _) => const Scaffold(body: Text('base')),
        ),
        GoRoute(
          path: '/food-result',
          builder: (_, _) => FoodResultScreen(imageBytes: image),
        ),
      ],
    );

/// [prepareMealAnalysisImage] gercek bir isolate'e `compute()` ile gider,
/// `_saveMeal` ise `MealThumbnailService` uzerinden path_provider'a gercek
/// bir platform kanali cagrisi yapar — ikisi de sahte zamanla (`pump()` tek
/// basina) tamamlanmiyor. `meal_analysis_failure_tracking_test.dart` ile
/// ayni gerekce/desen: gercek zaman veren `runAsync` ile bekleniyor.
Future<void> _drain(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _openAndSave(WidgetTester tester, GoRouter router) async {
  router.push('/food-result');
  await tester.pump();
  await _drain(tester, () => tester.any(find.text('Öğünlere kaydet')));

  await tester.tap(find.text('Öğünlere kaydet'));
  // Rota gecis animasyonu tamamlansa da SnackBar'in kendi zamanlayicisi
  // pumpAndSettle'i suresiz beklemeye zorlayabiliyor (gozlemlendi) — bu
  // yuzden pumpAndSettle KULLANILMIYOR; hedef durum `_drain` kosuluyla
  // dogrulaniyor, ardindan tek bir zaman-atlamali pump ile animasyonlar
  // kapatiliyor.
  //
  // 'base' metnini beklemek YANLIS: GoRouter push ile ustune bindigi icin
  // '/base' rotasi zaten en bastan itibaren agacta MOUNTED kalir (Navigator
  // gecmisteki rotalari maintainState=true ile canli tutar) — bu yuzden
  // `find.text('base')` daha _saveMeal hic calismadan bile eslesir ve
  // dongu gercek islemi hic beklemeden aninda cikar (gozlemlendi). Bunun
  // yerine ya sihirbaz acildi ya da FoodResultScreen'in KENDISI kapandi
  // (wizard acilmadan basariyla pop oldu) sinyali kullaniliyor.
  await _drain(
    tester,
    () =>
        tester.any(find.byType(MetricsWizardScreen)) ||
        !tester.any(find.byType(FoodResultScreen)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late Uint8List image;

  setUpAll(() {
    image = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
  });

  setUp(() {
    // _saveMeal → MealThumbnailService._fileFor → path_provider'in
    // 'getApplicationDocumentsDirectory' kanali. Test ortaminda bu kanal
    // icin bir platform implementasyonu KAYITLI DEGIL — handler
    // atanmazsa cagri hicbir zaman ne sonuclanir ne de hata firlatir
    // (gozlemlendi: _saveMeal sonsuza kadar askida kalir). Gercek bir
    // dizin donerek deterministik davranis saglaniyor; MealThumbnailService
    // zaten hatalari yutup null donuyor, o yuzden burada asil onemli olan
    // cagrinin TAMAMLANMASI.
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('food result metrics prompt trigger', () {
    testWidgets(
        'metrics yok ve sihirbaz daha once reddedilmemisse oguen kaydinda acilir',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final analytics = _RecordingAnalytics();
      final router = _routerFor(image);

      await tester.pumpWidget(
        _subject(
          analytics: analytics,
          prefs: prefs,
          db: db,
          image: image,
          router: router,
        ),
      );

      await _openAndSave(tester, router);

      expect(find.byType(MetricsWizardScreen), findsOneWidget);
      expect(analytics.wasTracked(FunnelEvents.metricsPromptShown), isTrue);
      expect(analytics.wasTracked(FunnelEvents.mealAdded), isTrue);
    });

    testWidgets(
        'sihirbaz daha once reddedildiyse (shouldPrompt=false) oguen kaydinda tekrar acilmaz',
        (tester) async {
      // metrics_prompt_settled=true → MetricsPromptStore.shouldPrompt() false
      // döner (bkz. metrics_prompt_store.dart) — kullanıcı daha önce "Şimdi
      // değil" demiş/tamamlamış.
      SharedPreferences.setMockInitialValues({
        'metrics_prompt_settled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final analytics = _RecordingAnalytics();
      final router = _routerFor(image);

      await tester.pumpWidget(
        _subject(
          analytics: analytics,
          prefs: prefs,
          db: db,
          image: image,
          router: router,
        ),
      );

      await _openAndSave(tester, router);

      expect(find.byType(MetricsWizardScreen), findsNothing);
      expect(find.byType(FoodResultScreen), findsNothing);
      expect(find.text('base'), findsOneWidget);
      expect(analytics.wasTracked(FunnelEvents.metricsPromptShown), isFalse);
      expect(analytics.wasTracked(FunnelEvents.mealAdded), isTrue);
    });

    testWidgets(
        'tetikleyici (metrics get()) firlarsa oguen yine de kaydedilmis sayilir ve ekran kapanir',
        (tester) async {
      // Code review bulgusu: tetikleyici mantigi (Drift get() + shouldPrompt())
      // eskiden _saveMeal'in ANA try/catch'ini paylasiyordu. Bu blokta bir
      // hata firlarsa akis disaridaki catch'e dusuyor, "Kaydetme basarisiz"
      // gosteriliyor ve context.pop() hic cagrilmiyordu — oysa oguen zaten
      // basariyla Drift'e yazilmisti (meal_added da gonderilmisti). Kullanici
      // "basarisiz" mesajini gorup tekrar denerse yeni bir uuid ile
      // YINELENEN kayit olusuyordu. Bu test, tetikleyicinin kendi
      // try/catch'ine alinip hatanin yutulmasini dogruluyor: ekran normal
      // sekilde kapanmali, "basarisiz" mesaji GORUNMEMELI.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final analytics = _RecordingAnalytics();
      final router = _routerFor(image);

      await tester.pumpWidget(
        _subject(
          analytics: analytics,
          prefs: prefs,
          db: db,
          image: image,
          router: router,
          extraOverrides: [
            userMetricsLocalDataSourceProvider.overrideWithValue(
              _ThrowingUserMetricsDataSource(),
            ),
          ],
        ),
      );

      await _openAndSave(tester, router);

      // Sihirbaz acilamadi (tetikleyici firladi) ama oguen kaydi ETKILENMEDI:
      // ekran normal basari yoluyla kapandi, "basarisiz" mesaji yok.
      expect(find.byType(MetricsWizardScreen), findsNothing);
      expect(find.byType(FoodResultScreen), findsNothing);
      expect(find.text('base'), findsOneWidget);
      expect(find.text('Kaydetme başarısız'), findsNothing);
      expect(analytics.wasTracked(FunnelEvents.mealAdded), isTrue);
      expect(analytics.wasTracked(FunnelEvents.metricsPromptShown), isFalse);
    });
  });
}
