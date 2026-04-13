import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/additive_entity.dart';
import '../entities/allergen_entity.dart';

abstract interface class AdditiveRepository {
  /// Fetches all additives matching the given E-codes.
  ///
  /// [eCodes] should be pre-normalised (e.g. "E471"), but implementations
  /// may apply additional normalisation as a safety measure.
  Future<Either<Failure, List<AdditiveEntity>>> getAdditivesByCodes(
    List<String> eCodes,
  );

  /// Fetches a single additive by its E-code, returning null when not found.
  Future<Either<Failure, AdditiveEntity?>> getAdditiveByCode(String eCode);

  /// Returns the full list of known allergens.
  Future<Either<Failure, List<AllergenEntity>>> getAllAllergens();

  /// Returns true when the local additives database has not yet been seeded.
  Future<Either<Failure, bool>> isSeedRequired();

  /// Seeds the local additives database from a raw JSON string.
  ///
  /// [jsonContent] is expected to be the contents of the bundled seed file.
  Future<Either<Failure, void>> seedFromJson(String jsonContent);
}
