import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/anthropic_ai_service.dart';
import 'package:nutrilens/core/services/gemini_ai_service.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/meals/presentation/providers/meal_provider.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/scanner/presentation/screens/food_result_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../water/water_widget_harness.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _Gemini extends GeminiAiService {
  _Gemini() : super(_MockSupabase());

  @override
  Future<MealAnalysisResult> analyzeMeal(
    String base64Image, {
    String languageCode = 'tr',
    required String deviceHash,
  }) async => const MealAnalysisResult(
    foodName: 'Mercimek corbasi',
    portionGrams: 300,
    nutriments: NutrimentsEntity(energyKcal: 250),
    confidence: 0.9,
    description: 'test',
    rawJson: '{}',
  );
}

Future<void> _drain(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    // Advance fake time too, so route/sheet transitions actually finish.
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Guest value-moment register CTA: after a guest saves a meal, offer an
/// account once — never to signed-in users, never twice, and never in the
/// same save that already opened the full-screen metrics wizard.
void main() {
  const userId = 'guest-cta-user';
  const ctaTitle = 'Öğünün kaydedildi 🎉';
  late Uint8List image;
  late AppDatabase db;
  late RecordingAnalytics analytics;
  late ProviderContainer container;
  late GoRouter router;

  setUpAll(() {
    image = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required bool guest,
    bool metricsSettled = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (metricsSettled) 'metrics_prompt_settled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    analytics = RecordingAnalytics();
    router = GoRouter(
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
        GoRoute(
          path: '/register',
          builder: (_, _) => const Scaffold(body: Text('register-page')),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        geminiAiServiceProvider.overrideWithValue(_Gemini()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        effectiveUserIdProvider.overrideWithValue(userId),
        isGuestProvider.overrideWithValue(guest),
        isPremiumProvider.overrideWithValue(false),
        notificationServiceProvider.overrideWithValue(
          MockNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColorsExtension.light]),
        ),
      ),
    );
  }

  Future<void> saveMeal(WidgetTester tester) async {
    router.push('/food-result');
    await tester.pump();
    await _drain(tester, () => tester.any(find.text('Öğünlere kaydet')));
    await tester.tap(find.text('Öğünlere kaydet'));
    await tester.pump();
  }

  Future<int> mealCount(WidgetTester tester) async => (await tester.runAsync(
    () => container.read(mealLocalDataSourceProvider).getMeals(userId: userId),
  ))!.length;

  testWidgets('misafir ogun kaydedince teklif bir kez cikar, sonra cikmaz', (
    tester,
  ) async {
    await pumpApp(tester, guest: true);
    await saveMeal(tester);
    await _drain(tester, () => tester.any(find.text(ctaTitle)));
    await tester.pump(const Duration(milliseconds: 500)); // sheet slide-in

    expect(find.text(ctaTitle), findsOneWidget);
    expect(await mealCount(tester), 1);
    expect(
      analytics.props[FunnelEvents.registerPromptShown],
      containsPair('trigger', 'meal_saved'),
    );

    await tester.tap(find.text('Şu an değil'));
    await _drain(tester, () => !tester.any(find.byType(FoodResultScreen)));
    expect(find.text('base'), findsOneWidget);
    expect(analytics.names, contains(FunnelEvents.registerPromptDismissed));

    await saveMeal(tester);
    await _drain(tester, () => !tester.any(find.byType(FoodResultScreen)));
    expect(find.text(ctaTitle), findsNothing);
    expect(await mealCount(tester), 2);
  });

  testWidgets('kabul edilince kayit ekranina gider', (tester) async {
    await pumpApp(tester, guest: true);
    await saveMeal(tester);
    await _drain(tester, () => tester.any(find.text(ctaTitle)));
    await tester.pump(const Duration(milliseconds: 500)); // sheet slide-in

    await tester.tap(find.text('Ücretsiz hesap aç'));
    await _drain(tester, () => tester.any(find.text('register-page')));

    expect(find.text('register-page'), findsOneWidget);
    expect(analytics.names, contains(FunnelEvents.registerPromptAccepted));
    expect(await mealCount(tester), 1);
  });

  testWidgets('hesapli kullaniciya teklif cikmaz', (tester) async {
    await pumpApp(tester, guest: false);
    await saveMeal(tester);
    await _drain(tester, () => !tester.any(find.byType(FoodResultScreen)));

    expect(find.text(ctaTitle), findsNothing);
    expect(analytics.names, isNot(contains(FunnelEvents.registerPromptShown)));
  });

  testWidgets('ayni kayitta hedef sihirbazi acildiysa teklif ertelenir', (
    tester,
  ) async {
    // No metrics yet and the prompt not settled → the wizard opens after
    // this save, so the register offer must wait for a later one.
    await pumpApp(tester, guest: true, metricsSettled: false);
    await saveMeal(tester);
    await _drain(
      tester,
      () => analytics.names.contains(FunnelEvents.metricsPromptShown),
    );

    expect(analytics.names, contains(FunnelEvents.metricsPromptShown));
    expect(find.text(ctaTitle), findsNothing);
    expect(analytics.names, isNot(contains(FunnelEvents.registerPromptShown)));
  });
}
