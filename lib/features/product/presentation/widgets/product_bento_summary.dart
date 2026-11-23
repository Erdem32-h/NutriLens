import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../domain/entities/product_entity.dart';

/// 2x2 Cozy pastel Bento summary grid shown at the top of the Product Detail
/// Health tab: Additives, NOVA Processing, Sugar (100g), and Fiber & Protein.
class ProductBentoSummary extends StatelessWidget {
  final ProductEntity product;

  const ProductBentoSummary({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final n = product.nutriments;

    final additiveCount = product.additivesTags.length;
    final additiveValue = additiveCount == 0
        ? '0 · ${l10n.risk1}'
        : '$additiveCount ${l10n.scoreBreakdownAdditives}';

    final novaValue = product.novaGroup != null
        ? 'NOVA ${product.novaGroup}'
        : l10n.novaUnknownLabel;

    final sugarValue = n.sugars != null
        ? '${n.sugars!.toStringAsFixed(1)} g'
        : '—';

    final fiberProteinParts = <String>[
      if (n.fiber != null) '${n.fiber!.toStringAsFixed(1)}g',
      if (n.proteins != null) '${n.proteins!.toStringAsFixed(1)}g',
    ];
    final fiberProteinValue = fiberProteinParts.isEmpty
        ? '—'
        : fiberProteinParts.join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BentoMetricCard(
                  tint: additiveCount == 0
                      ? colors.cozy.mint
                      : colors.cozy.rose,
                  icon: Icons.science_outlined,
                  label: l10n.additives,
                  value: additiveValue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BentoMetricCard(
                  tint: colors.cozy.sky,
                  icon: Icons.factory_outlined,
                  label: l10n.novaGroup,
                  value: novaValue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BentoMetricCard(
                  tint: colors.cozy.peach,
                  icon: Icons.cookie_outlined,
                  label: '${l10n.sugarLabel} (100g)',
                  value: sugarValue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BentoMetricCard(
                  tint: colors.cozy.lilac,
                  icon: Icons.eco_outlined,
                  label: '${l10n.fiberLabel} & ${l10n.proteinLabel}',
                  value: fiberProteinValue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BentoMetricCard extends StatelessWidget {
  final CozyTint tint;
  final IconData icon;
  final String label;
  final String value;

  const _BentoMetricCard({
    required this.tint,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.ink.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tint.ink),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.cozy.bodyOnTint,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
