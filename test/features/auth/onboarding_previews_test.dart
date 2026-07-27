import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/widgets/onboarding_previews.dart';
import 'package:nutrilens/features/product/presentation/widgets/health_score_bar.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MealPreview ornek degerleri gosterir', (tester) async {
    await _pump(tester, const MealPreview());

    expect(find.text('Kıymalı makarna'), findsOneWidget);
    expect(find.text('486'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScorePreview gauge 4 gosterir', (tester) async {
    await _pump(tester, const ScorePreview());

    // hpScore 26 -> ScoreConstants.hpToGauge -> 4. Katki sayisi da 4
    // oldugu icin duz find.text('4') iki eslesme bulur; gauge'i
    // HealthScoreBar'in icinde arayarak daraltiyoruz.
    expect(
      find.descendant(
        of: find.byType(HealthScoreBar),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FiltersPreview cip ve uyariyi gosterir', (tester) async {
    await _pump(tester, const FiltersPreview());

    expect(find.text('Gluten'), findsOneWidget);
    expect(find.text('Laktoz'), findsOneWidget);
    expect(
      find.text('Bu üründe laktoz var — senin listende.'),
      findsOneWidget,
    );
  });

  testWidgets('uc onizleme de koyu temada hatasiz cizilir', (tester) async {
    for (final w in const [MealPreview(), ScorePreview(), FiltersPreview()]) {
      await _pump(tester, w, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uc onizleme de Arapca (RTL) hatasiz cizilir', (tester) async {
    for (final w in const [MealPreview(), ScorePreview(), FiltersPreview()]) {
      await _pump(tester, w, locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
    }
  });
}
