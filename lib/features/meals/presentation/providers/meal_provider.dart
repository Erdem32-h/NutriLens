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
import 'meal_chart_provider.dart';

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
      ref.invalidate(calorieChartDataProvider);
      ref.invalidate(todayCalorieTotalProvider);
    }
  });
});

final mealsProvider = FutureProvider<List<MealEntryEntity>>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return [];
  final dataSource = ref.watch(mealLocalDataSourceProvider);
  return dataSource.getMeals(userId: userId);
});

/// Bugünün (yerel gece yarısından şimdiye) toplam alınan kalorisi.
/// Öğünlerim ekranındaki "alınan / hedef" özet satırını besler —
/// grafik bölümünün dönem sekmesinden (calorieChartDataProvider,
/// caloriePeriodProvider/calorieOffsetProvider) bilerek bağımsızdır:
/// kullanıcı grafikte Ay/Yıl sekmesine geçse bile bu satır her zaman
/// BUGÜNÜ gösterir. Diğer meal-mutasyon noktalarıyla aynı elle-invalidate
/// deseni izlenir (bkz. bu dosyadaki + meals_screen.dart + profile_screen.dart
/// içindeki mealsProvider/calorieChartDataProvider invalidate çağrıları) —
/// provider zincirini watch üzerinden kurmak yerine.
final todayCalorieTotalProvider = FutureProvider<double>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return 0;
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final dataSource = ref.watch(mealLocalDataSourceProvider);
  return dataSource.totalCalories(
    userId: userId,
    from: startOfDay,
    to: startOfDay.add(const Duration(days: 1)),
  );
});

