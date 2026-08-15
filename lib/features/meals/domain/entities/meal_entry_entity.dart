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
  final int? portionGrams;
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
    this.portionGrams,
    this.aiRawJson,
    this.syncStatus = 'local_only',
    this.createdAt,
    this.updatedAt,
  });

  /// [UserMetricsEntity.copyWith]'ı yansıtır: değişmeyen alanlar `??
  /// this.field` ile korunur. Bugün hiçbir çağıran nullable bir alanı
  /// açıkça null'a temizlemek istemiyor — `_guardPortionGrams`
  /// (meal_sync_service.dart), `portionGrams`'ı her zaman dolu bir
  /// değerle geçiyor — bu yüzden `UserMetricsEntity.clearTargetWeight`
  /// gibi bir "clear" bayrağı burada yok. Böyle bir ihtiyaç doğarsa aynı
  /// desenle eklenebilir.
  MealEntryEntity copyWith({
    String? id,
    String? userId,
    String? photoThumbnailPath,
    String? mealName,
    String? brand,
    MealType? mealType,
    DateTime? capturedAt,
    String? ingredientsText,
    NutrimentsEntity? nutriments,
    double? calories,
    double? hpScore,
    double? confidence,
    int? portionGrams,
    String? aiRawJson,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealEntryEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      photoThumbnailPath: photoThumbnailPath ?? this.photoThumbnailPath,
      mealName: mealName ?? this.mealName,
      brand: brand ?? this.brand,
      mealType: mealType ?? this.mealType,
      capturedAt: capturedAt ?? this.capturedAt,
      ingredientsText: ingredientsText ?? this.ingredientsText,
      nutriments: nutriments ?? this.nutriments,
      calories: calories ?? this.calories,
      hpScore: hpScore ?? this.hpScore,
      confidence: confidence ?? this.confidence,
      portionGrams: portionGrams ?? this.portionGrams,
      aiRawJson: aiRawJson ?? this.aiRawJson,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
    portionGrams,
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
