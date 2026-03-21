import 'package:flutter/material.dart';

import '../../domain/entities/nutriments_entity.dart';

class NutrimentTable extends StatelessWidget {
  final NutrimentsEntity nutriments;

  const NutrimentTable({super.key, required this.nutriments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _buildRows();

    if (rows.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Besin degeri bilgisi mevcut degil',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Besin Degerleri (100g)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              children: [
                _headerRow(theme),
                ...rows,
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow(ThemeData theme) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Besin',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Miktar',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  List<TableRow> _buildRows() {
    final items = <_NutrimentRow>[];

    if (nutriments.energyKcal != null) {
      items.add(_NutrimentRow('Enerji', nutriments.energyKcal!, 'kcal', null));
    }
    if (nutriments.fat != null) {
      items.add(_NutrimentRow('Yag', nutriments.fat!, 'g', _fatLevel));
    }
    if (nutriments.saturatedFat != null) {
      items.add(_NutrimentRow(
          'Doymus Yag', nutriments.saturatedFat!, 'g', _satFatLevel));
    }
    if (nutriments.sugars != null) {
      items.add(
          _NutrimentRow('Seker', nutriments.sugars!, 'g', _sugarLevel));
    }
    if (nutriments.salt != null) {
      items.add(_NutrimentRow('Tuz', nutriments.salt!, 'g', _saltLevel));
    }
    if (nutriments.fiber != null) {
      items.add(_NutrimentRow('Lif', nutriments.fiber!, 'g', null));
    }
    if (nutriments.proteins != null) {
      items.add(
          _NutrimentRow('Protein', nutriments.proteins!, 'g', null));
    }

    return items.map((item) => _dataRow(item)).toList();
  }

  TableRow _dataRow(_NutrimentRow item) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              if (item.levelColor != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: item.levelColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(item.label),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${item.value.toStringAsFixed(1)} ${item.unit}',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // WHO thresholds per 100g for color coding
  Color? get _fatLevel {
    final v = nutriments.fat ?? 0;
    if (v <= 3) return const Color(0xFF4CAF50);
    if (v <= 17.5) return const Color(0xFFFFC107);
    return const Color(0xFFD32F2F);
  }

  Color? get _satFatLevel {
    final v = nutriments.saturatedFat ?? 0;
    if (v <= 1.5) return const Color(0xFF4CAF50);
    if (v <= 5) return const Color(0xFFFFC107);
    return const Color(0xFFD32F2F);
  }

  Color? get _sugarLevel {
    final v = nutriments.sugars ?? 0;
    if (v <= 5) return const Color(0xFF4CAF50);
    if (v <= 22.5) return const Color(0xFFFFC107);
    return const Color(0xFFD32F2F);
  }

  Color? get _saltLevel {
    final v = nutriments.salt ?? 0;
    if (v <= 0.3) return const Color(0xFF4CAF50);
    if (v <= 1.5) return const Color(0xFFFFC107);
    return const Color(0xFFD32F2F);
  }
}

class _NutrimentRow {
  final String label;
  final double value;
  final String unit;
  final Color? levelColor;

  const _NutrimentRow(this.label, this.value, this.unit, this.levelColor);
}
