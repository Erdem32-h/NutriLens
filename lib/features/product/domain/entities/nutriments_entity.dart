import 'package:equatable/equatable.dart';

class NutrimentsEntity extends Equatable {
  final double? energyKcal;
  final double? fat;
  final double? saturatedFat;
  final double? sugars;
  final double? salt;
  final double? fiber;
  final double? proteins;

  const NutrimentsEntity({
    this.energyKcal,
    this.fat,
    this.saturatedFat,
    this.sugars,
    this.salt,
    this.fiber,
    this.proteins,
  });

  static const empty = NutrimentsEntity();

  NutrimentsEntity copyWith({
    double? energyKcal,
    double? fat,
    double? saturatedFat,
    double? sugars,
    double? salt,
    double? fiber,
    double? proteins,
  }) {
    return NutrimentsEntity(
      energyKcal: energyKcal ?? this.energyKcal,
      fat: fat ?? this.fat,
      saturatedFat: saturatedFat ?? this.saturatedFat,
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
        sugars,
        salt,
        fiber,
        proteins,
      ];
}
