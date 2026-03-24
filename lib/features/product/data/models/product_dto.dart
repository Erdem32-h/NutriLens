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
    final additivesTags = (row['additives_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    final nutrimentsMap = row['nutriments'] as Map<String, dynamic>? ?? {};

    return ProductEntity(
      barcode: row['barcode'] as String,
      productName: row['product_name'] as String?,
      brands: row['brand'] as String?,
      imageUrl: row['image_url'] as String?,
      ingredientsText: row['ingredients_text'] as String?,
      additivesTags: additivesTags,
      novaGroup: row['nova_group'] as int?,
      nutriscoreGrade: row['nutriscore_grade'] as String?,
      nutriments: NutrimentsEntity(
        energyKcal: (nutrimentsMap['energy_kcal'] as num?)?.toDouble(),
        fat: (nutrimentsMap['fat'] as num?)?.toDouble(),
        saturatedFat: (nutrimentsMap['saturated_fat'] as num?)?.toDouble(),
        sugars: (nutrimentsMap['sugars'] as num?)?.toDouble(),
        salt: (nutrimentsMap['salt'] as num?)?.toDouble(),
        fiber: (nutrimentsMap['fiber'] as num?)?.toDouble(),
        proteins: (nutrimentsMap['proteins'] as num?)?.toDouble(),
      ),
      hpScore: (row['hp_score'] as num?)?.toDouble(),
      hpChemicalLoad: (row['hp_chemical_load'] as num?)?.toDouble(),
      hpRiskFactor: (row['hp_risk_factor'] as num?)?.toDouble(),
      hpNutriFactor: (row['hp_nutri_factor'] as num?)?.toDouble(),
    );
  }

  /// Converts lists to JSON string for Drift storage.
  static String _listToJson(List<String> list) => jsonEncode(list);

  /// Parses JSON string from Drift to list.
  static List<String> _jsonToList(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '[]') return const [];
    final decoded = jsonDecode(jsonStr);
    if (decoded is List) {
      return decoded.cast<String>();
    }
    return const [];
  }

  /// Converts a [ProductEntity] to a map suitable for Drift insertion.
  static Map<String, dynamic> toDriftMap(ProductEntity entity) {
    return {
      'barcode': entity.barcode,
      'productName': entity.productName,
      'brands': entity.brands,
      'imageUrl': entity.imageUrl,
      'ingredientsText': entity.ingredientsText,
      'allergensTags': _listToJson(entity.allergensTags),
      'additivesTags': _listToJson(entity.additivesTags),
      'novaGroup': entity.novaGroup,
      'nutriscoreGrade': entity.nutriscoreGrade,
      'nutriments': NutrimentsDto.toJsonString(entity.nutriments),
      'categoriesTags': _listToJson(entity.categoriesTags),
      'countriesTags': _listToJson(entity.countriesTags),
      'hpScore': entity.hpScore,
      'hpChemicalLoad': entity.hpChemicalLoad,
      'hpRiskFactor': entity.hpRiskFactor,
      'hpNutriFactor': entity.hpNutriFactor,
      'cachedAt': DateTime.now(),
    };
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
