import '../entities/meal_entry_entity.dart';

class MealDefaults {
  final String name;
  final MealType type;
  final String brand;

  const MealDefaults({
    required this.name,
    required this.type,
    this.brand = 'Ev yapımı',
  });
}

MealDefaults mealDefaultsFor(DateTime capturedAt) {
  final hour = capturedAt.hour;
  if (hour >= 5 && hour <= 10) {
    return const MealDefaults(name: 'Kahvaltı', type: MealType.breakfast);
  }
  if (hour >= 11 && hour <= 15) {
    return const MealDefaults(name: 'Öğlen Yemeği', type: MealType.lunch);
  }
  if (hour >= 16 && hour <= 21) {
    return const MealDefaults(name: 'Akşam Yemeği', type: MealType.dinner);
  }
  return const MealDefaults(name: 'Ara Öğün', type: MealType.snack);
}

/// All app-generated default meal names across supported locales. A stored
/// name in this set is *not* user-authored, so the UI is free to re-render
/// it in the active language (via [MealType]) instead of showing the frozen
/// string that happened to be active at capture time.
const Set<String> kDefaultMealNames = {
  // tr
  'Kahvaltı', 'Öğlen Yemeği', 'Akşam Yemeği', 'Ara Öğün',
  // en
  'Breakfast', 'Lunch', 'Dinner', 'Snack',
};

/// App-generated default brand/source labels across locales.
const Set<String> kDefaultMealBrands = {'Ev yapımı', 'Homemade'};

bool isDefaultMealName(String name) => kDefaultMealNames.contains(name.trim());

bool isDefaultMealBrand(String brand) =>
    kDefaultMealBrands.contains(brand.trim());
