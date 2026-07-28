import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/meals/presentation/screens/meals_screen.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('boş veri: dönem seçici + boş mesaj görünür', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
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
        ],
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hafta'), findsOneWidget); // varsayılan sekme
    expect(find.text('Bu dönemde kayıtlı öğün yok'), findsOneWidget);
  });
}
