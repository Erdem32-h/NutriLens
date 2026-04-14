import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/drift/app_database.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/counterfeit_local_datasource.dart';
import '../../data/repositories/counterfeit_repository_impl.dart';
import '../../domain/entities/counterfeit_entity.dart';
import '../../domain/usecases/check_counterfeit_usecase.dart';

// --- Wiring ---

final counterfeitLocalDsProvider = Provider<CounterfeitLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CounterfeitLocalDataSourceImpl(db);
});

final counterfeitRepositoryProvider =
    Provider<CounterfeitRepositoryImpl>((ref) {
  return CounterfeitRepositoryImpl(
    local: ref.watch(counterfeitLocalDsProvider),
    supabase: Supabase.instance.client,
  );
});

final checkCounterfeitUseCaseProvider =
    Provider<CheckCounterfeitUseCase>((ref) {
  return CheckCounterfeitUseCase(ref.watch(counterfeitRepositoryProvider));
});

// --- UI Provider ---

/// Returns the counterfeit record for a given (barcode, brand) pair, or null
/// if the product is not in the Tarım Bakanlığı list.
final counterfeitCheckProvider = FutureProvider.family<CounterfeitEntity?,
    ({String barcode, String? brand})>((ref, args) async {
  final useCase = ref.watch(checkCounterfeitUseCaseProvider);
  final result =
      await useCase(barcode: args.barcode, brand: args.brand);
  return result.fold((_) => null, (entity) => entity);
});

/// Triggers a manual sync of the counterfeit list from Supabase.
Future<void> syncCounterfeitList(AppDatabase db) async {
  final ds = CounterfeitLocalDataSourceImpl(db);
  final repo = CounterfeitRepositoryImpl(
    local: ds,
    supabase: Supabase.instance.client,
  );
  await repo.syncFromSupabase();
}
