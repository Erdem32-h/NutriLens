import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nutriments_entity.dart';

class NutrimentTable extends StatelessWidget {
  final NutrimentsEntity nutriments;

  const NutrimentTable({super.key, required this.nutriments});

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(context);
    final hasAnyValue = rows.any((r) => r.value != null);

    if (!hasAnyValue) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          'Besin değeri bilgisi mevcut değil',
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Besin Değerleri (100g)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.colors.surfaceCard2,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Besin',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
                Text(
                  'Miktar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...rows.asMap().entries.map((entry) {
            final isEven = entry.key.isEven;
            final item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10,
              ),
              color: isEven ? Colors.transparent : context.colors.surfaceCard2,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (item.levelColor != null)
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: item.levelColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.value == null
                        ? '?'
                        : '${_formatValue(item.value!, item.unit)} ${item.unit}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  List<_NutrimentRow> _buildRows(BuildContext context) {
    return [
      _NutrimentRow('Enerji', nutriments.energyKcal, 'kcal', null),
      _NutrimentRow('Yağ', nutriments.fat, 'g', _fatLevel(context)),
      _NutrimentRow('Doymuş Yağ', nutriments.saturatedFat, 'g', _satFatLevel(context)),
      _NutrimentRow('Trans Yağ', nutriments.transFat, 'g', _transFatLevel(context)),
      _NutrimentRow('Karbonhidrat', nutriments.carbohydrates, 'g', null),
      _NutrimentRow('Şeker', nutriments.sugars, 'g', _sugarLevel(context)),
      _NutrimentRow('Lif', nutriments.fiber, 'g', null),
      _NutrimentRow('Protein', nutriments.proteins, 'g', null),
      _NutrimentRow('Tuz', nutriments.salt, 'g', _saltLevel(context)),
    ];
  }

  // WHO thresholds per 100g for color coding
  Color? _fatLevel(BuildContext context) {
    final v = nutriments.fat;
    if (v == null) return null;
    if (v <= 3) return context.colors.riskSafe;
    if (v <= 17.5) return context.colors.riskModerate;
    return context.colors.riskDangerous;
  }

  Color? _satFatLevel(BuildContext context) {
    final v = nutriments.saturatedFat;
    if (v == null) return null;
    if (v <= 1.5) return context.colors.riskSafe;
    if (v <= 5) return context.colors.riskModerate;
    return context.colors.riskDangerous;
  }

  Color? _sugarLevel(BuildContext context) {
    final v = nutriments.sugars;
    if (v == null) return null;
    if (v <= 5) return context.colors.riskSafe;
    if (v <= 22.5) return context.colors.riskModerate;
    return context.colors.riskDangerous;
  }

  Color? _saltLevel(BuildContext context) {
    final v = nutriments.salt;
    if (v == null) return null;
    if (v <= 0.3) return context.colors.riskSafe;
    if (v <= 1.5) return context.colors.riskModerate;
    return context.colors.riskDangerous;
  }

  // Trans fat is a strict "lower is better" signal — WHO recommends < 1 % of
  // total energy, which for a 100 g serving means anything above ~1 g is
  // already a meaningful hit. Keep the safe band tight.
  Color? _transFatLevel(BuildContext context) {
    final v = nutriments.transFat;
    if (v == null) return null;
    if (v <= 0.1) return context.colors.riskSafe;
    if (v <= 1) return context.colors.riskModerate;
    return context.colors.riskDangerous;
  }

  // Salt is commonly labelled to 2–3 decimals ("Tuz: 0,60 g"). Rounding to
  // 1 decimal erases meaningful information for low-sodium products.
  // For all other nutrients 1 decimal matches how labels are printed.
  String _formatValue(double v, String unit) {
    if (v == 0) return '0';
    if (unit == 'kcal') return v.toStringAsFixed(0);
    if (unit == 'g' && v < 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(1);
  }
}

class _NutrimentRow {
  final String label;
  final double? value;
  final String unit;
  final Color? levelColor;

  const _NutrimentRow(this.label, this.value, this.unit, this.levelColor);
}