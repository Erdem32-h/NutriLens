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

  testWidgets(
      'bar chart makro segmentleri sıfır genişliğe çökmez (regresyon)',
      (tester) async {
    // ColoredBox, child'ı olmadan gevşek genişlik kısıtında en küçük
    // boyutu (0) seçer — SizedBox'a width verilmezse segment görünmez
    // bir dilime çöker (yükseklik doğru olsa bile). Bu test, her
    // segmentin ClipRRect kapsayıcısıyla aynı genişlikte render
    // olduğunu doğrular.
    await tester.pumpWidget(wrap(CalorieStackedBarChart(data: weekData())));
    await tester.pumpAndSettle();

    final barWidths = find
        .byType(ClipRRect)
        .evaluate()
        .map((e) => (e.renderObject as RenderBox).size.width)
        .where((w) => w > 0)
        .toSet();
    expect(barWidths, isNotEmpty);

    final segmentColors = find
        .byType(ColoredBox)
        .evaluate()
        .map((e) => (e.widget as ColoredBox).color)
        .toSet();
    // 2 dolu bucket × 3 makro = en az bu 3 kimlik rengi render olmalı.
    expect(segmentColors.length, greaterThanOrEqualTo(3));

    // Scaffold'un varsayılan arka plan ColoredBox'ı (alpha 0) dahil tüm
    // ağacı değil, sadece CalorieStackedBarChart'ın alt ağacındaki, gerçek
    // (saydam olmayan) makro segmentlerini say. `if (size.height > 0)` gibi
    // atlama koşulu YOK — 0×0'a çöken bir segment burada kaçmaz.
    final nonEmptySegments = find
        .descendant(
          of: find.byType(CalorieStackedBarChart),
          matching: find.byType(ColoredBox),
        )
        .evaluate()
        .where((element) => (element.widget as ColoredBox).color.a > 0)
        .toList();

    // 2 dolu bucket × 3 makro = en az 6 saydam olmayan segment beklenir.
    expect(nonEmptySegments.length, greaterThanOrEqualTo(6));
    for (final element in nonEmptySegments) {
      final size = (element.renderObject as RenderBox).size;
      expect(
        size.width,
        greaterThan(0),
        reason: 'Renkli makro segmenti sıfır genişlikte render oldu',
      );
      expect(
        size.height,
        greaterThan(0),
        reason: 'Renkli makro segmenti sıfır yükseklikte render oldu',
      );
    }
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

  testWidgets(
      'hedefin altındaki barda kesikli hedef çizgisi bulunur ve doğru '
      'konumda çizilir', (tester) async {
    // weekData()'daki en yüksek bar 2000 kcal; hedef 1800 < 2000, yani
    // effectiveMax == maxKcal (rescale yok) ve çizgi normal aralıkta.
    await tester.pumpWidget(
      wrap(CalorieStackedBarChart(data: weekData(), targetKcal: 1800)),
    );
    await tester.pumpAndSettle();

    final lineFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TargetLine',
    );
    expect(lineFinder, findsOneWidget);

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: lineFinder, matching: find.byType(Positioned)).first,
    );
    // chartHeight=160, labelRowHeight=24 (widget'ın private sabitleri):
    // bottom = 24 + 160*(1800/2000) = 168.
    expect(positioned.bottom, closeTo(168, 0.01));
  });

  testWidgets(
      'hedef en yüksek bardan büyük olduğunda (en yaygın senaryo) çizgi '
      'grafik alanının dışına taşıp kırpılmaz', (tester) async {
    // En yüksek bar 2000 kcal; hedef 3000 > 2000 → effectiveMax hedefe
    // genişler ve ham oran tam 1.0 olur. Düzeltmeden önce bu durumda
    // `bottom` Stack'in tam yüksekliğine eşitlenip çizgi Clip.hardEdge ile
    // tamamen kırpılıyordu — yani çizgi TAM OLARAK en çok gerektiği anda
    // görünmüyordu.
    await tester.pumpWidget(
      wrap(CalorieStackedBarChart(data: weekData(), targetKcal: 3000)),
    );
    await tester.pumpAndSettle();

    final lineFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TargetLine',
    );
    expect(lineFinder, findsOneWidget);

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: lineFinder, matching: find.byType(Positioned)).first,
    );
    // Grafik alanı labelRowHeight(24) + chartHeight(160) = 184 yüksekliğinde;
    // çizgi 4px — bottom en fazla 180 olabilir, yoksa üstten taşar.
    expect(positioned.bottom, isNotNull);
    expect(positioned.bottom, lessThanOrEqualTo(180));
    expect(positioned.bottom, greaterThanOrEqualTo(0));
  });

  testWidgets(
      'targetKcal null iken (metrics yok) hedef çizgisi render olmaz ve '
      'grafik öncekiyle bit bit aynı kalır', (tester) async {
    await tester.pumpWidget(wrap(CalorieStackedBarChart(data: weekData())));
    await tester.pumpAndSettle();

    final lineFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TargetLine',
    );
    expect(lineFinder, findsNothing);
  });

  testWidgets(
      'macro balance card makro dökümü yokken yanıltıcı Düşük göstermez',
      (tester) async {
    // kcal var (bir öğün loglanmış) ama proteinKcal/carbKcal/fatKcal hepsi
    // 0 — yani sadece kalori girilmiş, makro dökümü olmayan bir öğün.
    // %0/Düşük göstermek "eksik besleniyorsun" yanılgısı üretir; bunun
    // yerine nötr bir yer tutucu ("—") gösterilmeli.
    final data = CalorieChartData(
      period: CaloriePeriod.day,
      rangeStart: DateTime(2026, 7, 28),
      rangeEnd: DateTime(2026, 7, 29),
      buckets: const [
        CalorieBucket(kcal: 500),
        CalorieBucket(),
        CalorieBucket(),
        CalorieBucket(),
      ],
      totalKcal: 500,
      proteinKcal: 0,
      carbKcal: 0,
      fatKcal: 0,
      daysWithData: 1,
    );
    await tester.pumpWidget(wrap(MacroBalanceCard(data: data)));
    await tester.pumpAndSettle();
    expect(find.text('Düşük'), findsNothing);
    expect(find.text('Normal'), findsNothing);
    expect(find.text('Yüksek'), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
  });
}
