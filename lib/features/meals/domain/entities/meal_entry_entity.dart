import 'package:equatable/equatable.dart';

import '../../../product/domain/entities/nutriments_entity.dart';

enum MealType { breakfast, lunch, dinner, snack }

class MealEntryEntity extends Equatable {
  final String id;
  final String userId;
  final String? photoThumbnailPath;
  final String mealName;
  final String brand;
  final MealType mealType;
  final DateTime capturedAt;
  final String? ingredientsText;
  final NutrimentsEntity nutriments;
  final double calories;
  final double? hpScore;
  final double? confidence;
  final String? aiRawJson;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MealEntryEntity({
    required this.id,
    required this.userId,
    this.photoThumbnailPath,
    required this.mealName,
    this.brand = 'Ev yapımı',
    required this.mealType,
    required this.capturedAt,
    this.ingredientsText,
    this.nutriments = const NutrimentsEntity(),
    this.calories = 0,
    this.hpScore,
    this.confidence,
    this.aiRawJson,
    this.syncStatus = 'local_only',
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    photoThumbnailPath,
    mealName,
    brand,
    mealType,
    capturedAt,
    ingredientsText,
    nutriments,
    calories,
    hpScore,
    confidence,
    aiRawJson,
    syncStatus,
    createdAt,
    updatedAt,
  ];
}

MealType mealTypeFromString(String value) {
  return MealType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => MealType.snack,
  );
}
