import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/meal_local_datasource.dart';
import '../../data/datasources/meal_remote_datasource.dart';
import '../../data/services/meal_sync_service.dart';
import '../../data/services/meal_thumbnail_service.dart';
import '../../domain/entities/meal_entry_entity.dart';

final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetService(ref.watch(appDatabaseProvider));
});

final mealLocalDataSourceProvider = Provider<MealLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MealLocalDataSourceImpl(db);
});

// --- Premium cloud sync ---

final mealRemoteDataSourceProvider = Provider<MealRemoteDataSource>((ref) {
  return MealRemoteDataSource(ref.watch(supabaseClientProvider));
});

final mealSyncServiceProvider = Provider<MealSyncService>((ref) {
  return MealSyncService(
    ref.watch(mealLocalDataSourceProvider),
    ref.watch(mealRemoteDataSourceProvider),
    const MealThumbnailService(),
  );
});

/// Premium-only: when a signed-in user is premium, runs a one-shot full sync
/// (upload pending local meals + pull cloud meals down) and refreshes the meal
/// lists if anything changed. No-op for free/guest users. Watched by the meals
/// screen so it fires when the user lands there.
final mealCloudSyncProvider = Provider<void>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (!isPremium || userId == null) return;
  final sync = ref.read(mealSyncServiceProvider);
  Future(() async {
    final changed = await sync.fullSyncOnce(userId);
    if (changed) {
      ref.invalidate(mealsProvider);
      ref.invalidate(mealCalorieSummaryProvider);
    }
  });
});

final mealsProvider = FutureProvider<List<MealEntryEntity>>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return [];
  final dataSource = ref.watch(mealLocalDataSourceProvider);
  return dataSource.getMeals(userId: userId);
});

final mealCalorieSummaryProvider = FutureProvider<MealCalorieSummary>((
  ref,
) async {
  final userId = ref.watch(effectiveUserIdProvider);
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
