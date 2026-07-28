// Riverpod 3 moved StateProvider/StateController to the legacy library.
import 'package:flutter_riverpod/legacy.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
