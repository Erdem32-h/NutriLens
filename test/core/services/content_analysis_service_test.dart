import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens/core/services/content_analysis_service.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

void main() {
  ProductEntity makeProduct({
    int? novaGroup,
    double? sugars,
    double? saturatedFat,
    double? salt,
    String? ingredientsText,
  }) {
    return ProductEntity(
      barcode: '1234567890',
      novaGroup: novaGroup,
      ingredientsText: ingredientsText,
      nutriments: NutrimentsEntity(
        sugars: sugars,
        saturatedFat: saturatedFat,
        salt: salt,
      ),
    );
  }

  group('ContentAnalysisService.analyzeIngredients', () {
    test('returns empty list for product with no issues', () {
      final product = makeProduct(
        novaGroup: 1,
        sugars: 2.0,
        saturatedFat: 1.0,
        salt: 0.3,
        ingredientsText: 'water, wheat flour',
      );

      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result, isEmpty);
    });

    test('detects NOVA 4 ultra-processed', () {
      final product = makeProduct(novaGroup: 4);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'ultraProcessed'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'ultraProcessed');
      expect(warning.level, WarningLevel.risky);
    });

    test('does not flag NOVA 1, 2, 3 as ultra-processed', () {
      for (final nova in [1, 2, 3]) {
        final product = makeProduct(novaGroup: nova);
        final result = ContentAnalysisService.analyzeIngredients(product: product);
        expect(
          result.any((w) => w.messageKey == 'ultraProcessed'),
          isFalse,
          reason: 'NOVA $nova should not be flagged',
        );
      }
    });

    test('detects high sugar (> 22.5g)', () {
      final product = makeProduct(sugars: 30.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'highSugar'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'highSugar');
      expect(warning.level, WarningLevel.risky);
    });

    test('detects moderate sugar (> 5g but <= 22.5g)', () {
      final product = makeProduct(sugars: 15.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'moderateSugar'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'moderateSugar');
      expect(warning.level, WarningLevel.caution);
    });

    test('does not flag low sugar (<= 5g)', () {
      final product = makeProduct(sugars: 3.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'highSugar'), isFalse);
      expect(result.any((w) => w.messageKey == 'moderateSugar'), isFalse);
    });

    test('detects high saturated fat (> 5g)', () {
      final product = makeProduct(saturatedFat: 8.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'highSaturatedFat'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'highSaturatedFat');
      expect(warning.level, WarningLevel.risky);
    });

    test('does not flag low saturated fat (<= 5g)', () {
      final product = makeProduct(saturatedFat: 3.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'highSaturatedFat'), isFalse);
    });

    test('detects high salt (> 1.5g)', () {
      final product = makeProduct(salt: 2.5);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'highSalt'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'highSalt');
      expect(warning.level, WarningLevel.risky);
    });

    test('does not flag low salt (<= 1.5g)', () {
      final product = makeProduct(salt: 0.5);
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'highSalt'), isFalse);
    });

    test('detects palm oil in ingredients', () {
      final product = makeProduct(
        ingredientsText: 'sugar, palm oil, flour',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'containsPalmOil'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'containsPalmOil');
      expect(warning.level, WarningLevel.risky);
    });

    test('detects palmiye yağı (Turkish palm oil)', () {
      final product = makeProduct(
        ingredientsText: 'şeker, palmiye yağı, un',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'containsPalmOil'), isTrue);
    });

    test('detects trans fat in ingredients', () {
      final product = makeProduct(
        ingredientsText: 'partially hydrogenated soybean oil',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'mayContainTransFat'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'mayContainTransFat');
      expect(warning.level, WarningLevel.caution);
    });

    test('detects flavorings in ingredients', () {
      final product = makeProduct(
        ingredientsText: 'sugar, natural flavor, salt',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'containsFlavoring'), isTrue);
      final warning = result.firstWhere((w) => w.messageKey == 'containsFlavoring');
      expect(warning.level, WarningLevel.caution);
    });

    test('detects aroma verici (Turkish flavoring)', () {
      final product = makeProduct(
        ingredientsText: 'şeker, aroma verici, tuz',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'containsFlavoring'), isTrue);
    });

    test('handles null ingredientsText gracefully', () {
      final product = makeProduct(ingredientsText: null);
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      // Should not throw, and should not contain ingredient-text-based warnings
      expect(result.any((w) => w.messageKey == 'containsPalmOil'), isFalse);
      expect(result.any((w) => w.messageKey == 'mayContainTransFat'), isFalse);
      expect(result.any((w) => w.messageKey == 'containsFlavoring'), isFalse);
    });

    test('handles null nutriment values gracefully', () {
      final product = makeProduct();
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      // Should not throw, and should not contain nutriment-based warnings
      expect(result.any((w) => w.messageKey == 'highSugar'), isFalse);
      expect(result.any((w) => w.messageKey == 'moderateSugar'), isFalse);
      expect(result.any((w) => w.messageKey == 'highSaturatedFat'), isFalse);
      expect(result.any((w) => w.messageKey == 'highSalt'), isFalse);
    });

    test('case-insensitive ingredient matching', () {
      final product = makeProduct(
        ingredientsText: 'PALM OIL, FLAVOR',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'containsPalmOil'), isTrue);
      expect(result.any((w) => w.messageKey == 'containsFlavoring'), isTrue);
    });

    test('multiple warnings stack correctly', () {
      final product = makeProduct(
        novaGroup: 4,
        sugars: 30.0,
        saturatedFat: 10.0,
        salt: 2.0,
        ingredientsText: 'palm oil, aroma, partially hydrogenated oil',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      // Should have: ultraProcessed, highSugar, highSaturatedFat, highSalt,
      //              containsPalmOil, containsFlavoring, mayContainTransFat
      expect(result.length, 7);
    });

    test('all warnings have valid icons', () {
      final product = makeProduct(
        novaGroup: 4,
        sugars: 30.0,
        saturatedFat: 10.0,
        salt: 2.0,
        ingredientsText: 'palm oil, aroma, partially hydrogenated oil',
      );
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      for (final warning in result) {
        expect(warning.icon, isA<IconData>());
      }
    });

    test('sugar boundary: exactly 22.5g is caution not risky', () {
      final product = makeProduct(sugars: 22.5);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'highSugar'), isFalse);
      expect(result.any((w) => w.messageKey == 'moderateSugar'), isTrue);
    });

    test('sugar boundary: exactly 5.0g is not flagged', () {
      final product = makeProduct(sugars: 5.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);

      expect(result.any((w) => w.messageKey == 'highSugar'), isFalse);
      expect(result.any((w) => w.messageKey == 'moderateSugar'), isFalse);
    });

    test('saturated fat boundary: exactly 5.0g is not flagged', () {
      final product = makeProduct(saturatedFat: 5.0);
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'highSaturatedFat'), isFalse);
    });

    test('salt boundary: exactly 1.5g is not flagged', () {
      final product = makeProduct(salt: 1.5);
      final result = ContentAnalysisService.analyzeIngredients(product: product);
      expect(result.any((w) => w.messageKey == 'highSalt'), isFalse);
    });
  });

  group('WarningLevel enum', () {
    test('has all expected values', () {
      expect(WarningLevel.values.length, 4);
      expect(WarningLevel.values, contains(WarningLevel.risky));
      expect(WarningLevel.values, contains(WarningLevel.caution));
      expect(WarningLevel.values, contains(WarningLevel.safe));
      expect(WarningLevel.values, contains(WarningLevel.natural));
    });
  });

  group('ContentWarning', () {
    test('stores all fields', () {
      const warning = ContentWarning(
        messageKey: 'testKey',
        icon: Icons.warning,
        level: WarningLevel.risky,
      );

      expect(warning.messageKey, 'testKey');
      expect(warning.icon, Icons.warning);
      expect(warning.level, WarningLevel.risky);
    });
  });
}
