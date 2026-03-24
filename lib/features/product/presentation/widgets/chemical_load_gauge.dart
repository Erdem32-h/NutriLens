import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
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
                isPartial ? 'Kimyasal Yük Analizi' : 'Kimyasal Yük',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: context.colors.surfaceCard2,
              valueColor: AlwaysStoppedAnimation(color),
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
