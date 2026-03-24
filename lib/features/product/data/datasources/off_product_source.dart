import 'package:logger/logger.dart';

import '../../domain/entities/product_entity.dart';
import 'product_remote_datasource.dart';
import 'product_source.dart';

/// Wraps existing ProductRemoteDataSource (Open Food Facts) as a ProductSource.
final class OpenFoodFactsSource implements ProductSource {
  final ProductRemoteDataSource _remoteDataSource;
  final _logger = Logger();

  OpenFoodFactsSource(this._remoteDataSource);

  @override
  String get name => 'open_food_facts';

  @override
  int get priority => 1;

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<ProductEntity?> resolve(String barcode) async {
    try {
      return await _remoteDataSource.getProduct(barcode);
    } catch (e) {
      _logger.w('OpenFoodFactsSource error for $barcode: $e');
      return null;
    }
  }
}
