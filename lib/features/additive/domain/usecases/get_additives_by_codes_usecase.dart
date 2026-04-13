import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/hp_score_calculator.dart';
import '../entities/additive_entity.dart';
import '../repositories/additive_repository.dart';

class GetAdditivesByCodesUsecase {
  final AdditiveRepository _repository;

  const GetAdditivesByCodesUsecase(this._repository);

  /// Looks up all [AdditiveEntity] records matching [eCodes].
  ///
  /// Each code is normalised via [HpScoreCalculator.normalizeECode] before the
  /// repository call so that raw Open Food Facts tags (e.g. "en:e471") are
  /// converted to the canonical form ("E471") used in the database.
  ///
  /// Duplicate codes are de-duplicated after normalisation.
  Future<Either<Failure, List<AdditiveEntity>>> call(
    List<String> eCodes,
  ) async {
    final normalised = eCodes
        .map(HpScoreCalculator.normalizeECode)
        .toSet()
        .toList(growable: false);

    return _repository.getAdditivesByCodes(normalised);
  }
}
