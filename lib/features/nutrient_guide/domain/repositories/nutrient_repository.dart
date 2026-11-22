import '../entities/nutrient_entity.dart';

abstract class NutrientRepository {
  /// Every nutrient in the guide, in the order the content file lists them.
  Future<List<NutrientEntity>> getAll();
}
