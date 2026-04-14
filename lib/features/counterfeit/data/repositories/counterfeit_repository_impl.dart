import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/counterfeit_entity.dart';
import '../../domain/repositories/counterfeit_repository.dart';
import '../datasources/counterfeit_local_datasource.dart';
import '../models/counterfeit_dto.dart';

class CounterfeitRepositoryImpl implements CounterfeitRepository {
  final CounterfeitLocalDataSource _local;
  final SupabaseClient _supabase;

  /// Re-sync if cached data is older than this threshold.
  static const _syncThreshold = Duration(days: 7);

  const CounterfeitRepositoryImpl({
    required CounterfeitLocalDataSource local,
    required SupabaseClient supabase,
  }) : _local = local,
       _supabase = supabase;

  @override
  Future<Either<Failure, CounterfeitEntity?>> checkProduct({
    required String barcode,
    String? brand,
  }) async {
    try {
      // Auto-sync if stale
      final lastSync = await _local.lastSyncedAt();
      if (lastSync == null ||
          DateTime.now().difference(lastSync) > _syncThreshold) {
        await syncFromSupabase();
      }

      final result = await _local.findMatch(barcode: barcode, brand: brand);
      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncFromSupabase() async {
    try {
      final response = await _supabase
          .from('counterfeit_products')
          .select()
          .order('synced_at', ascending: false);

      final rows = response as List<dynamic>;
      final entities = rows
          .map((r) => CounterfeitDto.fromSupabase(r as Map<String, dynamic>))
          .toList();

      await _local.replaceAll(entities);
      return const Right(null);
    } catch (e) {
      // Sync failure is non-critical; don't surface to UI
      return Left(ServerFailure('Counterfeit sync failed: $e'));
    }
  }
}
