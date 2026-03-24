import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../data/datasources/community_product_source.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../entities/product_entity.dart';

class SubmitCommunityProductUseCase {
  final CommunityProductSource _communitySource;
  final ProductLocalDataSource _localDataSource;

  const SubmitCommunityProductUseCase({
    required CommunityProductSource communitySource,
    required ProductLocalDataSource localDataSource,
  })  : _communitySource = communitySource,
        _localDataSource = localDataSource;

  Future<Either<Failure, void>> call({
    required ProductEntity product,
    required String userId,
    String? ingredientsPhotoUrl,
    String source = 'ocr',
  }) async {
    try {
      // Save to Supabase community DB
      await _communitySource.addProduct(
        product: product,
        ingredientsPhotoUrl: ingredientsPhotoUrl,
        userId: userId,
        source: source,
      );

      // Cache locally in Drift
      await _localDataSource.cacheProduct(product);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to submit product: $e'));
    }
  }
}
