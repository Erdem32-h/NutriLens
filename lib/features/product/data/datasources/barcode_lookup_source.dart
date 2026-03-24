import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/product_entity.dart';
import 'product_source.dart';

/// UPC Item DB — free barcode lookup. Usually returns only product name and brand.
/// Ingredients/nutrition are rarely available.
final class BarcodeLookupSource implements ProductSource {
  final Dio _dio;
  final _logger = Logger();

  BarcodeLookupSource(this._dio);

  @override
  String get name => 'barcode_lookup';

  @override
  int get priority => 2;

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<ProductEntity?> resolve(String barcode) async {
    try {
      final response = await _dio.get(
        ApiConstants.upcItemDbBaseUrl,
        queryParameters: {'upc': barcode},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'NutriLens/1.0.0',
          },
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200) return null;

      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;

      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final title = item['title'] as String?;
      final brand = item['brand'] as String?;

      if (title == null || title.isEmpty) return null;

      return ProductEntity(
        barcode: barcode,
        productName: title,
        brands: brand,
        imageUrl: _extractImageUrl(item),
      );
    } catch (e) {
      _logger.w('BarcodeLookupSource error for $barcode: $e');
      return null;
    }
  }

  String? _extractImageUrl(Map<String, dynamic> item) {
    final images = item['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      return images.first as String?;
    }
    return null;
  }
}
