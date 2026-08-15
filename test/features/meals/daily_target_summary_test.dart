import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/meals/presentation/screens/meals_screen.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

/// meals_screen.dart'in liste basliginin ustune eklenen gunluk
/// alinan/hedef ozet satirini test eder (Task 8, Step 2/6).
///
/// dailyCalorieTargetProvider dogrudan override edilir (bir Provider,
/// her zaman bir sayi dondurur) — bu, userMetricsProvider'in Drift
/// zincirini kurmadan "metrics var/yok" senaryolarini ayri ayri test
/// etmeyi saglar; user_metrics_provider.dart'taki kendi dokumantasyonu
/// tam olarak bu ayrimi tanimliyor.
MealEntryEntity _todayMeal({required double calories}) => MealEntryEntity(
      id: 'today-1',
      userId: 'user-1',
      mealName: 'Test ogun',
      brand: 'Ev yapimi',
      mealType: MealType.lunch,
      capturedAt: DateTime.now(),
      ingredientsText: 'test',
      nutriments: NutrimentsEntity(energyKcal: calories),
      calories: calories,
      hpScore: 70,
      confidence: 0.8,
      aiRawJson: '{}',
    );

// `extraOverrides` bilerek tiplenmemis: `Override`, `riverpod` paketinden
// gelir ve bu paket `flutter_riverpod` uzerinden yalnizca gecisli bir
// bagimlilik (pubspec.yaml'da dogrudan listelenmiyor) — dogrudan import
// etmek yerine, hedef tip zaten `ProviderScope.overrides` parametresinden
// (List<Override>) cikarilabildigi icin asagida `.cast()` tip argumanini
// belirtmeden kullaniliyor.
Widget wrap(AppDatabase db, {List extraOverrides = const []}) =>
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        effectiveUserIdProvider.overrideWithValue('user-1'),
        // meal_provider.dart'taki mealCloudSyncProvider, currentUserProvider +
        // isPremiumProvider'i kosulsuz watch eder (bkz. meals_screen_chart_test.dart
        // ayni yorum) — bunlar olmadan zincir Supabase/RevenueCat'e uzanip patlar.
        currentUserProvider.overrideWithValue(null),
        isPremiumProvider.overrideWithValue(false),
        ...extraOverrides,
      ].cast(),
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: const MealsScreen(),
      ),
    );

/// Öğünlerim ekranı dolu haldeyken (grafik + yeni özet kartı + öğün
/// listesi) varsayılan 800×600 test yüzeyine sığmıyor — flutter_test'in
/// finder'ları varsayılan olarak `skipOffstage: true` çalışır ve
/// viewport'un altında kalan (henüz layout almamış/scroll dışı) widget'ları
/// "offstage" sayıp atlar. Yüzeyi yeterince uzun yaparak asıl davranışı
/// (scroll gerektirmeden) test ediyoruz — bu proje `flutter_test`'in kendi
/// fontuyla çizdiğinden gerçek piksel yükseklikleri farklı olabilir, bu
/// yüzden bolca pay bırakıldı.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets(
      'metrics yokken varsayilan 2000 kcal hedefiyle "alinan / hedef" ozeti gorunur',
      (tester) async {
    await _useTallSurface(tester);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(_todayMeal(calories: 1420));

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('1420 / 2000 kcal'), findsOneWidget);
  });

  testWidgets(
      'dailyCalorieTargetProvider 2500 override edildiginde ozet yeni hedefi gosterir',
      (tester) async {
    await _useTallSurface(tester);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(_todayMeal(calories: 1420));

    await tester.pumpWidget(
      wrap(
        db,
        extraOverrides: [dailyCalorieTargetProvider.overrideWithValue(2500)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1420 / 2500 kcal'), findsOneWidget);
  });

  testWidgets('toplam hedefi asinca asim gostergesi gorunur', (tester) async {
    await _useTallSurface(tester);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(_todayMeal(calories: 1420));

    await tester.pumpWidget(
      wrap(
        db,
        extraOverrides: [dailyCalorieTargetProvider.overrideWithValue(1000)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1420 / 1000 kcal'), findsOneWidget);
    expect(find.text('Hedefin 420 kcal üzerindesin'), findsOneWidget);
  });

  testWidgets('hedef asilmadiysa asim gostergesi gorunmez', (tester) async {
    await _useTallSurface(tester);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(_todayMeal(calories: 1420));

    await tester.pumpWidget(
      wrap(
        db,
        extraOverrides: [dailyCalorieTargetProvider.overrideWithValue(2000)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('üzerindesin'), findsNothing);
  });

  testWidgets(
      'metrics yokken (varsayilan 2000 kcal) dahi tibbi tavsiye dipnotu '
      'gorunur — gosterilen sayi kisisel olsun olmasin tahmini bir '
      'referanstir', (tester) async {
    await _useTallSurface(tester);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(_todayMeal(calories: 1420));

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(
      find.text('Tahmini değerdir, tıbbi tavsiye yerine geçmez.'),
      findsOneWidget,
    );
  });
}
