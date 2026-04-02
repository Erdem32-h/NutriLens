import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../datasources/product_source.dart';

final class ProductRepositoryImpl implements ProductRepository {
  final ProductResolver _resolver;
  final ProductLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  const ProductRepositoryImpl({
    required ProductResolver resolver,
    required ProductLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _resolver = resolver,
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
          return Right(cached);
        }
        // Stale cache — try resolver, fall back to stale
        return _resolveWithFallback(barcode, staleCached: cached);
      }
    } on CacheException {
      // Cache read failed, continue to resolver
    }

    // 2. No cache — resolve from remote sources
    return _resolveFromSources(barcode);
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

  Future<Either<Failure, ProductEntity>> _resolveWithFallback(
    String barcode, {
    required ProductEntity staleCached,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      return Right(staleCached);
    }

    try {
      final result = await _resolver.resolve(barcode).timeout(
        const Duration(seconds: 16),
      );
      if (result.isFound) {
        // Cache write is fire-and-forget — never block product display
        try {
          await _localDataSource.cacheProduct(result.product!);
        } on CacheException catch (_) {
          // SQLite unavailable — proceed without caching
        }
        return Right(result.product!);
      }
      // Not found in any source — return stale cache
      return Right(staleCached);
    } catch (_) {
      return Right(staleCached);
    }
  }

  Future<Either<Failure, ProductEntity>> _resolveFromSources(
    String barcode,
  ) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      return const Left(NetworkFailure());
    }

    try {
      final result = await _resolver.resolve(barcode).timeout(
        const Duration(seconds: 16),
      );
      if (result.isFound) {
        // Cache write is fire-and-forget — never block product display
        try {
          await _localDataSource.cacheProduct(result.product!);
        } on CacheException catch (_) {
          // SQLite unavailable — proceed without caching
        }
        return Right(result.product!);
      }
      return const Left(NotFoundFailure());
    } on TimeoutException {
      return const Left(ServerFailure('Product fetch timed out'));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
