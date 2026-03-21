import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nutriments_entity.dart';

class NutrimentTable extends StatelessWidget {
  final NutrimentsEntity nutriments;

  const NutrimentTable({super.key, required this.nutriments});

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();

    if (rows.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Besin değeri bilgisi mevcut değil',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Besin Değerleri (100g)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceCard2,
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Besin',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const Text(
                  'Miktar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
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
              color: isEven ? Colors.transparent : AppColors.surfaceCard2,
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
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.value.toStringAsFixed(1)} ${item.unit}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
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

  List<_NutrimentRow> _buildRows() {
    final items = <_NutrimentRow>[];

    if (nutriments.energyKcal != null) {
      items.add(_NutrimentRow('Enerji', nutriments.energyKcal!, 'kcal', null));
    }
    if (nutriments.fat != null) {
      items.add(_NutrimentRow('Yağ', nutriments.fat!, 'g', _fatLevel));
    }
    if (nutriments.saturatedFat != null) {
      items.add(_NutrimentRow(
          'Doymuş Yağ', nutriments.saturatedFat!, 'g', _satFatLevel));
    }
    if (nutriments.sugars != null) {
      items.add(_NutrimentRow('Şeker', nutriments.sugars!, 'g', _sugarLevel));
    }
    if (nutriments.salt != null) {
      items.add(_NutrimentRow('Tuz', nutriments.salt!, 'g', _saltLevel));
    }
    if (nutriments.fiber != null) {
      items.add(_NutrimentRow('Lif', nutriments.fiber!, 'g', null));
    }
    if (nutriments.proteins != null) {
      items.add(_NutrimentRow('Protein', nutriments.proteins!, 'g', null));
    }

    return items;
  }

  // WHO thresholds per 100g for color coding
  Color? get _fatLevel {
    final v = nutriments.fat ?? 0;
    if (v <= 3) return AppColors.riskSafe;
    if (v <= 17.5) return AppColors.riskModerate;
    return AppColors.riskDangerous;
  }

  Color? get _satFatLevel {
    final v = nutriments.saturatedFat ?? 0;
    if (v <= 1.5) return AppColors.riskSafe;
    if (v <= 5) return AppColors.riskModerate;
    return AppColors.riskDangerous;
  }

  Color? get _sugarLevel {
    final v = nutriments.sugars ?? 0;
    if (v <= 5) return AppColors.riskSafe;
    if (v <= 22.5) return AppColors.riskModerate;
    return AppColors.riskDangerous;
  }

  Color? get _saltLevel {
    final v = nutriments.salt ?? 0;
    if (v <= 0.3) return AppColors.riskSafe;
    if (v <= 1.5) return AppColors.riskModerate;
    return AppColors.riskDangerous;
  }
}

class _NutrimentRow {
  final String label;
  final double value;
  final String unit;
  final Color? levelColor;

  const _NutrimentRow(this.label, this.value, this.unit, this.levelColor);
}
