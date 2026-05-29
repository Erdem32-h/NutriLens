import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/hp_score_calculator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';

/// Transparency card for the Health tab: "Why N/5?".
///
/// Reconstructs the HP Score (v3) component contributions from the stored
/// raw factors on [ProductEntity] so the user can see *why* a product
/// landed on its gauge level. Starts collapsed; expanding reveals each
/// factor's signed point contribution plus the NOVA processing group as a
/// sub-label of the nutritional-quality factor.
///
/// Formula (see [ScoreConstants]):
///   100 − chem×0.45 − risk×0.40 + nutri×0.15 − ingredientPenalty
class ScoreBreakdownCard extends StatelessWidget {
  final ProductEntity product;

  const ScoreBreakdownCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final score = product.calculatedHpScore;
    // Nothing to break down without a score or any stored component.
    if (score == null &&
        product.hpChemicalLoad == null &&
        product.hpRiskFactor == null &&
        product.hpNutriFactor == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final l10n = context.l10n;
    final gauge = ScoreConstants.hpToGauge(score);
    final gaugeColor = colors.gaugeColor(gauge);

    // Critical blacklist (palm oil, glucose syrup, …) forces the lowest
    // score regardless of the component math — surface that explicitly.
    final bool isCritical = _hasCriticalIngredient(product.ingredientsText);

    final chem = product.hpChemicalLoad ?? 0;
    final risk = product.hpRiskFactor ?? 0;
    final nutri = product.hpNutriFactor ?? 0;
    final penalty = HpScoreCalculator.ingredientQualityPenalty(
      product.ingredientsText,
      product.nutriments,
    );

    final chemPts = -(chem * ScoreConstants.chemicalWeight);
    final riskPts = -(risk * ScoreConstants.riskWeight);
    final nutriPts = nutri * ScoreConstants.nutriWeight;
    final penaltyPts = -penalty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Strip the default ExpansionTile dividers for a cleaner card.
          data: Theme.of(
            context,
          ).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            leading: Icon(Icons.insights_rounded, color: gaugeColor),
            title: Text(
              '${l10n.scoreBreakdownWhy} $gauge/5?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              l10n.scoreBreakdownSubtitle,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            children: [
              if (isCritical) _criticalCallout(colors, l10n),
              _row(
                colors: colors,
                label: l10n.scoreBreakdownBase,
                points: 100,
                maxMagnitude: 100,
                isBase: true,
              ),
              _row(
                colors: colors,
                label: l10n.scoreBreakdownChemical,
                sub: product.additivesTags.isEmpty
                    ? null
                    : '${product.additivesTags.length} ${l10n.scoreBreakdownAdditives}',
                points: chemPts,
                maxMagnitude: 45,
              ),
              _row(
                colors: colors,
                label: l10n.scoreBreakdownRisk,
                sub: l10n.scoreBreakdownRiskSub,
                points: riskPts,
                maxMagnitude: 40,
              ),
              _row(
                colors: colors,
                label: l10n.scoreBreakdownNutri,
                sub: _novaSubLabel(l10n),
                points: nutriPts,
                maxMagnitude: 15,
              ),
              if (penalty > 0)
                _row(
                  colors: colors,
                  label: l10n.scoreBreakdownPenalty,
                  sub: l10n.scoreBreakdownPenaltySub,
                  points: penaltyPts,
                  maxMagnitude: ScoreConstants.ingredientQualityPenaltyCap,
                ),
              const SizedBox(height: 8),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 8),
              _resultRow(colors, l10n, gauge, gaugeColor, score),
            ],
          ),
        ),
      ),
    );
  }

  String _novaSubLabel(dynamic l10n) {
    final n = product.novaGroup;
    final label = switch (n) {
      1 => l10n.nova1Label,
      2 => l10n.nova2Label,
      3 => l10n.nova3Label,
      4 => l10n.nova4Label,
      _ => l10n.novaUnknownLabel,
    };
    return n == null ? 'NOVA — $label' : 'NOVA $n — $label';
  }

  Widget _criticalCallout(AppColorsExtension colors, dynamic l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.report_rounded, color: colors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.scoreBreakdownCritical,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required AppColorsExtension colors,
    required String label,
    required double points,
    required double maxMagnitude,
    String? sub,
    bool isBase = false,
  }) {
    final isPositive = points > 0;
    final isZero = points.abs() < 0.5;
    final deltaColor = isBase
        ? colors.textMuted
        : isZero
        ? colors.textMuted
        : isPositive
        ? Colors.green.shade600
        : colors.error;
    final fraction = (points.abs() / maxMagnitude).clamp(0.0, 1.0);
    final sign = isBase ? '' : (isPositive ? '+' : '−');
    final magnitude = points.abs().round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$sign$magnitude',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: deltaColor,
                ),
              ),
            ],
          ),
          if (!isBase && !isZero) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: colors.surfaceCard2,
                valueColor: AlwaysStoppedAnimation(deltaColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(
    AppColorsExtension colors,
    dynamic l10n,
    int gauge,
    Color gaugeColor,
    double? score,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.scoreBreakdownResult,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: gaugeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$gauge/5',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: gaugeColor,
            ),
          ),
        ),
      ],
    );
  }

  static bool _hasCriticalIngredient(String? ingredientsText) {
    if (ingredientsText == null) return false;
    final t = ScoreConstants.normalizeTurkish(ingredientsText);
    return ScoreConstants.criticalPatterns.any(t.contains);
  }
}
