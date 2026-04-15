import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nutriments_entity.dart';

class EditorialNutrientTable extends StatelessWidget {
  final NutrimentsEntity nutriments;

  const EditorialNutrientTable({super.key, required this.nutriments});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final rows = <_NutrientRow>[
      if (nutriments.energyKcal != null)
        _NutrientRow(l10n.energyValue, '${nutriments.energyKcal!.toStringAsFixed(0)} kcal'),
      if (nutriments.fat != null)
        _NutrientRow(l10n.fatLabel, '${nutriments.fat!.toStringAsFixed(1)} g'),
      if (nutriments.saturatedFat != null)
        _NutrientRow(l10n.saturatedFatLabel, '${nutriments.saturatedFat!.toStringAsFixed(1)} g'),
      if (nutriments.transFat != null)
        _NutrientRow(l10n.transFatLabel, '${nutriments.transFat!.toStringAsFixed(1)} g'),
      if (nutriments.carbohydrates != null)
        _NutrientRow(l10n.carbohydrateLabel, '${nutriments.carbohydrates!.toStringAsFixed(1)} g'),
      if (nutriments.sugars != null)
        _NutrientRow(l10n.sugarLabel, '${nutriments.sugars!.toStringAsFixed(1)} g'),
      if (nutriments.salt != null)
        _NutrientRow(l10n.saltLabel, '${nutriments.salt!.toStringAsFixed(2)} g'),
      if (nutriments.fiber != null)
        _NutrientRow(l10n.fiberLabel, '${nutriments.fiber!.toStringAsFixed(1)} g'),
      if (nutriments.proteins != null)
        _NutrientRow(l10n.proteinLabel, '${nutriments.proteins!.toStringAsFixed(1)} g'),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                l10n.detailedContent,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),

            // Rows
            ...List.generate(rows.length, (index) {
              final row = rows[index];
              final isEven = index.isEven;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isEven
                      ? Colors.transparent
                      : colors.surfaceCard2.withValues(alpha: 0.4),
                  borderRadius: index == rows.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Footer note
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                l10n.dailyValueNote,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientRow {
  final String label;
  final String value;

  const _NutrientRow(this.label, this.value);
}
