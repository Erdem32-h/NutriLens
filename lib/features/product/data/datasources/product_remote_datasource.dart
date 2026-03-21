import 'package:openfoodfacts/openfoodfacts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/product_entity.dart';
import '../models/product_dto.dart';

abstract interface class ProductRemoteDataSource {
  Future<ProductEntity> getProduct(String barcode);
}

final class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  ProductRemoteDataSourceImpl() {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'NutriLens',
      version: AppConstants.appVersion,
      url: 'https://nutrilens.app',
    );
    OpenFoodAPIConfiguration.globalLanguages = const [
      OpenFoodFactsLanguage.TURKISH,
      OpenFoodFactsLanguage.ENGLISH,
    ];
  }

  @override
  Future<ProductEntity> getProduct(String barcode) async {
    try {
      final configuration = ProductQueryConfiguration(
        barcode,
        version: ProductQueryVersion.v3,
        language: OpenFoodFactsLanguage.TURKISH,
        fields: [
          ProductField.BARCODE,
          ProductField.NAME,
          ProductField.BRANDS,
          ProductField.IMAGE_FRONT_URL,
          ProductField.INGREDIENTS_TEXT,
          ProductField.ALLERGENS,
          ProductField.ADDITIVES,
          ProductField.NOVA_GROUP,
          ProductField.NUTRISCORE,
          ProductField.NUTRIMENTS,
          ProductField.CATEGORIES_TAGS,
          ProductField.COUNTRIES_TAGS,
        ],
      );

      final result = await OpenFoodAPIClient.getProductV3(configuration);

      if (result.status == ProductResultV3.statusSuccess ||
          result.status == ProductResultV3.statusWarning) {
        final product = result.product;
        if (product == null) {
          throw const NotFoundException('Product data is empty');
        }
        return ProductDto.fromOffProduct(product);
      }

      throw NotFoundException('Product not found for barcode: $barcode');
    } on NotFoundException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('429') ||
          e.toString().contains('rate limit')) {
        throw const RateLimitException();
      }
      throw ServerException(
        'Failed to fetch product: ${e.toString()}',
      );
    }
  }
}
