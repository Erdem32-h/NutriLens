import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../datasources/product_remote_datasource.dart';

final class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;
  final ProductLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  const ProductRepositoryImpl({
    required ProductRemoteDataSource remoteDataSource,
    required ProductLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, ProductEntity>> getProduct(String barcode) async {
    // 1. Check local cache
    try {
      final cached = await _localDataSource.getProduct(barcode);
      if (cached != null) {
        final stale = await _localDataSource.isStale(barcode);
        if (!stale) {
          // Fresh cache - return immediately
          return Right(cached);
        }

        // Stale cache - try remote, fall back to stale
        return _fetchRemoteWithFallback(barcode, staleCached: cached);
      }
    } on CacheException {
      // Cache read failed, try remote
    }

    // 2. No cache - must fetch from remote
    return _fetchRemote(barcode);
  }

  @override
  Future<Either<Failure, void>> cacheProduct(ProductEntity product) async {
    try {
      await _localDataSource.cacheProduct(product);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> getCachedProduct(
    String barcode,
  ) async {
    try {
      final cached = await _localDataSource.getProduct(barcode);
      if (cached == null) {
        return const Left(NotFoundFailure('Product not found in cache'));
      }
      return Right(cached);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Future<Either<Failure, ProductEntity>> _fetchRemoteWithFallback(
    String barcode, {
    required ProductEntity staleCached,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      // Offline but have stale cache - return it
      return Right(staleCached);
    }

    try {
      final product = await _remoteDataSource.getProduct(barcode);
      await _localDataSource.cacheProduct(product);
      return Right(product);
    } on NotFoundException {
      // Product was removed from OFF - still return stale cache
      return Right(staleCached);
    } on RateLimitException {
      return Right(staleCached);
    } catch (_) {
      // Network error - return stale cache
      return Right(staleCached);
    }
  }

  Future<Either<Failure, ProductEntity>> _fetchRemote(String barcode) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      return const Left(NetworkFailure());
    }

    try {
      final product = await _remoteDataSource.getProduct(barcode);
      await _localDataSource.cacheProduct(product);
      return Right(product);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on RateLimitException catch (e) {
      return Left(RateLimitFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
