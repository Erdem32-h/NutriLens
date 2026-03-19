abstract final class AppConstants {
  static const String appName = 'NutriLens';
  static const String appVersion = '1.0.0';

  static const String userAgent = 'NutriLens/1.0 (contact@nutrilens.app)';

  static const Duration cacheTtl = Duration(days: 7);
  static const int scanDebounceMs = 3000;
  static const int historyPageSize = 20;
  static const int maxAlternatives = 5;
}
