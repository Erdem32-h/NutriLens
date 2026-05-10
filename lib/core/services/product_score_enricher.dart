import '../constants/score_constants.dart';
import '../../features/product/domain/entities/product_entity.dart';
import 'hp_score_calculator.dart';

class ProductScoreEnricher {
  final HpScoreCalculator _calculator;

  const ProductScoreEnricher(this._calculator);

  Future<ProductEntity> ensureFreshScore(ProductEntity product) async {
    final hasFreshScore =
        product.hpScore != null &&
        product.hpScoreVersion >= ScoreConstants.hpScoreAlgorithmVersion;

    if (hasFreshScore || !product.hasEssentialData) {
      return product;
    }

    final result = await _calculator.calculateFull(
      additivesTags: product.additivesTags,
      nutriments: product.nutriments,
      novaGroup: product.novaGroup,
      ingredientsText: product.ingredientsText,
    );

    return product.copyWith(
      hpScore: result.hpScore,
      hpChemicalLoad: result.chemicalLoad,
      hpRiskFactor: result.riskFactor,
      hpNutriFactor: result.nutriFactor,
      hpScoreVersion: ScoreConstants.hpScoreAlgorithmVersion,
    );
  }
}
