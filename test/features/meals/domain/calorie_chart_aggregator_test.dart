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
