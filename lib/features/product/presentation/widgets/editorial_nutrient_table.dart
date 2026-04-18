import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nutriments_entity.dart';

/// Nutrition facts table displayed in the product detail screen.
///
/// Matches the Turkish food label hierarchy:
///   Enerji (kJ/kcal)
///   Yağ (g)
///     └ Doymuş Yağ (g)          ← indented child
///     └ Trans Yağ (g)           ← indented child
///   Karbonhidrat (g)
///     └ Şekerler (g)            ← indented child
///   Lif (g)
///   Protein (g)
///   Tuz (g)
class EditorialNutrientTable extends StatelessWidget {
  final NutrimentsEntity nutriments;

  const EditorialNutrientTable({super.key, required this.nutriments});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    // Build the ordered entry list with hierarchy info
    final entries = <_NutrientEntry>[];

    // ── Energy ──────────────────────────────────────────────────────
    if (nutriments.energyKcal != null) {
      final kcal = nutriments.energyKcal!;
      final kj = (kcal * 4.184).round();
      entries.add(_NutrientEntry(
        label: '${l10n.energyValue} (kJ/kcal)',
        value: '$kj / ${kcal.toStringAsFixed(0)}',
        isChild: false,
        isParent: false,
      ));
    }

    // ── Fat group ────────────────────────────────────────────────────
    if (nutriments.fat != null) {
      entries.add(_NutrientEntry(
        label: '${l10n.fatLabel} (g)',
        value: nutriments.fat!.toStringAsFixed(1),
        isChild: false,
        isParent: nutriments.saturatedFat != null || nutriments.transFat != null,
      ));
    }
    if (nutriments.saturatedFat != null) {
      entries.add(_NutrientEntry(
        label: l10n.saturatedFatLabel,
        value: '${nutriments.saturatedFat!.toStringAsFixed(1)} g',
        isChild: true,
        isParent: false,
      ));
    }
    if (nutriments.transFat != null) {
      entries.add(_NutrientEntry(
        label: l10n.transFatLabel,
        value: '${nutriments.transFat!.toStringAsFixed(1)} g',
        isChild: true,
        isParent: false,
      ));
    }

    // ── Carbohydrate group ───────────────────────────────────────────
    if (nutriments.carbohydrates != null) {
      entries.add(_NutrientEntry(
        label: '${l10n.carbohydrateLabel} (g)',
        value: nutriments.carbohydrates!.toStringAsFixed(1),
        isChild: false,
        isParent: nutriments.sugars != null,
      ));
    }
    if (nutriments.sugars != null) {
      entries.add(_NutrientEntry(
        label: l10n.sugarLabel,
        value: '${nutriments.sugars!.toStringAsFixed(1)} g',
        isChild: true,
        isParent: false,
      ));
    }

    // ── Standalone rows ──────────────────────────────────────────────
    if (nutriments.fiber != null) {
      entries.add(_NutrientEntry(
        label: '${l10n.fiberLabel} (g)',
        value: nutriments.fiber!.toStringAsFixed(1),
        isChild: false,
        isParent: false,
      ));
    }
    if (nutriments.proteins != null) {
      entries.add(_NutrientEntry(
        label: '${l10n.proteinLabel} (g)',
        value: nutriments.proteins!.toStringAsFixed(1),
        isChild: false,
        isParent: false,
      ));
    }
    if (nutriments.salt != null) {
      entries.add(_NutrientEntry(
        label: '${l10n.saltLabel} (g)',
        value: nutriments.salt!.toStringAsFixed(2),
        isChild: false,
        isParent: false,
      ));
    }

    if (entries.isEmpty) return const SizedBox.shrink();

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
            // ── Table header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                l10n.detailedContent,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Column labels ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.detailedContent.isEmpty ? '' : '',
                    ),
                  ),
                  Text(
                    '100g',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Divider ─────────────────────────────────────────────
            Divider(
              height: 1,
              color: colors.border.withValues(alpha: 0.3),
              indent: 20,
              endIndent: 20,
            ),

            // ── Rows ─────────────────────────────────────────────────
            ...List.generate(entries.length, (index) {
              final entry = entries[index];
              final isLast = index == entries.length - 1;

              return _NutrientRowWidget(
                entry: entry,
                isLast: isLast,
                colors: colors,
              );
            }),

            // ── Footer ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                context.l10n.dailyValueNote,
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

// ── Row Widget ─────────────────────────────────────────────────────────

class _NutrientRowWidget extends StatelessWidget {
  final _NutrientEntry entry;
  final bool isLast;
  final AppColorsExtension colors;

  const _NutrientRowWidget({
    required this.entry,
    required this.isLast,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isChild = entry.isChild;
    final isParent = entry.isParent;

    return Container(
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(24))
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left indent accent for child rows
            if (isChild) ...[
              const SizedBox(width: 20),
              Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 10),
            ] else
              const SizedBox(width: 20),

            // Label + value
            Expanded(
              child: Container(
                padding: EdgeInsets.only(
                  right: 20,
                  top: isChild ? 10 : 13,
                  bottom: isChild ? 10 : 13,
                ),
                decoration: BoxDecoration(
                  border: !isLast
                      ? Border(
                          bottom: BorderSide(
                            color: colors.border.withValues(alpha: 0.2),
                          ),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Label
                    Expanded(
                      child: Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: isChild ? 13 : 14,
                          fontWeight:
                              isParent ? FontWeight.w700 : FontWeight.w500,
                          color: isChild
                              ? colors.textMuted
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Value
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: isChild ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: isChild
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data Model ─────────────────────────────────────────────────────────

class _NutrientEntry {
  final String label;
  final String value;

  /// True if this row is indented under a parent (e.g. Doymuş Yağ under Yağ).
  final bool isChild;

  /// True if this row has children below it (e.g. Yağ has Doymuş/Trans Yağ).
  final bool isParent;

  const _NutrientEntry({
    required this.label,
    required this.value,
    required this.isChild,
    required this.isParent,
  });
}
