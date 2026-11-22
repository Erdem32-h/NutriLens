import 'package:flutter/services.dart';

import '../domain/entities/nutrient_entity.dart';
import '../domain/repositories/nutrient_repository.dart';
import 'nutrient_parser.dart';

class AssetNutrientRepository implements NutrientRepository {
  AssetNutrientRepository(
    this._bundle, {
    this.assetPath = 'assets/nutrients/nutrients.json',
  });

  final AssetBundle _bundle;
  final String assetPath;

  Future<List<NutrientEntity>>? _cache;

  @override
  Future<List<NutrientEntity>> getAll() {
    final cached = _cache;
    if (cached != null) return cached;

    final load = _bundle.loadString(assetPath).then(parseNutrients);
    _cache = load;
    // A failed load must not stick: the screen's "try again" re-calls getAll.
    load.catchError((Object _) {
      if (identical(_cache, load)) _cache = null;
      return <NutrientEntity>[];
    });
    return load;
  }
}
