import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/counterfeit_entity.dart';
import '../repositories/counterfeit_repository.dart';

class CheckCounterfeitUseCase {
  final CounterfeitRepository _repository;

  const CheckCounterfeitUseCase(this._repository);

  Future<Either<Failure, CounterfeitEntity?>> call({
    required String barcode,
    String? brand,
  }) =>
      _repository.checkProduct(barcode: barcode, brand: brand);
}
