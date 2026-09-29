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
import 'package:nutrilens/features/fasting/domain/fasting_session.dart';
import 'package:nutrilens/features/fasting/presentation/providers/fasting_provider.dart';
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
    await tester.pump();
  }
}

void main() {
  const userId = 'meal-warn-user';
  final now = DateTime(2027, 2, 8, 20);
  late Uint8List image;
  late AppDatabase db;
  late RecordingAnalytics analytics;
  late ProviderContainer container;
  late GoRouter router;

  setUpAll(() {
    image = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
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

  Future<void> pumpScreen(WidgetTester tester, {required bool fasting}) async {
    SharedPreferences.setMockInitialValues({'metrics_prompt_settled': true});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    analytics = RecordingAnalytics();
    final notifications = MockNotificationService();
    when(() => notifications.cancelFastingTarget()).thenAnswer((_) async {});
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
      ],
    );
    container = ProviderContainer(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        geminiAiServiceProvider.overrideWithValue(_Gemini()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        effectiveUserIdProvider.overrideWithValue(userId),
        isPremiumProvider.overrideWithValue(false),
        notificationServiceProvider.overrideWithValue(notifications),
        fastingClockProvider.overrideWithValue(() => now),
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
    if (fasting) {
      await tester.runAsync(
        () => container
            .read(fastingSessionsLocalDataSourceProvider)
            .start(
              userId,
              startedAt: now.subtract(const Duration(hours: 5, minutes: 30)),
              targetMinutes: 960,
            ),
      );
    }
    router.push('/food-result');
    await tester.pump();
    await _drain(tester, () => tester.any(find.text('Öğünlere kaydet')));
    await tester.tap(find.text('Öğünlere kaydet'));
    await tester.pump();
  }

  Future<int> mealCount(WidgetTester tester) async =>
      (await tester.runAsync(
        () =>
            container.read(mealLocalDataSourceProvider).getMeals(userId: userId),
      ))!.length;

  Future<FastingSession?> activeFast(WidgetTester tester) async =>
      (await tester.runAsync<FastingSession?>(
    () => container.read(fastingSessionsLocalDataSourceProvider).active(userId),
  ));

  testWidgets('oruc yokken uyari cikmaz, ogun kaydedilir', (tester) async {
    await pumpScreen(tester, fasting: false);
    await _drain(tester, () => !tester.any(find.byType(FoodResultScreen)));

    expect(find.text('Oruçtasın'), findsNothing);
    expect(await mealCount(tester), 1);
  });

  testWidgets('aktif oruc + vazgec: kayit yok, oruc devam eder', (tester) async {
    await pumpScreen(tester, fasting: true);
    await _drain(tester, () => tester.any(find.text('Oruçtasın')));

    expect(find.text('Oruçtasın'), findsOneWidget);
    expect(find.textContaining('5:30'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FoodResultScreen), findsOneWidget);
    expect(await mealCount(tester), 0);
    expect(await activeFast(tester), isNotNull);
    expect(analytics.names, isNot(contains(FunnelEvents.ifFastEnded)));
  });

  testWidgets('aktif oruc + onayla: oruc biter (meal_save), ogun kaydedilir', (
    tester,
  ) async {
    await pumpScreen(tester, fasting: true);
    await _drain(tester, () => tester.any(find.text('Orucu bitir ve kaydet')));

    await tester.tap(find.text('Orucu bitir ve kaydet'));
    await tester.pump();
    await _drain(tester, () => !tester.any(find.byType(FoodResultScreen)));

    expect(analytics.props[FunnelEvents.ifFastEnded]?['source'], 'meal_save');
    expect(analytics.props[FunnelEvents.ifFastEnded]?['completed'], false);
    expect(await activeFast(tester), isNull);
    expect(await mealCount(tester), 1);
  });
}
