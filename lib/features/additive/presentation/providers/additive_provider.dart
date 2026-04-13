import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/product/presentation/providers/product_provider.dart';
import '../../data/datasources/additive_local_datasource.dart';
import '../../data/repositories/additive_repository_impl.dart';
import '../../domain/entities/additive_entity.dart';
import '../../domain/entities/allergen_entity.dart';
import '../../domain/repositories/additive_repository.dart';
import '../../domain/usecases/get_additives_by_codes_usecase.dart';
import '../../domain/usecases/get_all_allergens_usecase.dart';

// --- Data Sources ---

final additiveLocalDataSourceProvider =
    Provider<AdditiveLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AdditiveLocalDataSourceImpl(db);
});

// --- Repository ---

final additiveRepositoryProvider = Provider<AdditiveRepository>((ref) {
  final local = ref.watch(additiveLocalDataSourceProvider);
  return AdditiveRepositoryImpl(local);
});

// --- Use Cases ---

final getAdditivesByCodesUsecaseProvider =
    Provider<GetAdditivesByCodesUsecase>((ref) {
  return GetAdditivesByCodesUsecase(ref.watch(additiveRepositoryProvider));
});

final getAllAllergensUsecaseProvider =
    Provider<GetAllAllergensUsecase>((ref) {
  return GetAllAllergensUsecase(ref.watch(additiveRepositoryProvider));
});

// --- Seed Status (run once on app start) ---

final additiveSeedProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(additiveRepositoryProvider);

  final needsSeed = await repo.isSeedRequired();
  if (needsSeed.getOrElse((_) => false)) {
    final jsonStr = await rootBundle.loadString(
      'assets/additives/additives_database.json',
    );
    await repo.seedFromJson(jsonStr);
  }
});

// --- Additive queries ---

/// Returns a list of [AdditiveEntity] for the given E-codes.
/// Falls back to empty list on error.
final additiveEntitiesByCodesProvider = FutureProvider.family<
    List<AdditiveEntity>, List<String>>((ref, codes) async {
  // Wait for seed to complete
  await ref.watch(additiveSeedProvider.future);

  if (codes.isEmpty) return [];
  final usecase = ref.watch(getAdditivesByCodesUsecaseProvider);
  final result = await usecase(codes);
  return result.getOrElse((_) => []);
});

/// Returns a single [AdditiveEntity] for the given E-code, or null.
final additiveByCodeProvider =
    FutureProvider.family<AdditiveEntity?, String>((ref, code) async {
  await ref.watch(additiveSeedProvider.future);

  final repo = ref.watch(additiveRepositoryProvider);
  final result = await repo.getAdditiveByCode(code);
  return result.getOrElse((_) => null);
});

/// Returns all allergens from the local database.
final allAllergensProvider =
    FutureProvider<List<AllergenEntity>>((ref) async {
  final usecase = ref.watch(getAllAllergensUsecaseProvider);
  final result = await usecase();
  return result.getOrElse((_) => []);
});
