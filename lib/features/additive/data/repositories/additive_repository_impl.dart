import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/additive_entity.dart';
import '../../domain/entities/allergen_entity.dart';
import '../../domain/repositories/additive_repository.dart';
import '../datasources/additive_local_datasource.dart';

class AdditiveRepositoryImpl implements AdditiveRepository {
  final AdditiveLocalDataSource _local;

  const AdditiveRepositoryImpl(this._local);

  @override
  Future<Either<Failure, List<AdditiveEntity>>> getAdditivesByCodes(
    List<String> eCodes,
  ) async {
    try {
      final result = await _local.getAdditivesByCodes(eCodes);
      return Right(result);
    } catch (e) {
      return Left(CacheFailure('Failed to fetch additives: $e'));
    }
  }

  @override
  Future<Either<Failure, AdditiveEntity?>> getAdditiveByCode(
    String eCode,
  ) async {
    try {
      final result = await _local.getAdditiveByCode(eCode);
      return Right(result);
    } catch (e) {
      return Left(CacheFailure('Failed to fetch additive $eCode: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AllergenEntity>>> getAllAllergens() async {
    try {
      final result = await _local.getAllAllergens();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure('Failed to fetch allergens: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isSeedRequired() async {
    try {
      final result = await _local.isSeedRequired();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure('Failed to check seed status: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> seedFromJson(String jsonContent) async {
    try {
      await _local.seedFromJson(jsonContent);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to seed additives: $e'));
    }
  }
}
