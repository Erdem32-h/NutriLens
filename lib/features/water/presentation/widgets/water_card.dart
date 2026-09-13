import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tap_card.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../providers/water_provider.dart';
import '../water_actions.dart';

class WaterCard extends ConsumerWidget {
  const WaterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final tint = colors.cozy.sky;
    final goal = ref.watch(waterGoalProvider);
    final glasses = ref.watch(waterTodayProvider).value?.glasses ?? 0;
    final met = glasses >= goal;

    return AppTapCard(
      onTap: () => context.pushNamed(RouteNames.water),
      semanticLabel: l10n.waterTitle,
      borderRadius: BorderRadius.circular(24),
      decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_rounded, color: tint.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.waterGlassesProgress(glasses, goal),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: goal <= 0 ? 0 : (glasses / goal).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colors.border,
                color: met ? colors.primary : tint.ink,
              ),
            ),
            if (met) ...[
              const SizedBox(height: 6),
              Text(
                l10n.waterGoalReached,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.waterRemoveGlass,
                  onPressed: glasses > 0
                      ? () => removeWaterGlass(context, ref)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => addWaterGlass(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.waterAddGlass),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
