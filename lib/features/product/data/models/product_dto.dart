import 'dart:convert';

import 'package:openfoodfacts/openfoodfacts.dart';

import '../../domain/entities/nutriments_entity.dart';
import '../../domain/entities/product_entity.dart';
import 'nutriments_dto.dart';

abstract final class ProductDto {
  /// Maps OFF SDK [Product] to our [ProductEntity].
  static ProductEntity fromOffProduct(Product product) {
    return ProductEntity(
      barcode: product.barcode ?? '',
      productName: product.productName,
      brands: product.brands,
      imageUrl: product.imageFrontUrl,
      ingredientsText: product.ingredientsText,
      allergensTags: product.allergens?.ids ?? const [],
      additivesTags: product.additives?.ids ?? const [],
      novaGroup: product.novaGroup,
      nutriscoreGrade: product.nutriscore,
      nutriments: NutrimentsDto.fromOffNutriments(product.nutriments),
      categoriesTags: product.categoriesTags ?? const [],
      countriesTags: product.countriesTags ?? const [],
    );
  }

  /// Maps a Supabase community_products row to [ProductEntity].
  static ProductEntity fromCommunityRow(Map<String, dynamic> row) {
    final additivesTags = _safeListFromRow(row['additives_tags']);
    final nutrimentsMap = _safeMapFromRow(row['nutriments']);

    return ProductEntity(
      barcode: row['barcode']?.toString() ?? '',
      productName: row['product_name']?.toString(),
      brands: row['brand']?.toString(),
      imageUrl: row['image_url']?.toString(),
      ingredientsText: row['ingredients_text']?.toString(),
      additivesTags: additivesTags,
      novaGroup: _safeInt(row['nova_group']),
      nutriscoreGrade: row['nutriscore_grade']?.toString(),
      nutriments: NutrimentsEntity(
        energyKcal: _safeDouble(nutrimentsMap['energy_kcal']),
        fat: _safeDouble(nutrimentsMap['fat']),
        saturatedFat: _safeDouble(nutrimentsMap['saturated_fat']),
        sugars: _safeDouble(nutrimentsMap['sugars']),
        salt: _safeDouble(nutrimentsMap['salt']),
        fiber: _safeDouble(nutrimentsMap['fiber']),
        proteins: _safeDouble(nutrimentsMap['proteins']),
      ),
      hpScore: _safeDouble(row['hp_score']),
      hpChemicalLoad: _safeDouble(row['hp_chemical_load']),
      hpRiskFactor: _safeDouble(row['hp_risk_factor']),
      hpNutriFactor: _safeDouble(row['hp_nutri_factor']),
    );
  }

  /// Safely extracts a List<String> from a dynamic Supabase value.
  /// Handles: List, JSON string, null.
  static List<String> _safeListFromRow(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        // Not valid JSON
      }
    }
    return const [];
  }

  /// Safely extracts a Map<String, dynamic> from a dynamic Supabase value.
  /// Handles: Map, JSON string, null.
  static Map<String, dynamic> _safeMapFromRow(dynamic value) {
    if (value == null) return const {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Not valid JSON
      }
    }
    return const {};
  }

  /// Safely parses a double from a dynamic value.
  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely parses an int from a dynamic value.
  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parses JSON string from Drift to list.
  static List<String> _jsonToList(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '[]') return const [];
    final decoded = jsonDecode(jsonStr);
    if (decoded is List) {
      return decoded.cast<String>();
    }
    return const [];
  }

  /// Converts a Drift row to a [ProductEntity].
  static ProductEntity fromDriftRow({
    required String barcode,
    String? productName,
    String? brands,
    String? imageUrl,
    String? ingredientsText,
    required String allergensTags,
    required String additivesTags,
    int? novaGroup,
    String? nutriscoreGrade,
    required String nutriments,
    required String categoriesTags,
    required String countriesTags,
    double? hpScore,
    double? hpChemicalLoad,
    double? hpRiskFactor,
    double? hpNutriFactor,
  }) {
    return ProductEntity(
      barcode: barcode,
      productName: productName,
      brands: brands,
      imageUrl: imageUrl,
      ingredientsText: ingredientsText,
      allergensTags: _jsonToList(allergensTags),
      additivesTags: _jsonToList(additivesTags),
      novaGroup: novaGroup,
      nutriscoreGrade: nutriscoreGrade,
      nutriments: NutrimentsDto.fromJsonString(nutriments),
      categoriesTags: _jsonToList(categoriesTags),
      countriesTags: _jsonToList(countriesTags),
      hpScore: hpScore,
      hpChemicalLoad: hpChemicalLoad,
      hpRiskFactor: hpRiskFactor,
      hpNutriFactor: hpNutriFactor,
    );
  }
}
