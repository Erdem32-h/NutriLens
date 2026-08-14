import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/calorie_target_calculator.dart';
import '../../../../core/session/app_session.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/user_metrics_local_datasource.dart';
import '../../domain/entities/user_metrics_entity.dart';

final userMetricsLocalDataSourceProvider = Provider<UserMetricsLocalDataSource>(
  (ref) => UserMetricsLocalDataSourceImpl(ref.watch(appDatabaseProvider)),
);

/// `effectiveUserIdProvider` yalnızca çıkış yapılmış kullanıcıda null döner
/// (router zaten /login'e yönlendirmiş olur) — o durumda metrics de yok.
final userMetricsProvider = FutureProvider<UserMetricsEntity?>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return null;
  return ref.watch(userMetricsLocalDataSourceProvider).get(userId);
});

/// Günlük kalori hedefi. Metrics girilmemişse besin etiketlerinin klasik
/// 2000 kcal varsayımına düşer — hiçbir ekran metrics'in varlığına bağımlı
/// olmamalı.
final dailyCalorieTargetProvider = Provider<int>((ref) {
  final metrics = ref.watch(userMetricsProvider).value;
  if (metrics == null) return kDefaultDailyCalories;
  return calculateCalorieTarget(metrics.toCalculatorInput(DateTime.now())).target;
});
