import 'package:equatable/equatable.dart';

import '../../../../core/services/calorie_target_calculator.dart';

/// Kullanıcının vücut ölçüleri. Kalori hedefi bundan türetilir.
class UserMetricsEntity extends Equatable {
  final String userId;
  final BiologicalSex sex;
  final int birthYear;
  final int heightCm;
  final double weightKg;
  final double? targetWeightKg;
  final ActivityLevel activity;
  final DateTime updatedAt;

  const UserMetricsEntity({
    required this.userId,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.activity,
    required this.updatedAt,
  });

  /// Doğum yılından türetilen yaş. Gün/ay bilgisi sorulmadığı için yıl farkı
  /// yeterli — kalori hesabında bir yıllık sapmanın etkisi 5 kcal.
  int ageAt(DateTime now) => now.year - birthYear;

  CalorieTargetInput toCalculatorInput(DateTime now) => CalorieTargetInput(
    sex: sex,
    age: ageAt(now),
    heightCm: heightCm,
    weightKg: weightKg,
    targetWeightKg: targetWeightKg,
    activity: activity,
  );

  UserMetricsEntity copyWith({
    String? userId,
    BiologicalSex? sex,
    int? birthYear,
    int? heightCm,
    double? weightKg,
    double? targetWeightKg,
    bool clearTargetWeight = false,
    ActivityLevel? activity,
    DateTime? updatedAt,
  }) {
    return UserMetricsEntity(
      userId: userId ?? this.userId,
      sex: sex ?? this.sex,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: clearTargetWeight
          ? null
          : (targetWeightKg ?? this.targetWeightKg),
      activity: activity ?? this.activity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    sex,
    birthYear,
    heightCm,
    weightKg,
    targetWeightKg,
    activity,
    updatedAt,
  ];
}
