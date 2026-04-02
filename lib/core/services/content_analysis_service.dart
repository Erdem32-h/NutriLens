import 'package:flutter/material.dart';

import '../../features/product/domain/entities/product_entity.dart';
import '../constants/health_filter_options.dart';

enum WarningLevel { risky, caution, safe, natural }

class ContentWarning {
  final String messageKey;
  final String? placeholderKey;
  final IconData icon;
  final WarningLevel level;

  const ContentWarning({
    required this.messageKey,
    this.placeholderKey,
    required this.icon,
    required this.level,
  });
}

abstract final class ContentAnalysisService {
  static List<ContentWarning> analyzeIngredients({
    required ProductEntity product,
    List<String> activeAllergens = const [],
    List<String> activeDiets = const [],
    List<String> activeOils = const [],
    List<String> activeChemicals = const [],
  }) {
    final warnings = <ContentWarning>[];
    final nutriments = product.nutriments;
    final ingredients = product.ingredientsText?.toLowerCase() ?? '';

    // Check personal health filters first (they are more critical to the user)
    _checkPersonalFilters(
      ingredients: ingredients,
      activeIds: activeAllergens,
      options: HealthFilterOptions.allergens,
      warnings: warnings,
    );

    _checkPersonalFilters(
      ingredients: ingredients,
      activeIds: activeDiets,
      options: HealthFilterOptions.diets,
      warnings: warnings,
    );

    _checkPersonalFilters(
      ingredients: ingredients,
      activeIds: activeOils,
      options: HealthFilterOptions.oils,
      warnings: warnings,
    );

    _checkPersonalFilters(
      ingredients: ingredients,
      activeIds: activeChemicals,
      options: HealthFilterOptions.chemicals,
      warnings: warnings,
    );

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

  static void _checkPersonalFilters({
    required String ingredients,
    required List<String> activeIds,
    required List<FilterOption> options,
    required List<ContentWarning> warnings,
  }) {
    if (activeIds.isEmpty || ingredients.isEmpty) return;

    for (final id in activeIds) {
      final option = options.where((o) => o.id == id).firstOrNull;
      if (option != null) {
        final allTriggers = [...option.triggersTr, ...option.triggersEn];
        if (_containsAny(ingredients, allTriggers)) {
          warnings.add(ContentWarning(
            messageKey: 'containsFilteredItem',
            placeholderKey: option.nameKey,
            icon: Icons.health_and_safety_rounded,
            level: WarningLevel.risky, // Highly critical for personal filters
          ));
        }
      }
    }
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}
