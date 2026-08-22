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
import 'package:nutrilens/features/meals/presentation/screens/meal_edit_screen.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

final _seedMeal = MealEntryEntity(
  id: 'meal-1',
  userId: 'user-1',
  mealName: 'Kahvaltı',
  brand: 'Ev yapımı',
  mealType: MealType.breakfast,
  capturedAt: DateTime(2026, 1, 1, 9),
  ingredientsText: 'Yumurta, peynir',
  nutriments: const NutrimentsEntity(
    energyKcal: 400,
    proteins: 20,
    carbohydrates: 10,
    fat: 15,
  ),
  calories: 400,
);

Widget wrap(AppDatabase db) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    effectiveUserIdProvider.overrideWithValue('user-1'),
    currentUserProvider.overrideWithValue(null),
    isPremiumProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('tr'),
    home: MealEditScreen(meal: _seedMeal),
  ),
);

void main() {
  testWidgets('alanlar mevcut oguen degerleriyle onceden doldurulur', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await MealLocalDataSourceImpl(db).saveMeal(_seedMeal);

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Kahvaltı'), findsOneWidget);
    expect(find.text('400'), findsOneWidget); // kalori
    expect(find.text('20'), findsOneWidget); // protein
  });

  testWidgets(
    'kalori duzenlenip kaydedilince hem calories hem energyKcal guncellenir',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await MealLocalDataSourceImpl(db).saveMeal(_seedMeal);

      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Alan sirasi meal_edit_screen.dart'taki build() ile birebir: 0=ad,
      // 1=kaynak, 2=kalori, 3=protein, 4=karbonhidrat, 5=yag, 6=icerik.
      await tester.enterText(find.byType(TextField).at(2), '550');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Değişiklikleri Kaydet'));
      await tester.pumpAndSettle();

      final saved = await MealLocalDataSourceImpl(
        db,
      ).getMeals(userId: 'user-1');
      expect(saved.single.calories, 550);
      expect(saved.single.nutriments.energyKcal, 550);
      // Diger alanlar dokunulmadan korunmali.
      expect(saved.single.nutriments.proteins, 20);
      expect(saved.single.mealName, 'Kahvaltı');
    },
  );
}
