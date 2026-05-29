import 'package:nutrilens/l10n/generated/app_localizations.dart';

import '../domain/entities/meal_entry_entity.dart';
import '../domain/services/meal_defaults.dart';

/// Localized label for a [MealType].
String mealTypeLabel(AppLocalizations l10n, MealType type) => switch (type) {
  MealType.breakfast => l10n.mealTypeBreakfast,
  MealType.lunch => l10n.mealTypeLunch,
  MealType.dinner => l10n.mealTypeDinner,
  MealType.snack => l10n.mealTypeSnack,
};

/// Display name for a meal: user-authored names are shown verbatim, but
/// app-generated defaults are re-localized to the active language (so a
/// meal saved as "Akşam Yemeği" shows "Dinner" once the app is switched
/// to English, and vice-versa).
String displayMealName(AppLocalizations l10n, MealEntryEntity meal) {
  if (meal.mealName.trim().isEmpty || isDefaultMealName(meal.mealName)) {
    return mealTypeLabel(l10n, meal.mealType);
  }
  return meal.mealName;
}

/// Display brand/source: default "Homemade"/"Ev yapımı" is re-localized,
/// custom sources are shown as-is.
String displayMealBrand(AppLocalizations l10n, String brand) {
  if (brand.trim().isEmpty || isDefaultMealBrand(brand)) {
    return l10n.mealBrandHomemade;
  }
  return brand;
}
