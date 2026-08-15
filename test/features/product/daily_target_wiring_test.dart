import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/meals/presentation/screens/meal_detail_screen.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/widgets/bento_nutrition_grid.dart';
import 'package:nutrilens/features/product/presentation/widgets/editorial_nutrient_table.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:nutrilens/l10n/generated/app_localizations_tr.dart';

// Beklenen dipnot metinlerini l10n generator'ın kendisinden üretiyoruz —
// stringi test dosyasına elle kopyalamak, ARB değişince testi sessizce
// yanlış kılar.
final _tr = AppLocalizationsTr();

/// BentoNutritionGrid / EditorialNutrientTable hiçbir provider okumuyor
/// (değerler doğrudan constructor'dan geliyor) — ProviderScope'a gerek yok.
Widget _hostPlain(Widget child) => MaterialApp(
  // context.colors, AppColorsExtension olmayan bir temada debug assert
  // fırlatır (app_colors.dart) — theme şart.
  theme: AppTheme.light,
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// MealDetailScreen `userMetricsProvider`/`dailyCalorieTargetProvider`
/// okuyor — gerçek ekran, gerçek Riverpod bağlantısı üzerinden test edilir.
/// `metrics: null` == bugünkü tüm kullanıcıların durumu.
Widget _wrapMealScreen(MealEntryEntity meal, {required UserMetricsEntity? metrics}) {
  return ProviderScope(
    overrides: [userMetricsProvider.overrideWith((ref) async => metrics)],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MealDetailScreen(meal: meal),
    ),
  );
}

void main() {
  group('BentoNutritionGrid — dailyCalories yuzdelik boleni', () {
    testWidgets('varsayilan referans 2000 kcal: 1000/2000 = %50', (t) async {
      await t.pumpWidget(
        _hostPlain(
          const BentoNutritionGrid(
            nutriments: NutrimentsEntity(energyKcal: 1000),
          ),
        ),
      );
      expect(find.textContaining('50%'), findsWidgets);
    });

    testWidgets(
      'kisisel hedef verilince yuzde ona gore degisir: 1000/2500 = %40',
      (t) async {
        await t.pumpWidget(
          _hostPlain(
            const BentoNutritionGrid(
              nutriments: NutrimentsEntity(energyKcal: 1000),
              dailyCalories: 2500,
            ),
          ),
        );
        expect(find.textContaining('40%'), findsWidgets);
      },
    );
  });

  group('EditorialNutrientTable — dipnot secimi', () {
    const nutriments = NutrimentsEntity(energyKcal: 500);

    testWidgets('personalDailyCalories verilmezse eski 2000 kcal dipnotu kalir', (
      t,
    ) async {
      await t.pumpWidget(
        _hostPlain(const EditorialNutrientTable(nutriments: nutriments)),
      );
      expect(find.text(_tr.dailyValueNote), findsOneWidget);
      expect(find.text(_tr.dailyValueNotePersonal(2000)), findsNothing);
    });

    testWidgets('personalDailyCalories verilince kisisel dipnot gosterilir', (
      t,
    ) async {
      await t.pumpWidget(
        _hostPlain(
          const EditorialNutrientTable(
            nutriments: nutriments,
            personalDailyCalories: 2400,
          ),
        ),
      );
      expect(find.text(_tr.dailyValueNotePersonal(2400)), findsOneWidget);
      expect(find.text(_tr.dailyValueNote), findsNothing);
    });
  });

  group('MealDetailScreen — gercek ekran uzerinden uctan uca baglanti', () {
    // energyKcal=1000: varsayilan 2000 kcal tabaninda tam %50 verir, yuvarlama
    // belirsizligi olmadan dogrulanabilir.
    final meal = MealEntryEntity(
      id: 'meal-1',
      userId: 'user-1',
      mealName: 'Test Ogun',
      mealType: MealType.lunch,
      capturedAt: DateTime(2026, 8, 14),
      nutriments: const NutrimentsEntity(energyKcal: 1000),
      calories: 1000,
    );

    testWidgets(
      'EN KRITIK REGRESYON: metrics yok -> yuzdelik 2000 kcal tabanli VE '
      'dipnot eski metin (bugunku tum kullanicilarin davranisi bit bit ayni kalmali)',
      (t) async {
        await t.pumpWidget(_wrapMealScreen(meal, metrics: null));
        await t.pumpAndSettle();

        // 1000 / 2000 = %50
        expect(find.textContaining('50%'), findsWidgets);
        expect(find.text(_tr.dailyValueNote), findsOneWidget);
      },
    );

    testWidgets(
      'metrics var -> yuzdelik kisisel hedefe gore VE dipnot kisisel metin',
      (t) async {
        final metrics = UserMetricsEntity(
          userId: 'user-1',
          sex: BiologicalSex.male,
          birthYear: 1996,
          heightCm: 180,
          weightKg: 80,
          activity: ActivityLevel.sedentary,
          updatedAt: DateTime(2026, 8, 14),
        );
        await t.pumpWidget(_wrapMealScreen(meal, metrics: metrics));
        await t.pumpAndSettle();

        // Uretim kodu dailyCalorieTargetProvider ile ayni hesaplayiciyi
        // cagirir — beklenen deger de ayni yoldan turetiliyor (Task 3'un
        // provider testinde kullanilan desenle ayni).
        final target = calculateCalorieTarget(
          metrics.toCalculatorInput(DateTime.now()),
        ).target;
        final expectedPercent = (1000 / target * 100)
            .clamp(0, 100)
            .toStringAsFixed(0);

        expect(find.textContaining('$expectedPercent%'), findsWidgets);
        expect(find.text(_tr.dailyValueNotePersonal(target)), findsOneWidget);
        expect(find.text(_tr.dailyValueNote), findsNothing);
      },
    );
  });
}
