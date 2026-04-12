import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class SubmitCommunityProductUseCase {
  final ProductRepository _repository;

  const SubmitCommunityProductUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required ProductEntity product,
    required String userId,
    String? ingredientsPhotoUrl,
    String source = 'ocr',
  }) => _repository.submitCommunityProduct(
        product: product,
        userId: userId,
        ingredientsPhotoUrl: ingredientsPhotoUrl,
        source: source,
      );
}
