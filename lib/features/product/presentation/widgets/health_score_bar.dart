import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class HealthScoreBar extends StatelessWidget {
  final double? hpScore;

  const HealthScoreBar({super.key, required this.hpScore});

  @override
  Widget build(BuildContext context) {
    if (hpScore == null) return const SizedBox.shrink();

    final colors = context.colors;
    final l10n = context.l10n;
    final gaugeLevel = ScoreConstants.hpToGauge(hpScore!);
    final gaugeColor = colors.gaugeColor(gaugeLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Text(
              '${l10n.healthScoreLabel} ${l10n.worstIsBad}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                letterSpacing: 1.0,
              ),
            ),

            const SizedBox(height: 12),

            // Score display
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$gaugeLevel',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: gaugeColor,
                    height: 1.0,
                  ),
                ),
                Text(
                  '/5',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 5-segment bar
            SizedBox(
              height: 28,
              child: Row(
                children: List.generate(5, (index) {
                  final segmentLevel = index + 1;
                  final isActive = segmentLevel == gaugeLevel;
                  final segmentColor = colors.gaugeColor(segmentLevel);

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 3,
                        right: index == 4 ? 0 : 3,
                      ),
                      child: Column(
                        children: [
                          // Arrow indicator
                          if (isActive)
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: gaugeColor,
                            )
                          else
                            const SizedBox(height: 16),

                          // Segment
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isActive
                                    ? segmentColor
                                    : segmentColor.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.horizontal(
                                  left: index == 0
                                      ? const Radius.circular(6)
                                      : Radius.zero,
                                  right: index == 4
                                      ? const Radius.circular(6)
                                      : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 6),

            // Best / Worst labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.bestScore,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  l10n.worstScore,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
