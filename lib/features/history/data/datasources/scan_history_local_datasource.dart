import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/error/exceptions.dart';

/// A record combining scan history with cached product info.
class ScanHistoryWithProduct {
  final String id;
  final String barcode;
  final DateTime scannedAt;
  final double? hpScoreAtScan;
  final String? productName;
  final String? brands;
  final String? imageUrl;

  const ScanHistoryWithProduct({
    required this.id,
    required this.barcode,
    required this.scannedAt,
    this.hpScoreAtScan,
    this.productName,
    this.brands,
    this.imageUrl,
  });
}

abstract interface class ScanHistoryLocalDataSource {
  Future<void> addScan({
    required String userId,
    required String barcode,
    double? hpScore,
  });

  Future<List<ScanHistoryWithProduct>> getHistory({
    required String userId,
    int limit = 50,
  });

  Future<void> clearHistory(String userId);
}

final class ScanHistoryLocalDataSourceImpl
    implements ScanHistoryLocalDataSource {
  final AppDatabase _db;
  static const _uuid = Uuid();

  const ScanHistoryLocalDataSourceImpl(this._db);

  @override
  Future<void> addScan({
    required String userId,
    required String barcode,
    double? hpScore,
  }) async {
    try {
      // Önce aynı barkoda sahip kayıt var mı kontrol et
      final existing = await (_db.select(_db.scanHistory)
            ..where((t) => t.userId.equals(userId) & t.barcode.equals(barcode)))
          .getSingleOrNull();

      if (existing != null) {
        // Varsa, sadece tarihini güncelle
        await (_db.update(_db.scanHistory)
              ..where((t) => t.id.equals(existing.id)))
            .write(ScanHistoryCompanion(scannedAt: Value(DateTime.now())));
      } else {
        // Yoksa yeni kayıt ekle
        await _db.into(_db.scanHistory).insert(
              ScanHistoryCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                barcode: barcode,
                hpScoreAtScan: Value(hpScore),
              ),
            );
      }
    } catch (e) {
      throw CacheException('Failed to save scan history: $e');
    }
  }

  @override
  Future<List<ScanHistoryWithProduct>> getHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      // Join scan_history with food_products to get product info
      final query = _db.select(_db.scanHistory).join([
        leftOuterJoin(
          _db.foodProducts,
          _db.foodProducts.barcode.equalsExp(_db.scanHistory.barcode),
        ),
      ]);

      query
        ..where(_db.scanHistory.userId.equals(userId))
        ..orderBy([OrderingTerm.desc(_db.scanHistory.scannedAt)])
        ..limit(limit);

      final rows = await query.get();

      return rows.map((row) {
        final scan = row.readTable(_db.scanHistory);
        final product = row.readTableOrNull(_db.foodProducts);

        return ScanHistoryWithProduct(
          id: scan.id,
          barcode: scan.barcode,
          scannedAt: scan.scannedAt,
          hpScoreAtScan: scan.hpScoreAtScan,
          productName: product?.productName,
          brands: product?.brands,
          imageUrl: product?.imageUrl,
        );
      }).toList();
    } catch (e) {
      throw CacheException('Failed to read scan history: $e');
    }
  }

  @override
  Future<void> clearHistory(String userId) async {
    try {
      final query = _db.delete(_db.scanHistory)
        ..where((t) => t.userId.equals(userId));
      await query.go();
    } catch (e) {
      throw CacheException('Failed to clear scan history: $e');
    }
  }
}
