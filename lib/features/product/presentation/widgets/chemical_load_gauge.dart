import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class ChemicalLoadGauge extends StatelessWidget {
  final double chemicalLoad;
  final bool isPartial;

  const ChemicalLoadGauge({
    super.key,
    required this.chemicalLoad,
    this.isPartial = false,
  });

  @override
  Widget build(BuildContext context) {
    final score = (100 - chemicalLoad).clamp(0.0, 100.0);
    final gaugeLevel = ScoreConstants.hpToGauge(score);
    final color = context.colors.gaugeColor(gaugeLevel);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isPartial ? l10n.chemicalLoad : l10n.chemicalLoad,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              // 1-5 gauge display
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$gaugeLevel',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    '/5',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 5-segment mini bar
          SizedBox(
            height: 8,
            child: Row(
              children: List.generate(5, (index) {
                final segmentLevel = index + 1;
                final isActive = segmentLevel == gaugeLevel;
                final segmentColor = context.colors.gaugeColor(segmentLevel);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 2,
                      right: index == 4 ? 0 : 2,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isActive
                            ? segmentColor
                            : segmentColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.horizontal(
                          left: index == 0
                              ? const Radius.circular(4)
                              : Radius.zero,
                          right: index == 4
                              ? const Radius.circular(4)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (isPartial) ...[
            const SizedBox(height: 8),
            Text(
              'Besin değerleri bilinmediği için kısmi analiz',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
