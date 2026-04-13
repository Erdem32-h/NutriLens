import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/allergen_entity.dart';
import '../repositories/additive_repository.dart';

class GetAllAllergensUsecase {
  final AdditiveRepository _repository;

  const GetAllAllergensUsecase(this._repository);

  /// Returns the full list of known [AllergenEntity] records.
  Future<Either<Failure, List<AllergenEntity>>> call() async {
    return _repository.getAllAllergens();
  }
}
