import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/meal_local_datasource.dart';
import '../../domain/entities/meal_entry_entity.dart';

final mealLocalDataSourceProvider = Provider<MealLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MealLocalDataSourceImpl(db);
});

final mealsProvider = FutureProvider<List<MealEntryEntity>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final dataSource = ref.watch(mealLocalDataSourceProvider);
  return dataSource.getMeals(userId: userId);
});

final mealCalorieSummaryProvider = FutureProvider<MealCalorieSummary>((
  ref,
) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const MealCalorieSummary();

  final dataSource = ref.watch(mealLocalDataSourceProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month);
  final nextMonthStart = DateTime(now.year, now.month + 1);

  final values = await Future.wait<double>([
    dataSource.totalCalories(
      userId: userId,
      from: todayStart,
      to: tomorrowStart,
    ),
    dataSource.totalCalories(
      userId: userId,
      from: weekStart,
      to: tomorrowStart,
    ),
    dataSource.totalCalories(
      userId: userId,
      from: monthStart,
      to: nextMonthStart,
    ),
  ]);

  return MealCalorieSummary(
    today: values[0],
    week: values[1],
    month: values[2],
  );
});

class MealCalorieSummary {
  final double today;
  final double week;
  final double month;

  const MealCalorieSummary({this.today = 0, this.week = 0, this.month = 0});
}
