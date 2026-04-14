import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../models/counterfeit_dto.dart';
import '../../domain/entities/counterfeit_entity.dart';

abstract interface class CounterfeitLocalDataSource {
  /// Checks by barcode (exact) first, then by brand (case-insensitive).
  Future<CounterfeitEntity?> findMatch({
    required String barcode,
    String? brand,
  });

  /// Replaces all cached records with [records].
  Future<void> replaceAll(List<CounterfeitEntity> records);

  /// Returns the timestamp of the most recent sync, or null if never synced.
  Future<DateTime?> lastSyncedAt();
}

final class CounterfeitLocalDataSourceImpl
    implements CounterfeitLocalDataSource {
  final AppDatabase _db;

  const CounterfeitLocalDataSourceImpl(this._db);

  @override
  Future<CounterfeitEntity?> findMatch({
    required String barcode,
    String? brand,
  }) async {
    try {
      // 1. Exact barcode match
      final byBarcode = await (_db.select(_db.counterfeitProducts)
            ..where((t) => t.barcode.equals(barcode)))
          .getSingleOrNull();
      if (byBarcode != null) return CounterfeitDto.fromRow(byBarcode);

      // 2. Brand fuzzy match (case-insensitive contains)
      if (brand != null && brand.isNotEmpty) {
        final lowerBrand = brand.toLowerCase();
        final allRows = await _db.select(_db.counterfeitProducts).get();
        final matched = allRows.firstWhere(
          (r) => r.brandName.toLowerCase().contains(lowerBrand) ||
              lowerBrand.contains(r.brandName.toLowerCase()),
          orElse: () => throw StateError('not_found'),
        );
        return CounterfeitDto.fromRow(matched);
      }

      return null;
    } on StateError {
      return null;
    } catch (e) {
      throw CacheException('Failed to query counterfeit DB: $e');
    }
  }

  @override
  Future<void> replaceAll(List<CounterfeitEntity> records) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.counterfeitProducts).go();
        for (final entity in records) {
          await _db.into(_db.counterfeitProducts).insertOnConflictUpdate(
                CounterfeitProductsCompanion.insert(
                  id: entity.id,
                  brandName: entity.brandName,
                  productName: entity.productName,
                  category: Value(entity.category),
                  violationType: entity.violationType,
                  violationDetail: Value(entity.violationDetail),
                  province: Value(entity.province),
                  detectionDate: Value(entity.detectionDate),
                  barcode: Value(entity.barcode),
                  sourceUrl: Value(entity.sourceUrl),
                ),
              );
        }
      });
    } catch (e) {
      throw CacheException('Failed to replace counterfeit records: $e');
    }
  }

  @override
  Future<DateTime?> lastSyncedAt() async {
    try {
      final row = await (_db.select(_db.counterfeitProducts)
            ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)])
            ..limit(1))
          .getSingleOrNull();
      return row?.syncedAt;
    } catch (_) {
      return null;
    }
  }
}
