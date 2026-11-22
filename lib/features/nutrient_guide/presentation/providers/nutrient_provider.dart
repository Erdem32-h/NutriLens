import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/asset_nutrient_repository.dart';
import '../../domain/entities/nutrient_entity.dart';
import '../../domain/repositories/nutrient_repository.dart';

final nutrientRepositoryProvider = Provider<NutrientRepository>(
  (ref) => AssetNutrientRepository(rootBundle),
);

/// No automatic retry: the content ships inside the app, so a failure is a
/// packaging bug that backoff cannot fix. The screen shows an error with a
/// manual "try again" instead of a spinner that runs for tens of seconds.
final nutrientsProvider = FutureProvider<List<NutrientEntity>>(
  (ref) => ref.watch(nutrientRepositoryProvider).getAll(),
  retry: (_, _) => null,
);

/// Null when no nutrient has that id (e.g. a stale deep link).
final nutrientByIdProvider = FutureProvider.family<NutrientEntity?, String>((
  ref,
  id,
) async {
  final all = await ref.watch(nutrientsProvider.future);
  for (final n in all) {
    if (n.id == id) return n;
  }
  return null;
});
