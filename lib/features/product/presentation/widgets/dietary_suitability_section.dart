import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/dietary_suitability_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../additive/presentation/providers/additive_provider.dart';
import '../../domain/entities/product_entity.dart';

/// Product-level "Dietary Suitability" card (Vegan / Vegetarian / Halal),
/// mirroring the per-additive card but aggregated for the whole product:
/// additive flags + an ingredient keyword scan (see
/// [DietarySuitabilityService]). Hidden when there is no evidence to judge.
class DietarySuitabilitySection extends ConsumerWidget {
  final ProductEntity product;

  const DietarySuitabilitySection({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final additivesAsync = ref.watch(
      additiveEntitiesByCodesProvider(product.additivesTags),
    );

    return additivesAsync.maybeWhen(
      data: (additives) {
        final suitability = DietarySuitabilityService.evaluate(
          ingredientsText: product.ingredientsText,
          anyAdditiveNotVegan: additives.any((a) => !a.isVegan),
          anyAdditiveNotVegetarian: additives.any((a) => !a.isVegetarian),
          anyAdditiveNotHalal: additives.any((a) => !a.isHalal),
          hasAdditiveData: additives.isNotEmpty,
        );
        if (suitability == null) return const SizedBox.shrink();
        return _Card(suitability: suitability);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Card extends StatelessWidget {
  final DietarySuitability suitability;

  const _Card({required this.suitability});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu_outlined,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.dietarySuitability,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DietBadge(
                  label: l10n.vegan,
                  isOk: suitability.vegan,
                  colors: colors,
                ),
                _DietBadge(
                  label: l10n.vegetarian,
                  isOk: suitability.vegetarian,
                  colors: colors,
                ),
                _DietBadge(
                  label: l10n.halal,
                  isOk: suitability.halal,
                  colors: colors,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.dietarySuitabilityNote,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietBadge extends StatelessWidget {
  final String label;
  final bool isOk;
  final AppColorsExtension colors;

  const _DietBadge({
    required this.label,
    required this.isOk,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOk ? colors.riskSafe : colors.error;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOk ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}
