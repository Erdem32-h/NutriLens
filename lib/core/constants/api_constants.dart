abstract final class ApiConstants {
  static const String offBaseUrl = 'https://world.openfoodfacts.org';
  static const String offProductEndpoint = '/api/v2/product/';
  static const String offSearchEndpoint = '/cgi/search.pl';

  static const int offProductRateLimit = 100;
  static const int offSearchRateLimit = 10;

  static const Duration requestTimeout = Duration(seconds: 15);
}
