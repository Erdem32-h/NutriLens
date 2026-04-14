import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/counterfeit_entity.dart';

abstract interface class CounterfeitRepository {
  /// Checks if a product matches any counterfeit record.
  /// Matches by barcode (exact) or brand name (case-insensitive contains).
  /// Returns [null] when no match is found.
  Future<Either<Failure, CounterfeitEntity?>> checkProduct({
    required String barcode,
    String? brand,
  });

  /// Fetches all counterfeit records from Supabase and caches locally.
  Future<Either<Failure, void>> syncFromSupabase();
}
