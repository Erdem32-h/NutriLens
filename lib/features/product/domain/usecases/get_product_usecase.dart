import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProductUseCase {
  final ProductRepository _repository;

  const GetProductUseCase(this._repository);

  Future<Either<Failure, ProductEntity>> call(String barcode) {
    if (barcode.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Barcode cannot be empty')),
      );
    }
    return _repository.getProduct(barcode);
  }
}
