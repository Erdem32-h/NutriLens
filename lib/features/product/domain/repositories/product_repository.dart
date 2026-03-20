import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';

abstract interface class ProductRepository {
  Future<Either<Failure, ProductEntity>> getProduct(String barcode);

  Future<Either<Failure, void>> cacheProduct(ProductEntity product);

  Future<Either<Failure, ProductEntity>> getCachedProduct(String barcode);
}
