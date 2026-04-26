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
