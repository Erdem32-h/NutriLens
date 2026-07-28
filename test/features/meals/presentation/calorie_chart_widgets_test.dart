import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart'; // AppTheme.light/dark (static ThemeData getter'lar)
import 'package:nutrilens/features/meals/domain/entities/calorie_chart_data.dart';
import 'package:nutrilens/features/meals/presentation/widgets/calorie_stacked_bar_chart.dart';
import 'package:nutrilens/features/meals/presentation/widgets/macro_balance_card.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

CalorieChartData weekData() => CalorieChartData(
      period: CaloriePeriod.week,
      rangeStart: DateTime(2026, 7, 27),
      rangeEnd: DateTime(2026, 8, 3),
      buckets: [
        const CalorieBucket(
            kcal: 1500, proteinKcal: 400, carbKcal: 700, fatKcal: 400),
        const CalorieBucket(
            kcal: 2000, proteinKcal: 500, carbKcal: 1000, fatKcal: 500),
        for (var i = 0; i < 5; i++) const CalorieBucket(),
      ],
      totalKcal: 3500,
      proteinKcal: 900,
      carbKcal: 1700,
      fatKcal: 900,
      daysWithData: 2,
    );

Widget wrap(Widget child) => MaterialApp(
      // context.colors, temada AppColorsExtension yoksa debug modda assert
      // fırlatır (bkz. app_colors.dart:311-320) — widget testleri assert'lerle
      // çalışır, theme'i atlamak testi bu assert'le çökertir.
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('bar chart 7 bar ve legend render eder', (tester) async {
    await tester.pumpWidget(wrap(CalorieStackedBarChart(data: weekData())));
    await tester.pumpAndSettle();
    expect(find.byType(CalorieStackedBarChart), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget); // legend
    expect(find.text('Karbonhidrat'), findsOneWidget);
    expect(find.text('Yağ'), findsOneWidget);
  });

  testWidgets('macro balance card ortalama kcal ve seviyeleri gösterir',
      (tester) async {
    await tester.pumpWidget(wrap(MacroBalanceCard(data: weekData())));
    await tester.pumpAndSettle();
    expect(find.text('1750'), findsOneWidget); // 3500/2 gün
    expect(find.text('Günlük ortalama'), findsOneWidget);
    // paylar: %25.7 P, %48.6 K, %25.7 Y → P normal, K normal, Y normal
    expect(find.text('Normal'), findsNWidgets(3));
  });

  testWidgets('day periyodunda toplam etiketi kullanılır', (tester) async {
    final day = CalorieChartData(
      period: CaloriePeriod.day,
      rangeStart: DateTime(2026, 7, 28),
      rangeEnd: DateTime(2026, 7, 29),
      buckets: const [
        CalorieBucket(kcal: 900, proteinKcal: 100, carbKcal: 700, fatKcal: 90),
        CalorieBucket(),
        CalorieBucket(),
        CalorieBucket(),
      ],
      totalKcal: 900,
      proteinKcal: 100,
      carbKcal: 700,
      fatKcal: 90,
      daysWithData: 1,
    );
    await tester.pumpWidget(wrap(MacroBalanceCard(data: day)));
    await tester.pumpAndSettle();
    expect(find.text('Toplam'), findsOneWidget);
    // K %78.7 → Yüksek; P %11.2 Normal; Y %10.1 Düşük
    expect(find.text('Yüksek'), findsOneWidget);
    expect(find.text('Düşük'), findsOneWidget);
  });
}
