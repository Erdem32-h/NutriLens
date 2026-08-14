import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/widgets/editorial_nutrient_table.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    // context.colors, AppColorsExtension'sız temada debug assert fırlatır
    // (app_colors.dart) — theme şart.
    theme: AppTheme.light,
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  const nutriments = NutrimentsEntity(energyKcal: 320, fat: 12, proteins: 9);

  testWidgets('basisLabel verilmezse 100g gosterir (paketli urun)', (t) async {
    await t.pumpWidget(host(const EditorialNutrientTable(nutriments: nutriments)));
    expect(find.text('100g'), findsOneWidget);
  });

  testWidgets('basisLabel verilirse onu gosterir (ogun)', (t) async {
    await t.pumpWidget(
      host(
        const EditorialNutrientTable(nutriments: nutriments, basisLabel: '350 g'),
      ),
    );
    expect(find.text('350 g'), findsOneWidget);
    expect(find.text('100g'), findsNothing);
  });

  // product_detail_screen.dart calls EditorialNutrientTable(nutriments: ...)
  // WITHOUT basisLabel — this is that exact contract, named explicitly so a
  // future change to the default breaks a test that says what it protects.
  testWidgets('urun ekrani sozlesmesi: basisLabel gecilmezse 100g kalir', (
    t,
  ) async {
    await t.pumpWidget(host(const EditorialNutrientTable(nutriments: nutriments)));
    expect(find.text('100g'), findsOneWidget);
  });
}
