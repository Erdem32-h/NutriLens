import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/product_entity.dart';
import '../models/nutriments_dto.dart';
import '../models/product_dto.dart';

abstract interface class ProductLocalDataSource {
  Future<ProductEntity?> getProduct(String barcode);
  Future<void> cacheProduct(ProductEntity product);
  Future<bool> isStale(String barcode);

  /// Returns up to [limit] cached products with a better HP score than
  /// [currentHpScore], excluding [barcode], ordered by score descending.
  Future<List<ProductEntity>> getAlternatives({
    required String barcode,
    required double currentHpScore,
    int limit = 5,
  });
}

final class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  final AppDatabase _db;

  const ProductLocalDataSourceImpl(this._db);

  @override
  Future<ProductEntity?> getProduct(String barcode) async {
    try {
      final query = _db.select(_db.foodProducts)
        ..where((t) => t.barcode.equals(barcode));

      final row = await query.getSingleOrNull();
      if (row == null) return null;

      return ProductDto.fromDriftRow(
        barcode: row.barcode,
        productName: row.productName,
        brands: row.brands,
        imageUrl: row.imageUrl,
        ingredientsText: row.ingredientsText,
        allergensTags: row.allergensTags,
        additivesTags: row.additivesTags,
        novaGroup: row.novaGroup,
        nutriscoreGrade: row.nutriscoreGrade,
        nutriments: row.nutriments,
        categoriesTags: row.categoriesTags,
        countriesTags: row.countriesTags,
        hpScore: row.hpScore,
        hpChemicalLoad: row.hpChemicalLoad,
        hpRiskFactor: row.hpRiskFactor,
        hpNutriFactor: row.hpNutriFactor,
      );
    } catch (e) {
      throw CacheException('Failed to read cached product: $e');
    }
  }

  @override
  Future<void> cacheProduct(ProductEntity product) async {
    try {
      await _db.into(_db.foodProducts).insertOnConflictUpdate(
            FoodProductsCompanion.insert(
              barcode: product.barcode,
              productName: Value(product.productName),
              brands: Value(product.brands),
              imageUrl: Value(product.imageUrl),
              ingredientsText: Value(product.ingredientsText),
              allergensTags: Value(_listToJsonString(product.allergensTags)),
              additivesTags: Value(_listToJsonString(product.additivesTags)),
              novaGroup: Value(product.novaGroup),
              nutriscoreGrade: Value(product.nutriscoreGrade),
              nutriments: Value(
                NutrimentsDto.toJsonString(product.nutriments),
              ),
              categoriesTags: Value(_listToJsonString(product.categoriesTags)),
              countriesTags: Value(_listToJsonString(product.countriesTags)),
              hpScore: Value(product.hpScore),
              hpChemicalLoad: Value(product.hpChemicalLoad),
              hpRiskFactor: Value(product.hpRiskFactor),
              hpNutriFactor: Value(product.hpNutriFactor),
            ),
          );
    } catch (e) {
      throw CacheException('Failed to cache product: $e');
    }
  }

  @override
  Future<bool> isStale(String barcode) async {
    try {
      final query = _db.select(_db.foodProducts)
        ..where((t) => t.barcode.equals(barcode));

      final row = await query.getSingleOrNull();
      if (row == null) return true;

      final age = DateTime.now().difference(row.cachedAt);
      return age > AppConstants.cacheTtl;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<List<ProductEntity>> getAlternatives({
    required String barcode,
    required double currentHpScore,
    int limit = 5,
  }) async {
    try {
      final query = _db.select(_db.foodProducts)
        ..where(
          (t) =>
              t.barcode.equals(barcode).not() &
              t.hpScore.isBiggerThanValue(currentHpScore),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.hpScore)])
        ..limit(limit);

      final rows = await query.get();
      return rows
          .map(
            (row) => ProductDto.fromDriftRow(
              barcode: row.barcode,
              productName: row.productName,
              brands: row.brands,
              imageUrl: row.imageUrl,
              ingredientsText: row.ingredientsText,
              allergensTags: row.allergensTags,
              additivesTags: row.additivesTags,
              novaGroup: row.novaGroup,
              nutriscoreGrade: row.nutriscoreGrade,
              nutriments: row.nutriments,
              categoriesTags: row.categoriesTags,
              countriesTags: row.countriesTags,
              hpScore: row.hpScore,
              hpChemicalLoad: row.hpChemicalLoad,
              hpRiskFactor: row.hpRiskFactor,
              hpNutriFactor: row.hpNutriFactor,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  String _listToJsonString(List<String> list) => jsonEncode(list);
}
