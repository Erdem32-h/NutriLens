import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/nutriments_entity.dart';
import '../../domain/entities/product_entity.dart';
import 'product_source.dart';

/// USDA FoodData Central — free branded-food lookup (data.gov API key).
///
/// FDC has no dedicated barcode endpoint, so we hit `/foods/search` with the
/// scanned code and accept only an *exact* GTIN/UPC match (search is fuzzy and
/// will otherwise return unrelated products). Branded foods carry an
/// `ingredients` string and `foodNutrients` reported per 100 g, which lines up
/// with our [NutrimentsEntity] convention.
///
/// The corpus is US-centric, so hit rate on Turkish barcodes is low — this
/// sits late in the resolver chain (after OFF + UPC Item DB) purely as a free
/// extra fallback. When [_apiKey] is empty the source no-ops so a missing key
/// never breaks the chain.
final class UsdaFdcSource implements ProductSource {
  final Dio _dio;
  final String _apiKey;
  final _logger = Logger();

  UsdaFdcSource(this._dio, this._apiKey);

  @override
  String get name => 'usda_fdc';

  @override
  int get priority => 3;

  @override
  Duration get timeout => const Duration(seconds: 6);

  @override
  Future<ProductEntity?> resolve(String barcode) async {
    if (_apiKey.isEmpty) return null;
    try {
      final response = await _dio.get(
        ApiConstants.usdaFdcSearchUrl,
        queryParameters: {
          'api_key': _apiKey,
          'query': barcode,
          'dataType': 'Branded',
          'pageSize': 5,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode != 200) return null;

      final data = response.data as Map<String, dynamic>;
      final foods = data['foods'] as List<dynamic>?;
      if (foods == null || foods.isEmpty) return null;

      // Search is fuzzy — only trust a row whose GTIN/UPC matches the scan.
      final match = foods.cast<Map<String, dynamic>>().firstWhere(
        (f) => _gtinMatches(f['gtinUpc']?.toString(), barcode),
        orElse: () => const <String, dynamic>{},
      );
      if (match.isEmpty) return null;

      final name = (match['description'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;

      return ProductEntity(
        barcode: barcode,
        productName: _titleCase(name),
        brands: (match['brandOwner'] ?? match['brandName'])?.toString().trim(),
        ingredientsText: (match['ingredients'] as String?)?.trim(),
        nutriments: _mapNutriments(match['foodNutrients'] as List<dynamic>?),
      );
    } catch (e) {
      _logger.w('UsdaFdcSource error for $barcode: $e');
      return null;
    }
  }

  /// GTINs from FDC are often zero-padded to 14 digits; the scanned EAN-13 is
  /// not. Compare after stripping leading zeros so "0007310070007511" matches
  /// "7310070007511".
  bool _gtinMatches(String? gtin, String barcode) {
    if (gtin == null || gtin.isEmpty) return false;
    String strip(String s) => s.replaceFirst(RegExp(r'^0+'), '');
    return strip(gtin) == strip(barcode);
  }

  /// Map FDC `foodNutrients` (per 100 g) to our entity by USDA nutrient id.
  NutrimentsEntity _mapNutriments(List<dynamic>? nutrients) {
    if (nutrients == null) return const NutrimentsEntity();
    final byId = <int, double>{};
    for (final n in nutrients) {
      final m = n as Map<String, dynamic>;
      final id = (m['nutrientId'] as num?)?.toInt();
      final value = (m['value'] as num?)?.toDouble();
      if (id != null && value != null) byId[id] = value;
    }
    final sodiumMg = byId[1093]; // Sodium, Na (mg)
    return NutrimentsEntity(
      energyKcal: byId[1008], // Energy (kcal)
      fat: byId[1004], // Total lipid (fat)
      saturatedFat: byId[1258], // Fatty acids, total saturated
      transFat: byId[1257], // Fatty acids, total trans
      carbohydrates: byId[1005], // Carbohydrate, by difference
      sugars: byId[2000] ?? byId[1063], // Sugars, total
      fiber: byId[1079] ?? byId[2033], // Fiber, total dietary
      proteins: byId[1003], // Protein
      // Label salt isn't reported; derive from sodium (mg → g, ×2.5).
      salt: sodiumMg != null ? sodiumMg / 1000 * 2.5 : null,
    );
  }

  /// FDC branded descriptions are usually ALL CAPS — soften to Title Case so
  /// they read consistently with OFF product names in the UI.
  String _titleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
