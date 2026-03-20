import 'package:equatable/equatable.dart';

import 'nutriments_entity.dart';

class ProductEntity extends Equatable {
  final String barcode;
  final String? productName;
  final String? brands;
  final String? imageUrl;
  final String? ingredientsText;
  final List<String> allergensTags;
  final List<String> additivesTags;
  final int? novaGroup;
  final String? nutriscoreGrade;
  final NutrimentsEntity nutriments;
  final List<String> categoriesTags;
  final List<String> countriesTags;
  final double? hpScore;
  final double? hpChemicalLoad;
  final double? hpRiskFactor;
  final double? hpNutriFactor;

  const ProductEntity({
    required this.barcode,
    this.productName,
    this.brands,
    this.imageUrl,
    this.ingredientsText,
    this.allergensTags = const [],
    this.additivesTags = const [],
    this.novaGroup,
    this.nutriscoreGrade,
    this.nutriments = const NutrimentsEntity(),
    this.categoriesTags = const [],
    this.countriesTags = const [],
    this.hpScore,
    this.hpChemicalLoad,
    this.hpRiskFactor,
    this.hpNutriFactor,
  });

  ProductEntity copyWith({
    String? barcode,
    String? productName,
    String? brands,
    String? imageUrl,
    String? ingredientsText,
    List<String>? allergensTags,
    List<String>? additivesTags,
    int? novaGroup,
    String? nutriscoreGrade,
    NutrimentsEntity? nutriments,
    List<String>? categoriesTags,
    List<String>? countriesTags,
    double? hpScore,
    double? hpChemicalLoad,
    double? hpRiskFactor,
    double? hpNutriFactor,
  }) {
    return ProductEntity(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      brands: brands ?? this.brands,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredientsText: ingredientsText ?? this.ingredientsText,
      allergensTags: allergensTags ?? this.allergensTags,
      additivesTags: additivesTags ?? this.additivesTags,
      novaGroup: novaGroup ?? this.novaGroup,
      nutriscoreGrade: nutriscoreGrade ?? this.nutriscoreGrade,
      nutriments: nutriments ?? this.nutriments,
      categoriesTags: categoriesTags ?? this.categoriesTags,
      countriesTags: countriesTags ?? this.countriesTags,
      hpScore: hpScore ?? this.hpScore,
      hpChemicalLoad: hpChemicalLoad ?? this.hpChemicalLoad,
      hpRiskFactor: hpRiskFactor ?? this.hpRiskFactor,
      hpNutriFactor: hpNutriFactor ?? this.hpNutriFactor,
    );
  }

  @override
  List<Object?> get props => [
        barcode,
        productName,
        brands,
        imageUrl,
        ingredientsText,
        allergensTags,
        additivesTags,
        novaGroup,
        nutriscoreGrade,
        nutriments,
        categoriesTags,
        countriesTags,
        hpScore,
        hpChemicalLoad,
        hpRiskFactor,
        hpNutriFactor,
      ];
}
