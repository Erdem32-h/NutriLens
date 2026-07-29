# Kalori Takibi Grafiği — Uygulama Planı

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Öğünlerim ekranına Gün/Hafta/Ay/Yıl sekmeli, makro-renkli stacked-bar kalori grafiği + makro dengesi kartı eklemek ve ana ekran widget'ını 3 makro göstergesiyle genişletmek.

**Architecture:** Bucket'lama saf Dart fonksiyonlarında (`CalorieChartAggregator`, domain katmanı) yapılır; Riverpod `FutureProvider` yalnızca veri çekip aggregator'a devreder. UI üç küçük widget dosyasından oluşur; grafik el yapımıdır (yeni bağımlılık yok). Native widget'lar mevcut `home_widget` SharedPreferences/App-Group köprüsüne 3 yeni yüzde anahtarı ekleyerek genişler.

**Tech Stack:** Flutter, Riverpod (klasik provider'lar), Drift, `home_widget`, Kotlin RemoteViews, SwiftUI WidgetKit.

**Spec:** `docs/superpowers/specs/2026-07-28-kalori-takibi-grafik-design.md`

**Genel kurallar:**
- Her görev sonunda `flutter analyze` temiz olmalı.
- Commit mesajları Türkçe, conventional format (`feat(meals): ...`).
- Testler: `flutter test <dosya>` ile görev içinde, tüm suite en sonda.
- Yeni UI widget'larında yönlü padding gerekirse `EdgeInsetsDirectional` kullan (RTL desteği).
- `context.colors` = `AppColorsExtension` (`lib/core/theme/app_colors.dart`); tüm yüzeyler için tema renkleri, makro kimlikleri için `MacroColors` sabitleri kullanılır.

---

### Task 1: Figma mockup (kullanıcı onay kapısı)

**Bu görev koddan önce gelir ve kullanıcı onayı gerektirir — subagent'a devredilemez, ana oturumda yapılır.**

**Adımlar:**
1. `figma:figma-generate-design` skill'ini yükle (Figma MCP kuralı: `use_figma` çağrısından önce ilgili skill zorunlu).
2. Mockup içeriği — iki frame:
   - **Frame 1 — MealsScreen (light + dark):** üstte Gün/Hafta/Ay/Yıl segment seçici + `‹ 26 Tem – 1 Ağu ›` dönem gezinme satırı; ortada 7 barlı stacked-bar grafik (protein `#6366F1`, karbonhidrat `#F59E0B`, yağ `#EC4899` segmentleri) + altında 3 nokta legend; altında makro dengesi kartı (radius 24, `surfaceCard`: büyük kcal sayısı + "Günlük ortalama" alt yazısı + 3 satır Protein/Karbonhidrat/Yağ, her satırda % pay ve Düşük(mavi `#38BDF8`)/Normal(yeşil `#4ADE80`)/Yüksek(turuncu `#FB923C`) etiketi); en altta mevcut öğün listesi kartlarından 2 örnek.
   - **Frame 2 — Home widget (Android 2x2 + iOS small/medium):** mevcut düzen (BUGÜN başlık, büyük kcal, "N öğün · bugün", Tara butonu) + öğün sayısının altına 3 mini yatay bar: `P %25` / `K %50` / `Y %25`, aynı üç kimlik rengi.
   - Görsel dil: koyu yeşil marka gradyanı (widget), uygulama içinde `surfaceCard`/`background` tonları, `HealthScoreBar`'ın büyük-sayı tipografisi (w800).
3. `get_screenshot` ile mockup'ı kullanıcıya göster.
4. **Kullanıcı onayını bekle.** Onaylanmazsa düzeltme turu; onaylanınca Task 2'ye geç.

---

### Task 2: l10n anahtarları

**Files:**
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_pt.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_zh.arb`

**Step 1: 6 arb dosyasına anahtarları ekle**

`app_tr.arb`'a (şablon; alfabetik değil, mevcut meal anahtarlarının yakınına):

```json
"caloriePeriodDay": "Gün",
"caloriePeriodWeek": "Hafta",
"caloriePeriodMonth": "Ay",
"caloriePeriodYear": "Yıl",
"macroProtein": "Protein",
"macroCarbs": "Karbonhidrat",
"macroFat": "Yağ",
"macroLevelLow": "Düşük",
"macroLevelNormal": "Normal",
"macroLevelHigh": "Yüksek",
"calorieChartEmptyPeriod": "Bu dönemde kayıtlı öğün yok",
"calorieCardAverageDaily": "Günlük ortalama",
"calorieCardTotal": "Toplam"
```

Diğer 5 dile çevirileri (en: Day/Week/Month/Year, Protein/Carbs/Fat, Low/Normal/High, "No meals recorded in this period", "Daily average", "Total"; es/pt/ar/zh mevcut dosyalardaki çeviri kalitesiyle uyumlu şekilde).

**Step 2: Üret ve doğrula**

Run: `flutter gen-l10n`
Expected: hata yok; `lib/l10n/generated/` güncellenir.

Run: `flutter analyze`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/l10n
git commit -m "feat(l10n): kalori grafiği ve makro etiket anahtarları"
```

---

### Task 3: MacroReferenceConstants + MacroLevel

**Files:**
- Create: `lib/core/constants/macro_reference_constants.dart`
- Test: `test/core/constants/macro_reference_constants_test.dart`

**Step 1: Failing test yaz**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/constants/macro_reference_constants.dart';

void main() {
  test('pay aralığın altındaysa low', () {
    expect(
      MacroReferenceConstants.levelFor(9.9, min: 10, max: 35),
      MacroLevel.low,
    );
  });

  test('pay aralığın içindeyse normal (sınırlar dahil)', () {
    expect(
      MacroReferenceConstants.levelFor(10, min: 10, max: 35),
      MacroLevel.normal,
    );
    expect(
      MacroReferenceConstants.levelFor(35, min: 10, max: 35),
      MacroLevel.normal,
    );
  });

  test('pay aralığın üstündeyse high', () {
    expect(
      MacroReferenceConstants.levelFor(35.1, min: 10, max: 35),
      MacroLevel.high,
    );
  });
}
```

**Step 2: Testi çalıştır, FAIL gör**

Run: `flutter test test/core/constants/macro_reference_constants_test.dart`
Expected: derleme hatası ("macro_reference_constants.dart" yok).

**Step 3: Implementasyon**

```dart
/// Genel diyet referansı: bir makronun toplam makro-enerji içindeki payı
/// bu aralıkların altında/üstünde ise Düşük/Yüksek sayılır.
/// Kişisel hedef DEĞİLDİR (uygulamada TDEE altyapısı yok — spec §4).
enum MacroLevel { low, normal, high }

abstract final class MacroReferenceConstants {
  // Kabul edilebilir pay aralıkları (% — toplam makro kcal içindeki pay)
  static const double proteinMinPct = 10;
  static const double proteinMaxPct = 35;
  static const double carbMinPct = 45;
  static const double carbMaxPct = 65;
  static const double fatMinPct = 20;
  static const double fatMaxPct = 35;

  // Atwater faktörleri (kcal/gram)
  static const double kcalPerGramProtein = 4;
  static const double kcalPerGramCarb = 4;
  static const double kcalPerGramFat = 9;

  static MacroLevel levelFor(
    double pct, {
    required double min,
    required double max,
  }) {
    if (pct < min) return MacroLevel.low;
    if (pct > max) return MacroLevel.high;
    return MacroLevel.normal;
  }
}
```

**Step 4: Test geç**

Run: `flutter test test/core/constants/macro_reference_constants_test.dart`
Expected: 3 test PASS.

**Step 5: Commit**

```bash
git add lib/core/constants/macro_reference_constants.dart test/core/constants/macro_reference_constants_test.dart
git commit -m "feat(meals): makro referans aralıkları ve MacroLevel"
```

---

### Task 4: CalorieChartData modeli + CalorieChartAggregator

**Files:**
- Create: `lib/features/meals/domain/entities/calorie_chart_data.dart`
- Create: `lib/features/meals/domain/services/calorie_chart_aggregator.dart`
- Test: `test/features/meals/domain/calorie_chart_aggregator_test.dart`

**Step 1: Failing testleri yaz**

Test dosyası (tamamı):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/constants/macro_reference_constants.dart';
import 'package:nutrilens/features/meals/domain/entities/calorie_chart_data.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/meals/domain/services/calorie_chart_aggregator.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

MealEntryEntity meal({
  required DateTime at,
  double kcal = 400,
  MealType type = MealType.lunch,
  double? protein,
  double? carbs,
  double? fat,
}) {
  return MealEntryEntity(
    id: at.toIso8601String() + type.name,
    userId: 'u1',
    mealName: 'x',
    mealType: type,
    capturedAt: at,
    calories: kcal,
    nutriments: NutrimentsEntity(proteins: protein, carbohydrates: carbs, fat: fat),
  );
}

void main() {
  // Sabit "şimdi": Salı 28 Temmuz 2026
  final now = DateTime(2026, 7, 28, 20, 30);

  group('rangeFor', () {
    test('day offset 0 = bugün', () {
      final r = CalorieChartAggregator.rangeFor(CaloriePeriod.day, 0, now);
      expect(r.start, DateTime(2026, 7, 28));
      expect(r.end, DateTime(2026, 7, 29));
    });

    test('week offset 0 = Pazartesi başlangıçlı bu hafta', () {
      final r = CalorieChartAggregator.rangeFor(CaloriePeriod.week, 0, now);
      expect(r.start, DateTime(2026, 7, 27)); // Pazartesi
      expect(r.end, DateTime(2026, 8, 3));
    });

    test('month offset 1 = geçen ay, ay sınırları doğru', () {
      final r = CalorieChartAggregator.rangeFor(CaloriePeriod.month, 1, now);
      expect(r.start, DateTime(2026, 6));
      expect(r.end, DateTime(2026, 7));
    });

    test('year offset 0 = bu yıl', () {
      final r = CalorieChartAggregator.rangeFor(CaloriePeriod.year, 0, now);
      expect(r.start, DateTime(2026));
      expect(r.end, DateTime(2027));
    });

    test('month offset yıl sınırını aşar (Ocak - 1 = geçen yıl Aralık)', () {
      final jan = DateTime(2026, 1, 15);
      final r = CalorieChartAggregator.rangeFor(CaloriePeriod.month, 1, jan);
      expect(r.start, DateTime(2025, 12));
      expect(r.end, DateTime(2026, 1));
    });
  });

  group('aggregate', () {
    test('day: öğün tipine göre 4 bucket', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.day,
        offset: 0,
        now: now,
        meals: [
          meal(at: DateTime(2026, 7, 28, 8), type: MealType.breakfast, kcal: 300),
          meal(at: DateTime(2026, 7, 28, 13), type: MealType.lunch, kcal: 500),
          meal(at: DateTime(2026, 7, 28, 13, 30), type: MealType.lunch, kcal: 200),
        ],
      );
      expect(data.buckets.length, MealType.values.length);
      expect(data.buckets[MealType.breakfast.index].kcal, 300);
      expect(data.buckets[MealType.lunch.index].kcal, 700);
      expect(data.buckets[MealType.dinner.index].kcal, 0);
      expect(data.totalKcal, 1000);
    });

    test('week: 7 bucket, gün indeksi Pazartesi=0', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.week,
        offset: 0,
        now: now,
        meals: [
          meal(at: DateTime(2026, 7, 27, 9), kcal: 400), // Pzt
          meal(at: DateTime(2026, 7, 28, 9), kcal: 600), // Sal
        ],
      );
      expect(data.buckets.length, 7);
      expect(data.buckets[0].kcal, 400);
      expect(data.buckets[1].kcal, 600);
    });

    test('month: ayın gün sayısı kadar bucket (Temmuz=31)', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.month,
        offset: 0,
        now: now,
        meals: [meal(at: DateTime(2026, 7, 1, 9), kcal: 250)],
      );
      expect(data.buckets.length, 31);
      expect(data.buckets[0].kcal, 250);
    });

    test('year: 12 bucket, ay indeksi Ocak=0', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.year,
        offset: 0,
        now: now,
        meals: [meal(at: DateTime(2026, 3, 5, 9), kcal: 800)],
      );
      expect(data.buckets.length, 12);
      expect(data.buckets[2].kcal, 800);
    });

    test('makro kcal Atwater ile hesaplanır ve paylar doğru', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.day,
        offset: 0,
        now: now,
        meals: [
          // 25g protein=100kcal, 50g karb=200kcal, 11.11g yağ≈100kcal
          meal(
            at: DateTime(2026, 7, 28, 8),
            kcal: 400,
            protein: 25,
            carbs: 50,
            fat: 100 / 9,
          ),
        ],
      );
      expect(data.proteinKcal, closeTo(100, 0.01));
      expect(data.carbKcal, closeTo(200, 0.01));
      expect(data.fatKcal, closeTo(100, 0.01));
      expect(data.proteinPct, closeTo(25, 0.1));
      expect(data.carbPct, closeTo(50, 0.1));
      expect(data.fatPct, closeTo(25, 0.1));
      expect(data.proteinLevel, MacroLevel.normal);
      expect(data.carbLevel, MacroLevel.normal);
      expect(data.fatLevel, MacroLevel.normal);
    });

    test('null makro alanları 0 sayılır', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.day,
        offset: 0,
        now: now,
        meals: [meal(at: DateTime(2026, 7, 28, 8), kcal: 400)],
      );
      expect(data.proteinKcal, 0);
      expect(data.proteinPct, 0);
    });

    test('boş dönem: isEmpty true, günlük ortalama 0', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.week,
        offset: 0,
        now: now,
        meals: const [],
      );
      expect(data.isEmpty, isTrue);
      expect(data.avgKcalPerDay, 0);
    });

    test('günlük ortalama = toplam / veri olan gün sayısı', () {
      final data = CalorieChartAggregator.aggregate(
        period: CaloriePeriod.week,
        offset: 0,
        now: now,
        meals: [
          meal(at: DateTime(2026, 7, 27, 9), kcal: 400),
          meal(at: DateTime(2026, 7, 27, 13), kcal: 600),
          meal(at: DateTime(2026, 7, 28, 9), kcal: 500),
        ],
      );
      // 1500 kcal / 2 veri günü
      expect(data.avgKcalPerDay, 750);
    });
  });
}
```

**Step 2: FAIL gör**

Run: `flutter test test/features/meals/domain/calorie_chart_aggregator_test.dart`
Expected: derleme hatası (dosyalar yok).

**Step 3: Model dosyası**

`lib/features/meals/domain/entities/calorie_chart_data.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../../core/constants/macro_reference_constants.dart';

enum CaloriePeriod { day, week, month, year }

class CalorieBucket extends Equatable {
  final double kcal;
  final double proteinKcal;
  final double carbKcal;
  final double fatKcal;

  const CalorieBucket({
    this.kcal = 0,
    this.proteinKcal = 0,
    this.carbKcal = 0,
    this.fatKcal = 0,
  });

  double get macroKcal => proteinKcal + carbKcal + fatKcal;

  @override
  List<Object?> get props => [kcal, proteinKcal, carbKcal, fatKcal];
}

class CalorieChartData extends Equatable {
  final CaloriePeriod period;

  /// Dönem başlangıcı (dahil) ve bitişi (hariç).
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<CalorieBucket> buckets;
  final double totalKcal;
  final double proteinKcal;
  final double carbKcal;
  final double fatKcal;

  /// İçinde en az bir öğün olan gün sayısı — günlük ortalamanın paydası.
  /// Boş günleri paydaya katmak "az yedin" yanılgısı üretir; referans
  /// uygulamalar da yalnızca veri olan günleri ortalar.
  final int daysWithData;

  const CalorieChartData({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.buckets,
    this.totalKcal = 0,
    this.proteinKcal = 0,
    this.carbKcal = 0,
    this.fatKcal = 0,
    this.daysWithData = 0,
  });

  bool get isEmpty => totalKcal == 0;

  double get avgKcalPerDay =>
      daysWithData == 0 ? 0 : totalKcal / daysWithData;

  double get _macroTotal => proteinKcal + carbKcal + fatKcal;

  // Paylar toplam makro-kcal'e göredir (calories alanına değil) — üçü
  // her zaman 100'e tamamlanır; spec §8 ile tutarlı.
  double get proteinPct =>
      _macroTotal == 0 ? 0 : proteinKcal / _macroTotal * 100;
  double get carbPct => _macroTotal == 0 ? 0 : carbKcal / _macroTotal * 100;
  double get fatPct => _macroTotal == 0 ? 0 : fatKcal / _macroTotal * 100;

  MacroLevel get proteinLevel => MacroReferenceConstants.levelFor(
        proteinPct,
        min: MacroReferenceConstants.proteinMinPct,
        max: MacroReferenceConstants.proteinMaxPct,
      );
  MacroLevel get carbLevel => MacroReferenceConstants.levelFor(
        carbPct,
        min: MacroReferenceConstants.carbMinPct,
        max: MacroReferenceConstants.carbMaxPct,
      );
  MacroLevel get fatLevel => MacroReferenceConstants.levelFor(
        fatPct,
        min: MacroReferenceConstants.fatMinPct,
        max: MacroReferenceConstants.fatMaxPct,
      );

  @override
  List<Object?> get props => [
        period,
        rangeStart,
        rangeEnd,
        buckets,
        totalKcal,
        proteinKcal,
        carbKcal,
        fatKcal,
        daysWithData,
      ];
}
```

**Step 4: Aggregator dosyası**

`lib/features/meals/domain/services/calorie_chart_aggregator.dart`:

```dart
import '../../../../core/constants/macro_reference_constants.dart';
import '../entities/calorie_chart_data.dart';
import '../entities/meal_entry_entity.dart';

/// Saf bucket'lama mantığı — provider'dan bağımsız, testi kolay.
/// Tüm tarihler cihazın yerel saatiyle çalışır (mevcut
/// mealCalorieSummaryProvider davranışıyla tutarlı, spec §11).
abstract final class CalorieChartAggregator {
  static ({DateTime start, DateTime end}) rangeFor(
    CaloriePeriod period,
    int offset,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case CaloriePeriod.day:
        final start = today.subtract(Duration(days: offset));
        return (start: start, end: start.add(const Duration(days: 1)));
      case CaloriePeriod.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final start = monday.subtract(Duration(days: 7 * offset));
        return (start: start, end: start.add(const Duration(days: 7)));
      case CaloriePeriod.month:
        // Dart DateTime ay taşmasını normalize eder (2026,-2) → 2025 Ekim.
        final start = DateTime(now.year, now.month - offset);
        return (start: start, end: DateTime(start.year, start.month + 1));
      case CaloriePeriod.year:
        final start = DateTime(now.year - offset);
        return (start: start, end: DateTime(start.year + 1));
    }
  }

  static CalorieChartData aggregate({
    required CaloriePeriod period,
    required int offset,
    required DateTime now,
    required List<MealEntryEntity> meals,
  }) {
    final range = rangeFor(period, offset, now);
    final bucketCount = switch (period) {
      CaloriePeriod.day => MealType.values.length,
      CaloriePeriod.week => 7,
      // range.end = sonraki ayın 1'i; gün 0 = önceki ayın son günü.
      CaloriePeriod.month =>
        DateTime(range.start.year, range.start.month + 1, 0).day,
      CaloriePeriod.year => 12,
    };

    final kcal = List<double>.filled(bucketCount, 0);
    final protein = List<double>.filled(bucketCount, 0);
    final carb = List<double>.filled(bucketCount, 0);
    final fat = List<double>.filled(bucketCount, 0);
    final daysSeen = <DateTime>{};

    for (final meal in meals) {
      final at = meal.capturedAt;
      if (at.isBefore(range.start) || !at.isBefore(range.end)) continue;

      final index = switch (period) {
        CaloriePeriod.day => meal.mealType.index,
        CaloriePeriod.week =>
          DateTime(at.year, at.month, at.day).difference(range.start).inDays,
        CaloriePeriod.month => at.day - 1,
        CaloriePeriod.year => at.month - 1,
      };

      kcal[index] += meal.calories;
      protein[index] += (meal.nutriments.proteins ?? 0) *
          MacroReferenceConstants.kcalPerGramProtein;
      carb[index] += (meal.nutriments.carbohydrates ?? 0) *
          MacroReferenceConstants.kcalPerGramCarb;
      fat[index] +=
          (meal.nutriments.fat ?? 0) * MacroReferenceConstants.kcalPerGramFat;
      daysSeen.add(DateTime(at.year, at.month, at.day));
    }

    double sum(List<double> values) =>
        values.fold(0, (total, value) => total + value);

    return CalorieChartData(
      period: period,
      rangeStart: range.start,
      rangeEnd: range.end,
      buckets: List.generate(
        bucketCount,
        (i) => CalorieBucket(
          kcal: kcal[i],
          proteinKcal: protein[i],
          carbKcal: carb[i],
          fatKcal: fat[i],
        ),
      ),
      totalKcal: sum(kcal),
      proteinKcal: sum(protein),
      carbKcal: sum(carb),
      fatKcal: sum(fat),
      daysWithData: daysSeen.length,
    );
  }
}
```

**Step 5: Testler geç**

Run: `flutter test test/features/meals/domain/calorie_chart_aggregator_test.dart`
Expected: tüm testler PASS.

**Step 6: Commit**

```bash
git add lib/features/meals/domain test/features/meals/domain/calorie_chart_aggregator_test.dart
git commit -m "feat(meals): kalori grafiği bucket'lama modeli ve aggregator"
```

---

### Task 5: `MealLocalDataSource.getMealsInRange`

**Files:**
- Modify: `lib/features/meals/data/datasources/meal_local_datasource.dart`
- Test: `test/features/meals/data/meal_local_datasource_test.dart` (mevcut dosyaya ekle)

**Step 1: Failing test — mevcut test dosyasının sonuna ekle**

```dart
test('getMealsInRange aralıktaki tam satırları döndürür', () async {
  await dataSource.saveMeal(
    meal(id: 'in-1', capturedAt: DateTime(2026, 4, 26, 8), kcal: 350),
  );
  await dataSource.saveMeal(
    meal(id: 'in-2', capturedAt: DateTime(2026, 4, 26, 20), kcal: 650),
  );
  await dataSource.saveMeal(
    meal(id: 'before', capturedAt: DateTime(2026, 4, 25, 23), kcal: 900),
  );
  await dataSource.saveMeal(
    meal(id: 'at-end-excluded', capturedAt: DateTime(2026, 4, 27), kcal: 100),
  );

  final rows = await dataSource.getMealsInRange(
    userId: 'user-1',
    from: DateTime(2026, 4, 26),
    to: DateTime(2026, 4, 27),
  );

  expect(rows.map((m) => m.id).toSet(), {'in-1', 'in-2'});
  expect(rows.first.nutriments.proteins, 20); // tam entity döner
});
```

**Step 2: FAIL gör**

Run: `flutter test test/features/meals/data/meal_local_datasource_test.dart`
Expected: derleme hatası (`getMealsInRange` tanımsız).

**Step 3: Implementasyon**

Interface'e (`totalCalories`'in altına) ekle:

```dart
  /// Aralıktaki tam öğün satırları — kalori grafiğinin bucket'laması
  /// ham veriye ihtiyaç duyar; [totalCalories] yalnızca toplam döndürür.
  Future<List<MealEntryEntity>> getMealsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });
```

`MealLocalDataSourceImpl`'e (aynı sorgu deseni, `totalCalories`'in altına):

```dart
  @override
  Future<List<MealEntryEntity>> getMealsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows =
          await (_db.select(_db.mealEntries)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.capturedAt.isBiggerOrEqualValue(from) &
                    t.capturedAt.isSmallerThanValue(to),
              ))
              .get();
      return rows.map(_fromRow).toList();
    } catch (e) {
      throw CacheException('Failed to read meals in range: $e');
    }
  }
```

**Step 4: Test geç**

Run: `flutter test test/features/meals/data/meal_local_datasource_test.dart`
Expected: tüm testler PASS.

**Step 5: Commit**

```bash
git add lib/features/meals/data/datasources/meal_local_datasource.dart test/features/meals/data/meal_local_datasource_test.dart
git commit -m "feat(meals): datasource'a getMealsInRange ekle"
```

---

### Task 6: `meal_chart_provider.dart`

**Files:**
- Create: `lib/features/meals/presentation/providers/meal_chart_provider.dart`

Provider ince bir katman (mantık Task 4'te test edildi); ayrı unit test yazılmaz, ekran widget testi (Task 10) kapsar.

**Step 1: Implementasyon**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved StateProvider/StateController to the legacy library
// (see lib/features/scanner/presentation/providers/scanner_mode_provider.dart).
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/session/app_session.dart';
import '../../domain/entities/calorie_chart_data.dart';
import '../../domain/services/calorie_chart_aggregator.dart';
import 'meal_provider.dart';

/// Seçili zaman dilimi sekmesi (Gün/Hafta/Ay/Yıl).
final caloriePeriodProvider =
    StateProvider<CaloriePeriod>((ref) => CaloriePeriod.week);

/// Geriye dönük dönem sayısı: 0 = içinde bulunulan dönem.
/// Sekme değişince UI tarafı 0'a sıfırlar; gelecek döneme (negatif)
/// izin verilmez.
final calorieOffsetProvider = StateProvider<int>((ref) => 0);

final calorieChartDataProvider = FutureProvider<CalorieChartData>((ref) async {
  final period = ref.watch(caloriePeriodProvider);
  final offset = ref.watch(calorieOffsetProvider);
  final now = DateTime.now();

  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) {
    return CalorieChartAggregator.aggregate(
      period: period,
      offset: offset,
      now: now,
      meals: const [],
    );
  }

  final range = CalorieChartAggregator.rangeFor(period, offset, now);
  final meals = await ref
      .watch(mealLocalDataSourceProvider)
      .getMealsInRange(userId: userId, from: range.start, to: range.end);

  return CalorieChartAggregator.aggregate(
    period: period,
    offset: offset,
    now: now,
    meals: meals,
  );
});
```

**Step 2: Analyze**

Run: `flutter analyze`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/features/meals/presentation/providers/meal_chart_provider.dart
git commit -m "feat(meals): kalori grafiği provider katmanı"
```

---

### Task 7: Makro renk paleti

**Files:**
- Create: `lib/core/theme/macro_colors.dart`

**Step 1: Implementasyon**

```dart
import 'package:flutter/material.dart';

import '../constants/macro_reference_constants.dart';

/// Makro KİMLİK renkleri — "hangi makro" bilgisini taşır.
/// gaugeColor/riskColor ile karıştırma: onlar kalite/risk taşır (spec §6.2).
/// Sabit renklerdir; iki temada da aynı kalırlar (grafikte tutarlılık).
abstract final class MacroColors {
  static const Color protein = Color(0xFF6366F1); // indigo
  static const Color carbs = Color(0xFFF59E0B); // amber
  static const Color fat = Color(0xFFEC4899); // pembe

  /// Düşük/Normal/Yüksek etiket renkleri (referans: mavi/yeşil/turuncu).
  static Color levelColor(MacroLevel level) => switch (level) {
        MacroLevel.low => const Color(0xFF38BDF8),
        MacroLevel.normal => const Color(0xFF4ADE80),
        MacroLevel.high => const Color(0xFFFB923C),
      };
}
```

**Step 2: Analyze + Commit**

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/core/theme/macro_colors.dart
git commit -m "feat(theme): makro kimlik ve seviye renkleri"
```

---

### Task 8: `CaloriePeriodSelector` widget'ı

**Files:**
- Create: `lib/features/meals/presentation/widgets/calorie_period_selector.dart`

**Step 1: Implementasyon**

Segment pill'leri + `‹ tarih aralığı ›` satırı. `SegmentedButton` yerine tema diliyle uyumlu elle yapılmış pill grubu (mevcut `_Pill` estetiği).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calorie_chart_data.dart';
import '../providers/meal_chart_provider.dart';

class CaloriePeriodSelector extends ConsumerWidget {
  const CaloriePeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final period = ref.watch(caloriePeriodProvider);
    final offset = ref.watch(calorieOffsetProvider);

    String labelFor(CaloriePeriod p) => switch (p) {
          CaloriePeriod.day => l10n.caloriePeriodDay,
          CaloriePeriod.week => l10n.caloriePeriodWeek,
          CaloriePeriod.month => l10n.caloriePeriodMonth,
          CaloriePeriod.year => l10n.caloriePeriodYear,
        };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              for (final p in CaloriePeriod.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(caloriePeriodProvider.notifier).state = p;
                      ref.read(calorieOffsetProvider.notifier).state = 0;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: p == period ? colors.primary : null,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labelFor(p),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          // AppColorsExtension'da onPrimary yok; AppButton'ın
                          // primary-dolgu konvansiyonu (app_button.dart:112-116)
                          // seçili pilin üstünde de aynı şekilde Colors.black
                          // kullanır — iki temada da primary dolgu üstünde
                          // okunur kalır.
                          color: p == period
                              ? Colors.black
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: colors.textMuted,
              onPressed: () =>
                  ref.read(calorieOffsetProvider.notifier).state = offset + 1,
            ),
            Text(
              _rangeLabel(context, period, offset),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: colors.textMuted,
              // IconButton disabled durumda `color`'u değil `disabledColor`'ı
              // kullanır (Flutter davranışı) — disabledColor açıkça
              // verilmezse tema varsayılanına döner, tasarımdaki soluk
              // görünüm kaybolur.
              disabledColor: colors.textMuted.withValues(alpha: 0.3),
              // Gelecek döneme geçilemez (spec §11).
              onPressed: offset == 0
                  ? null
                  : () => ref.read(calorieOffsetProvider.notifier).state =
                      offset - 1,
            ),
          ],
        ),
      ],
    );
  }

  String _rangeLabel(BuildContext context, CaloriePeriod period, int offset) {
    final locale = Localizations.localeOf(context).toString();
    final range =
        CalorieChartAggregator.rangeFor(period, offset, DateTime.now());
    switch (period) {
      case CaloriePeriod.day:
        return DateFormat('d MMMM', locale).format(range.start);
      case CaloriePeriod.week:
        final end = range.end.subtract(const Duration(days: 1));
        final fmt = DateFormat('d MMM', locale);
        return '${fmt.format(range.start)} – ${fmt.format(end)}';
      case CaloriePeriod.month:
        return DateFormat('MMMM yyyy', locale).format(range.start);
      case CaloriePeriod.year:
        return DateFormat('yyyy', locale).format(range.start);
    }
  }
}
```

Not — `CalorieChartAggregator` import'u:
`../../domain/services/calorie_chart_aggregator.dart`.

**Step 2: Analyze + Commit**

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/features/meals/presentation/widgets/calorie_period_selector.dart
git commit -m "feat(meals): dönem seçici widget"
```

---

### Task 9: `CalorieStackedBarChart` + `MacroBalanceCard`

**Files:**
- Create: `lib/features/meals/presentation/widgets/calorie_stacked_bar_chart.dart`
- Create: `lib/features/meals/presentation/widgets/macro_balance_card.dart`
- Test: `test/features/meals/presentation/calorie_chart_widgets_test.dart`

**Step 1: Failing widget testleri yaz**

Kurulum deseni için `test/features/auth/onboarding_screen_test.dart`'taki
`MaterialApp` + `AppLocalizations.localizationsDelegates` sarmalayıcısını örnek al.

```dart
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
```

**Step 2: FAIL gör**

Run: `flutter test test/features/meals/presentation/calorie_chart_widgets_test.dart`
Expected: derleme hatası.

**Step 3: `calorie_stacked_bar_chart.dart` implementasyonu**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/macro_colors.dart';
import '../../domain/entities/calorie_chart_data.dart';
import '../../domain/entities/meal_entry_entity.dart';
import '../meal_display.dart';

class CalorieStackedBarChart extends StatelessWidget {
  final CalorieChartData data;

  const CalorieStackedBarChart({super.key, required this.data});

  static const double _chartHeight = 160;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxKcal = data.buckets
        .map((b) => b.kcal)
        .fold<double>(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight + 24, // bar + etiket satırı
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.buckets.length; i++)
                Expanded(child: _bar(context, i, maxKcal)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _legend(context, colors),
      ],
    );
  }

  Widget _bar(BuildContext context, int index, double maxKcal) {
    final colors = context.colors;
    final bucket = data.buckets[index];
    final heightFactor = maxKcal == 0 ? 0.0 : bucket.kcal / maxKcal;
    final barHeight = _chartHeight * heightFactor;
    final macro = bucket.macroKcal;

    // Ay görünümünde her barın etiketi sığmaz — 1, 8, 15, 22, 29.
    final showLabel =
        data.period != CaloriePeriod.month || index % 7 == 0;

    Widget segment(double kcal, Color color) {
      if (macro == 0 || kcal == 0) return const SizedBox.shrink();
      return SizedBox(
        // ColoredBox olmadan child verildiğinde, gevşek genişlik
        // kısıtında en küçük boyutu (0) seçer — width olmadan segment
        // görünmez bir dilime çöker.
        width: double.infinity,
        height: barHeight * (kcal / macro),
        child: ColoredBox(color: color),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: data.buckets.length > 12 ? 1.5 : 5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            child: bucket.kcal == 0
                ? const SizedBox.shrink()
                : macro == 0
                    // kcal var ama makro dökümü yok → nötr tek renk bar
                    ? SizedBox(
                        height: barHeight,
                        width: double.infinity,
                        child: ColoredBox(
                          color: colors.textMuted.withValues(alpha: 0.35),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            segment(bucket.proteinKcal, MacroColors.protein),
                            segment(bucket.carbKcal, MacroColors.carbs),
                            segment(bucket.fatKcal, MacroColors.fat),
                          ],
                        ),
                      ),
          ),
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                showLabel ? _labelFor(context, index) : '',
                style: TextStyle(fontSize: 10, color: colors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, int index) {
    final locale = Localizations.localeOf(context).toString();
    switch (data.period) {
      case CaloriePeriod.day:
        return mealTypeLabel(context.l10n, MealType.values[index]);
      case CaloriePeriod.week:
        final day = data.rangeStart.add(Duration(days: index));
        return DateFormat.E(locale).format(day);
      case CaloriePeriod.month:
        return '${index + 1}';
      case CaloriePeriod.year:
        final month = DateTime(data.rangeStart.year, index + 1);
        return DateFormat.MMM(locale).format(month);
    }
  }

  Widget _legend(BuildContext context, AppColorsExtension colors) {
    final l10n = context.l10n;
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        item(MacroColors.protein, l10n.macroProtein),
        item(MacroColors.carbs, l10n.macroCarbs),
        item(MacroColors.fat, l10n.macroFat),
      ],
    );
  }
}
```

Not: Gün görünümünde (`day`) öğün-tipi etiketleri uzun olabilir
(Kahvaltı/Ara Öğün) — 375px genişlikte taşma olursa `fontSize: 9` veya
`FittedBox` uygula; widget testi taşma hatasını yakalar.

**Step 4: `macro_balance_card.dart` implementasyonu**

`HealthScoreBar` görsel dili (`health_score_bar.dart`: surfaceCard, radius 24, padding 20, fontSize 42 w800 büyük sayı):

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/macro_reference_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/macro_colors.dart';
import '../../domain/entities/calorie_chart_data.dart';

class MacroBalanceCard extends StatelessWidget {
  final CalorieChartData data;

  const MacroBalanceCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDay = data.period == CaloriePeriod.day;
    final kcalValue = isDay ? data.totalKcal : data.avgKcalPerDay;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // toUpperCase() BİLEREK yok: Dart'ın toUpperCase()'i locale-aware
            // değil (Türkçe "i" → "İ" değil "I" olur) ve widget testi bu
            // metni verbatim ("Toplam"/"Günlük ortalama") arıyor — l10n
            // değeri zaten doğru büyük/küçük harfle yazılmış, üstüne
            // dokunmuyoruz.
            isDay ? l10n.calorieCardTotal : l10n.calorieCardAverageDaily,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${kcalValue.round()}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'kcal',
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _macroRow(context, l10n.macroProtein, MacroColors.protein,
              data.proteinPct, data.proteinLevel),
          const SizedBox(height: 10),
          _macroRow(context, l10n.macroCarbs, MacroColors.carbs, data.carbPct,
              data.carbLevel),
          const SizedBox(height: 10),
          _macroRow(
              context, l10n.macroFat, MacroColors.fat, data.fatPct,
              data.fatLevel),
        ],
      ),
    );
  }

  Widget _macroRow(
    BuildContext context,
    String name,
    Color identityColor,
    double pct,
    MacroLevel level,
  ) {
    final colors = context.colors;
    final l10n = context.l10n;
    final levelLabel = switch (level) {
      MacroLevel.low => l10n.macroLevelLow,
      MacroLevel.normal => l10n.macroLevelNormal,
      MacroLevel.high => l10n.macroLevelHigh,
    };
    final levelColor = MacroColors.levelColor(level);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: identityColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        Text(
          '%${pct.round()}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: levelColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            levelLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: levelColor,
            ),
          ),
        ),
      ],
    );
  }
}
```

**Step 5: Testler geç**

Run: `flutter test test/features/meals/presentation/calorie_chart_widgets_test.dart`
Expected: 3 test PASS. (Sayısal beklentiler — `1750`, `Normal`×3, `Yüksek`/`Düşük` — implementasyonla uyuşmazsa önce el hesabını doğrula, testi değil implementasyonu düzelt.)

**Step 6: Commit**

```bash
git add lib/features/meals/presentation/widgets test/features/meals/presentation/calorie_chart_widgets_test.dart
git commit -m "feat(meals): stacked bar grafik ve makro dengesi kartı"
```

---

### Task 10: MealsScreen entegrasyonu + eski özet kartların temizliği

**Files:**
- Modify: `lib/features/meals/presentation/screens/meals_screen.dart`
- Modify: `lib/features/meals/presentation/providers/meal_provider.dart` (mealCalorieSummaryProvider silinir)
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart:371`
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart:321,380`
- Test: `test/features/meals/presentation/meals_screen_chart_test.dart`

**Step 1: `meals_screen.dart` değişikliği**

1. `_SummaryCards` ve `_SummaryCard` sınıflarını sil (satır 88-154).
2. `summaryAsync` watch'ını (satır 29) sil.
3. Eski `SliverToBoxAdapter` (satır 47-56) yerine:

```dart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: _CalorieInsights(),
              ),
            ),
```

4. Dosya sonuna yeni bölüm widget'ı:

```dart
class _CalorieInsights extends ConsumerWidget {
  const _CalorieInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final chartAsync = ref.watch(calorieChartDataProvider);

    return Column(
      children: [
        const CaloriePeriodSelector(),
        const SizedBox(height: 14),
        chartAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (data) {
            if (data.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    context.l10n.calorieChartEmptyPeriod,
                    style: TextStyle(color: colors.textMuted),
                  ),
                ),
              );
            }
            return Column(
              children: [
                CalorieStackedBarChart(data: data),
                const SizedBox(height: 14),
                MacroBalanceCard(data: data),
              ],
            );
          },
        ),
      ],
    );
  }
}
```

5. Import'lar: `../widgets/calorie_period_selector.dart`, `../widgets/calorie_stacked_bar_chart.dart`, `../widgets/macro_balance_card.dart`, `../providers/meal_chart_provider.dart`.
6. `RefreshIndicator.onRefresh` (satır 42) ve `_confirmDelete` (satır 288): `ref.invalidate(mealCalorieSummaryProvider)` → `ref.invalidate(calorieChartDataProvider)`.

**Step 2: Ölü provider'ı sil + diğer call-site'ları güncelle**

`meal_provider.dart`'tan `mealCalorieSummaryProvider` (64-101) ve
`MealCalorieSummary` (103-109) silinir. Dart'ta iki dosya arasında
karşılıklı `import` geçerlidir (döngüsel import hatası vermez) — bu
yüzden her çağrı noktasında **doğrudan yer değiştirme** yapılır, dolaylı
`ref.listen` gerekmez:

1. `meal_provider.dart` başına ekle: `import 'meal_chart_provider.dart';`
2. `meal_provider.dart:52` (`mealCloudSyncProvider` içinde):
   `ref.invalidate(mealCalorieSummaryProvider)` → `ref.invalidate(calorieChartDataProvider)`
3. `food_result_screen.dart:371`: aynı değişiklik. Dosya zaten
   `import '../../../meals/presentation/providers/meal_provider.dart';`
   satırını içeriyor (3 seviye yukarı) — aynı deseni izleyerek yanına
   `import '../../../meals/presentation/providers/meal_chart_provider.dart';`
   ekle.
4. `profile_screen.dart:321` ve `:380`: aynı değişiklik. Bu dosya da
   `import '../../../meals/presentation/providers/meal_provider.dart';`
   kullanıyor (3 seviye yukarı) — aynı şekilde
   `import '../../../meals/presentation/providers/meal_chart_provider.dart';`
   ekle.

**Step 3: Failing ekran testi yaz**

`test/features/meals/presentation/meals_screen_chart_test.dart` — in-memory Drift + ProviderScope override ile:

```dart
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
```

Not: `appDatabaseProvider` (`Provider<AppDatabase>`, product_provider.dart:32),
`effectiveUserIdProvider` (`Provider<String?>`, app_session.dart:79),
`currentUserProvider` (`Provider<UserEntity?>`, auth_provider.dart:24) ve
`isPremiumProvider` (`Provider<bool>`, monetization_provider.dart:72) dördü
de düz `Provider` — `overrideWithValue` hepsinde geçerli.

**Step 4: Testler geç**

Run: `flutter test test/features/meals/presentation/meals_screen_chart_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: tüm suite PASS (silinen `mealCalorieSummaryProvider`'a referans kalmadığını da doğrular).

Run: `flutter analyze`
Expected: No issues found.

**Step 5: Commit**

```bash
git add lib test
git commit -m "feat(meals): kalori grafiği bölümünü Öğünlerim ekranına entegre et"
```

---

### Task 11: HomeWidgetService makro yüzdeleri

**Files:**
- Modify: `lib/core/services/home_widget_service.dart`
- Test: `test/core/services/home_widget_service_test.dart` (yeni)

**Step 1: Failing test yaz**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/home_widget_service.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  test('makro yüzdeleri Atwater kcal paylarından hesaplanır', () {
    final result = HomeWidgetService.macroPercentages([
      // 25g P=100kcal, 50g K=200kcal, ~11.1g Y=100kcal → 25/50/25
      NutrimentsEntity(proteins: 25, carbohydrates: 50, fat: 100 / 9),
    ]);
    expect(result.protein, 25);
    expect(result.carb, 50);
    expect(result.fat, 25);
  });

  test('veri yoksa hepsi 0', () {
    final result = HomeWidgetService.macroPercentages(const []);
    expect(result.protein, 0);
    expect(result.carb, 0);
    expect(result.fat, 0);
  });

  test('null alanlar 0 sayılır', () {
    final result = HomeWidgetService.macroPercentages(
      [const NutrimentsEntity(proteins: 10)],
    );
    expect(result.protein, 100);
    expect(result.carb, 0);
    expect(result.fat, 0);
  });
}
```

**Step 2: FAIL gör**

Run: `flutter test test/core/services/home_widget_service_test.dart`
Expected: derleme hatası (`macroPercentages` yok).

**Step 3: Implementasyon**

`home_widget_service.dart`'a:

1. Import ekle (dosya zaten `package:flutter/foundation.dart` import ediyor —
   `visibleForTesting` oradan gelir, yeni import gerekmez):

```dart
import '../constants/macro_reference_constants.dart';
import '../../features/product/data/models/nutriments_dto.dart';
import '../../features/product/domain/entities/nutriments_entity.dart';
```

2. Yeni anahtarlar (mevcutların altına):

```dart
  static const _keyProteinPct = 'today_protein_pct';
  static const _keyCarbPct = 'today_carb_pct';
  static const _keyFatPct = 'today_fat_pct';
```

3. Saf hesaplama (statik, test edilebilir):

```dart
  /// Bugünün makro-kcal paylarını (0-100 int) hesaplar. Payda üç
  /// makronun toplam kcal'idir; veri yoksa üçü de 0 döner.
  @visibleForTesting
  static ({int protein, int carb, int fat}) macroPercentages(
    Iterable<NutrimentsEntity> items,
  ) {
    var proteinKcal = 0.0, carbKcal = 0.0, fatKcal = 0.0;
    for (final n in items) {
      proteinKcal +=
          (n.proteins ?? 0) * MacroReferenceConstants.kcalPerGramProtein;
      carbKcal +=
          (n.carbohydrates ?? 0) * MacroReferenceConstants.kcalPerGramCarb;
      fatKcal += (n.fat ?? 0) * MacroReferenceConstants.kcalPerGramFat;
    }
    final total = proteinKcal + carbKcal + fatKcal;
    if (total == 0) return (protein: 0, carb: 0, fat: 0);
    return (
      protein: (proteinKcal / total * 100).round(),
      carb: (carbKcal / total * 100).round(),
      fat: (fatKcal / total * 100).round(),
    );
  }
```

4. `refresh()` içinde, `count` hesaplandıktan sonra:

```dart
      final macros = macroPercentages(
        rows.map((r) => NutrimentsDto.fromJsonString(r.nutriments)),
      );
```

ve `Future.wait` listesine 3 yazım ekle:

```dart
        HomeWidget.saveWidgetData<int>(_keyProteinPct, macros.protein),
        HomeWidget.saveWidgetData<int>(_keyCarbPct, macros.carb),
        HomeWidget.saveWidgetData<int>(_keyFatPct, macros.fat),
```

**Step 4: Testler geç**

Run: `flutter test test/core/services/home_widget_service_test.dart`
Expected: 3 test PASS.

**Step 5: Commit**

```bash
git add lib/core/services/home_widget_service.dart test/core/services/home_widget_service_test.dart
git commit -m "feat(widget): bugünün makro yüzdelerini native köprüye yaz"
```

---

### Task 12: Android native widget

**Files:**
- Modify: `android/app/src/main/res/layout/nutrilens_home_widget.xml`
- Modify: `android/app/src/main/kotlin/com/nutrilensapp/android/NutriLensHomeWidgetProvider.kt`

Native tarafta otomatik test yok (RemoteViews); doğrulama Task 14'te emülatörde manuel.

**Step 1: Layout — `widget_meal_count`'un altına (FrameLayout spacer'dan önce) ekle**

RemoteViews allow-list'i not: `ProgressBar` (horizontal style) RemoteViews-safe'tir.

```xml
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:orientation="vertical">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:id="@+id/widget_protein_label"
                android:layout_width="52dp"
                android:layout_height="wrap_content"
                android:text="P %0"
                android:textColor="#BBFFFFFF"
                android:textSize="10sp" />
            <ProgressBar
                android:id="@+id/widget_protein_bar"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="0dp"
                android:layout_weight="1"
                android:layout_height="4dp"
                android:max="100"
                android:progressTint="#6366F1"
                android:progressBackgroundTint="#33FFFFFF" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="3dp"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:id="@+id/widget_carb_label"
                android:layout_width="52dp"
                android:layout_height="wrap_content"
                android:text="K %0"
                android:textColor="#BBFFFFFF"
                android:textSize="10sp" />
            <ProgressBar
                android:id="@+id/widget_carb_bar"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="0dp"
                android:layout_weight="1"
                android:layout_height="4dp"
                android:max="100"
                android:progressTint="#F59E0B"
                android:progressBackgroundTint="#33FFFFFF" />
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="3dp"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:id="@+id/widget_fat_label"
                android:layout_width="52dp"
                android:layout_height="wrap_content"
                android:text="Y %0"
                android:textColor="#BBFFFFFF"
                android:textSize="10sp" />
            <ProgressBar
                android:id="@+id/widget_fat_bar"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="0dp"
                android:layout_weight="1"
                android:layout_height="4dp"
                android:max="100"
                android:progressTint="#EC4899"
                android:progressBackgroundTint="#33FFFFFF" />
        </LinearLayout>
    </LinearLayout>
```

**Step 2: Provider Kotlin — okuma + bağlama**

`onUpdate` içinde okuma bloğuna ekle (mevcut try içinde):

```kotlin
        var proteinPct = 0
        var carbPct = 0
        var fatPct = 0
        // ... mevcut prefs okuma try bloğu içine:
            proteinPct = prefs.getInt("today_protein_pct", 0)
            carbPct = prefs.getInt("today_carb_pct", 0)
            fatPct = prefs.getInt("today_fat_pct", 0)
```

RemoteViews bağlama bloğuna (kcal/meal_count set'lerinin altına):

```kotlin
                views.setTextViewText(R.id.widget_protein_label, "P %$proteinPct")
                views.setProgressBar(R.id.widget_protein_bar, 100, proteinPct, false)
                views.setTextViewText(R.id.widget_carb_label, "K %$carbPct")
                views.setProgressBar(R.id.widget_carb_bar, 100, carbPct, false)
                views.setTextViewText(R.id.widget_fat_label, "Y %$fatPct")
                views.setProgressBar(R.id.widget_fat_bar, 100, fatPct, false)
```

Not: mevcut layout'taki "BUGÜN"/"öğün · bugün" gibi native metinler hardcoded Türkçe — P/K/Y kısaltmaları da aynı konvansiyonu izler, l10n açılmaz.

**Step 3: Derleme doğrulaması**

Run: `cd android && ./gradlew :app:assembleDebug -q` (Windows'ta `gradlew.bat`)
Expected: BUILD SUCCESSFUL. (Yavaşsa Task 14'teki `flutter build apk --debug` ile birleştirilebilir — ama commit'ten önce en az bir kez derlenmeli.)

**Step 4: Commit**

```bash
git add android/app/src/main
git commit -m "feat(widget): Android widget'ına 3 makro göstergesi ekle"
```

---

### Task 13: iOS native widget

**Files:**
- Modify: `ios/NutriLensHomeWidget/NutriLensHomeWidget.swift`

macOS olmadan derlenemez — kod değişikliği yapılır, derleme/manuel doğrulama iOS build alınabilen ortama not düşülür (Task 14).

**Step 1: Entry ve Provider'ı genişlet**

```swift
private let kKeyProteinPct = "today_protein_pct"
private let kKeyCarbPct = "today_carb_pct"
private let kKeyFatPct = "today_fat_pct"

struct NutriLensEntry: TimelineEntry {
    let date: Date
    let kcal: Int
    let mealCount: Int
    let proteinPct: Int
    let carbPct: Int
    let fatPct: Int
}
```

`placeholder` → `NutriLensEntry(date: Date(), kcal: 0, mealCount: 0, proteinPct: 0, carbPct: 0, fatPct: 0)`.

`readEntry()`:

```swift
    private func readEntry() -> NutriLensEntry {
        let defaults = UserDefaults(suiteName: kAppGroup)
        return NutriLensEntry(
            date: Date(),
            kcal: defaults?.integer(forKey: kKeyKcal) ?? 0,
            mealCount: defaults?.integer(forKey: kKeyMealCount) ?? 0,
            proteinPct: defaults?.integer(forKey: kKeyProteinPct) ?? 0,
            carbPct: defaults?.integer(forKey: kKeyCarbPct) ?? 0,
            fatPct: defaults?.integer(forKey: kKeyFatPct) ?? 0
        )
    }
```

**Step 2: Makro satır view'ı + yerleşim**

Dosyaya ekle:

```swift
private struct MacroRow: View {
    let label: String
    let pct: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(label) %\(pct)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.8))
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 4)
        }
    }
}
```

`NutriLensHomeWidgetView.body` içinde, `Text("\(entry.mealCount) öğün · bugün")` ile `Spacer()` arasına:

```swift
                VStack(spacing: 3) {
                    MacroRow(label: "P", pct: entry.proteinPct,
                             color: Color(red: 0.39, green: 0.40, blue: 0.95)) // #6366F1
                    MacroRow(label: "K", pct: entry.carbPct,
                             color: Color(red: 0.96, green: 0.62, blue: 0.04)) // #F59E0B
                    MacroRow(label: "Y", pct: entry.fatPct,
                             color: Color(red: 0.93, green: 0.28, blue: 0.60)) // #EC4899
                }
                .padding(.top, 4)
```

**Step 3: Commit**

```bash
git add ios/NutriLensHomeWidget/NutriLensHomeWidget.swift
git commit -m "feat(widget): iOS widget'ına 3 makro göstergesi ekle"
```

---

### Task 14: Son doğrulama

**Step 1: Statik kontroller**

Run: `flutter analyze`
Expected: No issues found.

Run: `flutter test`
Expected: tüm testler PASS (409+ mevcut + yeni eklenenler).

**Step 2: Emülatörde manuel doğrulama (Android)**

1. `flutter run` ile debug build başlat (flutter-skill MCP araçları varsa `launch_app` + `screenshot` kullan).
2. Öğünlerim ekranı: sekmeler arası geçiş (Gün/Hafta/Ay/Yıl), `‹ ›` gezinme (sağ ok offset 0'da devre dışı olmalı), boş dönem mesajı, dolu dönemde bar + makro kart.
3. Bir öğün kaydet (veya mevcut test verisi) → grafik ve kart güncellensin.
4. Koyu + açık temada ekran görüntüsü al, taşma/kontrast kontrol et.
5. Home widget'ı ana ekrana ekle → kcal + 3 makro barı görünmeli; öğün kaydettikten sonra güncellenmeli.
6. Ekran görüntülerini kullanıcıya göster.

**Step 3: iOS notu**

iOS widget değişikliği bu makinede derlenemez (Windows). Kullanıcıya not: bir sonraki iOS build/TestFlight yüklemesinde `NutriLensHomeWidget` hedefinin derlendiğini ve widget'ın makroları gösterdiğini doğrula.

**Step 4: Vault güncellemesi**

- `wiki/03-current-sprint.md`: görev tamamlandı işaretle.
- `wiki/02-decisions-log.md`: makro referans aralıkları (%10-35/%45-65/%20-35) ve "kişisel hedef yok" kararı.
- `wiki/features/ogünlerim.md`: kalori grafiği bölümü eklendi notu.

**Step 5: Final commit (kalan değişiklikler varsa)**

```bash
git status
git add -A && git commit -m "chore(meals): kalori grafiği son rötuşlar"
```
