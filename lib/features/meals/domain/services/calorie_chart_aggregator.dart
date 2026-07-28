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
