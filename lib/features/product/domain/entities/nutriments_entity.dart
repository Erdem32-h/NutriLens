import 'package:equatable/equatable.dart';

class NutrimentsEntity extends Equatable {
  final double? energyKcal;
  final double? fat;
  final double? saturatedFat;
  final double? transFat;
  final double? carbohydrates;
  final double? sugars;
  final double? salt;
  final double? fiber;
  final double? proteins;

  const NutrimentsEntity({
    this.energyKcal,
    this.fat,
    this.saturatedFat,
    this.transFat,
    this.carbohydrates,
    this.sugars,
    this.salt,
    this.fiber,
    this.proteins,
  });

  static const empty = NutrimentsEntity();

  /// Multiplies every nutrient by [factor] — used by the food-result
  /// portion selector so a ½× / 1× / 1½× / 2× pick reflects directly
  /// in calories, macros, salt and fiber. Nulls stay null (the AI may
  /// genuinely not know a field; scaling unknown × factor is still
  /// unknown). [factor] of 1.0 returns the same values.
  NutrimentsEntity scaled(double factor) {
    if (factor == 1.0) return this;
    double? mul(double? v) => v == null ? null : v * factor;
    return NutrimentsEntity(
      energyKcal: mul(energyKcal),
      fat: mul(fat),
      saturatedFat: mul(saturatedFat),
      transFat: mul(transFat),
      carbohydrates: mul(carbohydrates),
      sugars: mul(sugars),
      salt: mul(salt),
      fiber: mul(fiber),
      proteins: mul(proteins),
    );
  }

  NutrimentsEntity copyWith({
    double? energyKcal,
    double? fat,
    double? saturatedFat,
    double? transFat,
    double? carbohydrates,
    double? sugars,
    double? salt,
    double? fiber,
    double? proteins,
  }) {
    return NutrimentsEntity(
      energyKcal: energyKcal ?? this.energyKcal,
      fat: fat ?? this.fat,
      saturatedFat: saturatedFat ?? this.saturatedFat,
      transFat: transFat ?? this.transFat,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      sugars: sugars ?? this.sugars,
      salt: salt ?? this.salt,
      fiber: fiber ?? this.fiber,
      proteins: proteins ?? this.proteins,
    );
  }

  @override
  List<Object?> get props => [
    energyKcal,
    fat,
    saturatedFat,
    transFat,
    carbohydrates,
    sugars,
    salt,
    fiber,
    proteins,
  ];
}
