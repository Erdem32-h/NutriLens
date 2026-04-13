import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AdditiveEntity extends Equatable {
  final String id;
  final String eNumber;
  final String nameEn;
  final String? nameTr;
  final String? category;

  /// Risk level 1–5: 1 = very low, 5 = very high
  final int riskLevel;
  final String? riskLabel;
  final String? descriptionEn;
  final String? descriptionTr;
  final String? efsaStatus;
  final String? turkishCodexStatus;
  final bool isVegan;
  final bool isVegetarian;
  final bool isHalal;

  const AdditiveEntity({
    required this.id,
    required this.eNumber,
    required this.nameEn,
    this.nameTr,
    this.category,
    required this.riskLevel,
    this.riskLabel,
    this.descriptionEn,
    this.descriptionTr,
    this.efsaStatus,
    this.turkishCodexStatus,
    this.isVegan = true,
    this.isVegetarian = true,
    this.isHalal = true,
  });

  /// Returns a colour representing the risk level:
  /// 1 → green, 2 → lime, 3 → yellow, 4 → orange, 5 → red
  Color get riskColor {
    switch (riskLevel) {
      case 1:
        return const Color(0xFF4CAF50); // green
      case 2:
        return const Color(0xFF8BC34A); // lime
      case 3:
        return const Color(0xFFFFEB3B); // yellow
      case 4:
        return const Color(0xFFFF9800); // orange
      case 5:
      default:
        return const Color(0xFFF44336); // red
    }
  }

  /// Returns true when the additive is banned by Turkish Codex or EFSA.
  bool get isBanned =>
      turkishCodexStatus == 'banned' || efsaStatus == 'banned';

  AdditiveEntity copyWith({
    String? id,
    String? eNumber,
    String? nameEn,
    String? nameTr,
    String? category,
    int? riskLevel,
    String? riskLabel,
    String? descriptionEn,
    String? descriptionTr,
    String? efsaStatus,
    String? turkishCodexStatus,
    bool? isVegan,
    bool? isVegetarian,
    bool? isHalal,
  }) {
    return AdditiveEntity(
      id: id ?? this.id,
      eNumber: eNumber ?? this.eNumber,
      nameEn: nameEn ?? this.nameEn,
      nameTr: nameTr ?? this.nameTr,
      category: category ?? this.category,
      riskLevel: riskLevel ?? this.riskLevel,
      riskLabel: riskLabel ?? this.riskLabel,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionTr: descriptionTr ?? this.descriptionTr,
      efsaStatus: efsaStatus ?? this.efsaStatus,
      turkishCodexStatus: turkishCodexStatus ?? this.turkishCodexStatus,
      isVegan: isVegan ?? this.isVegan,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isHalal: isHalal ?? this.isHalal,
    );
  }

  @override
  List<Object?> get props => [
        id,
        eNumber,
        nameEn,
        nameTr,
        category,
        riskLevel,
        riskLabel,
        descriptionEn,
        descriptionTr,
        efsaStatus,
        turkishCodexStatus,
        isVegan,
        isVegetarian,
        isHalal,
      ];
}
