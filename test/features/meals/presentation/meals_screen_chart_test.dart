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
import 'package:nutrilens/features/meals/presentation/widgets/calorie_stacked_bar_chart.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

// `extraOverrides` bilerek tiplenmemis: `Override`, `riverpod` paketinden
// gelir ve bu paket `flutter_riverpod` uzerinden yalnizca gecisli bir
// bagimlilik — dogrudan import etmek yerine hedef tip zaten
// `ProviderScope.overrides` parametresinden (List<Override>) cikarilabildigi
// icin `.cast()` ile kullaniliyor (bkz. daily_target_summary_test.dart).
Widget wrap(AppDatabase db, {List extraOverrides = const []}) =>
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        effectiveUserIdProvider.overrideWithValue('user-1'),
        // MealsScreen, mealCloudSyncProvider'ı da watch ediyor; o da
        // currentUserProvider + isPremiumProvider'ı koşulsuz watch eder
        // (meal_provider.dart — `if` kontrolünden ÖNCE ikisi de okunur).
        // Bu ikisi olmadan zincir Supabase/RevenueCat'e uzanır ve testte
        // patlar — bu yüzden burada da kısa devre ediyoruz.
        currentUserProvider.overrideWithValue(null),
        isPremiumProvider.overrideWithValue(false),
        ...extraOverrides,
      ].cast(),
      child: MaterialApp(
        // context.colors, AppColorsExtension olmayan bir temada debug
        // assert fırlatır (app_colors.dart:311-320) — Task 9'da aynı
        // sebeple eklenmişti, burada da gerekli.
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: const MealsScreen(),
      ),
    );

void main() {
  testWidgets('boş veri: dönem seçici + boş mesaj görünür', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Hafta'), findsOneWidget); // varsayılan sekme
    expect(find.text('Bu dönemde kayıtlı öğün yok'), findsOneWidget);
  });

  testWidgets(
      'dönem sekmesi değişirken grafik spinner\'a çökmez (layout zıplaması)',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(
      MealEntryEntity(
        id: 'today',
        userId: 'user-1',
        mealName: 'Kahvaltı',
        brand: 'Ev yapımı',
        mealType: MealType.breakfast,
        capturedAt: DateTime.now(),
        ingredientsText: 'Yumurta, peynir',
        nutriments: const NutrimentsEntity(energyKcal: 400, proteins: 20),
        calories: 400,
        hpScore: 82,
        confidence: 0.8,
        aiRawJson: '{"food_name":"omelet"}',
      ),
    );

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();
    expect(find.byType(CalorieStackedBarChart), findsOneWidget);

    // Sekme değişimi calorieChartDataProvider'ı yeniden yükletir. Yeni veri
    // gelene kadarki ara karede grafik yerine spinner gelirse tüm bölüm
    // ~40px'e çöker ve alttaki öğün listesi yukarı zıplar — kullanıcı bug'ı.
    // Ara kareyi görmek için pumpAndSettle DEĞİL tek pump kullanılır.
    await tester.tap(find.text('Gün'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'geçiş sırasında grafik spinner\'a çöküp listeyi zıplatmamalı');
    expect(find.byType(CalorieStackedBarChart), findsOneWidget);

    // Yeni dönemin verisi gelince de grafik yerinde kalmalı (bugünün öğünü
    // Gün görünümünde de var).
    await tester.pumpAndSettle();
    expect(find.byType(CalorieStackedBarChart), findsOneWidget);
  });

  testWidgets(
      'metrics yokken (personalDailyCaloriesProvider null) grafiğe hedef '
      'geçirilmez — ~607 canlı kullanıcının varsayılan görünümü budur',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(
      MealEntryEntity(
        id: 'today',
        userId: 'user-1',
        mealName: 'Kahvaltı',
        brand: 'Ev yapımı',
        mealType: MealType.breakfast,
        capturedAt: DateTime.now(),
        ingredientsText: 'Yumurta, peynir',
        nutriments: const NutrimentsEntity(energyKcal: 400, proteins: 20),
        calories: 400,
        hpScore: 82,
        confidence: 0.8,
        aiRawJson: '{"food_name":"omelet"}',
      ),
    );

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    final chart = tester.widget<CalorieStackedBarChart>(
      find.byType(CalorieStackedBarChart),
    );
    expect(chart.targetKcal, isNull);
  });

  testWidgets(
      'metrics varken Hafta/Ay sekmesinde grafiğe hedef geçirilir, Gün '
      'sekmesinde geçirilmez (kova birimi günlük değil)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(
      MealEntryEntity(
        id: 'today',
        userId: 'user-1',
        mealName: 'Kahvaltı',
        brand: 'Ev yapımı',
        mealType: MealType.breakfast,
        capturedAt: DateTime.now(),
        ingredientsText: 'Yumurta, peynir',
        nutriments: const NutrimentsEntity(energyKcal: 400, proteins: 20),
        calories: 400,
        hpScore: 82,
        confidence: 0.8,
        aiRawJson: '{"food_name":"omelet"}',
      ),
    );

    await tester.pumpWidget(
      wrap(
        db,
        extraOverrides: [
          personalDailyCaloriesProvider.overrideWithValue(1800),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Hafta = varsayılan sekme.
    var chart = tester.widget<CalorieStackedBarChart>(
      find.byType(CalorieStackedBarChart),
    );
    expect(chart.targetKcal, 1800);

    await tester.tap(find.text('Gün'));
    await tester.pumpAndSettle();

    chart = tester.widget<CalorieStackedBarChart>(
      find.byType(CalorieStackedBarChart),
    );
    expect(
      chart.targetKcal,
      isNull,
      reason:
          'Gün periyodu öğün tipine göre kovalanır — günlük hedef çizgisi '
          'anlamsızdır',
    );
  });
}
