import 'package:flutter/material.dart';

import '../../features/product/domain/entities/product_entity.dart';

enum WarningLevel { risky, caution, safe, natural }

class ContentWarning {
  final String messageKey;
  final IconData icon;
  final WarningLevel level;

  const ContentWarning({
    required this.messageKey,
    required this.icon,
    required this.level,
  });
}

abstract final class ContentAnalysisService {
  static List<ContentWarning> analyzeIngredients(ProductEntity product) {
    final warnings = <ContentWarning>[];
    final nutriments = product.nutriments;
    final ingredients = product.ingredientsText?.toLowerCase() ?? '';

    // NOVA Group 4 = ultra-processed
    if (product.novaGroup == 4) {
      warnings.add(const ContentWarning(
        messageKey: 'ultraProcessed',
        icon: Icons.warning_amber_rounded,
        level: WarningLevel.risky,
      ));
    }

    // Sugar thresholds (per 100g)
    final sugars = nutriments.sugars;
    if (sugars != null) {
      if (sugars > 22.5) {
        warnings.add(const ContentWarning(
          messageKey: 'highSugar',
          icon: Icons.local_cafe_rounded,
          level: WarningLevel.risky,
        ));
      } else if (sugars > 5.0) {
        warnings.add(const ContentWarning(
          messageKey: 'moderateSugar',
          icon: Icons.local_cafe_outlined,
          level: WarningLevel.caution,
        ));
      }
    }

    // Saturated fat threshold (per 100g)
    final satFat = nutriments.saturatedFat;
    if (satFat != null && satFat > 5.0) {
      warnings.add(const ContentWarning(
        messageKey: 'highSaturatedFat',
        icon: Icons.water_drop_rounded,
        level: WarningLevel.risky,
      ));
    }

    // Salt threshold (per 100g)
    final salt = nutriments.salt;
    if (salt != null && salt > 1.5) {
      warnings.add(const ContentWarning(
        messageKey: 'highSalt',
        icon: Icons.grain_rounded,
        level: WarningLevel.risky,
      ));
    }

    // Palm oil detection
    if (_containsAny(ingredients, ['palm', 'palmiye', 'hurma yağı'])) {
      warnings.add(const ContentWarning(
        messageKey: 'containsPalmOil',
        icon: Icons.eco_rounded,
        level: WarningLevel.risky,
      ));
    }

    // Trans fat detection
    if (_containsAny(ingredients, ['trans yağ', 'trans fat', 'partially hydrogenated'])) {
      warnings.add(const ContentWarning(
        messageKey: 'mayContainTransFat',
        icon: Icons.do_not_disturb_alt_rounded,
        level: WarningLevel.caution,
      ));
    }

    // Flavoring detection
    if (_containsAny(ingredients, ['aroma', 'flavor', 'flavour', 'aroma verici'])) {
      warnings.add(const ContentWarning(
        messageKey: 'containsFlavoring',
        icon: Icons.science_rounded,
        level: WarningLevel.caution,
      ));
    }

    return warnings;
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}
