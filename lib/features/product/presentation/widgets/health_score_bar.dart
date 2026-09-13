import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class HealthScoreBar extends StatelessWidget {
  /// (gauge level, width in score points) from 0 upward.
  static final _bands = () {
    const edges = [
      0.0,
      ScoreConstants.gauge4Threshold,
      ScoreConstants.gauge3Threshold,
      ScoreConstants.gauge2Threshold,
      ScoreConstants.gauge1Threshold,
      100.0,
    ];
    return [
      for (var i = 0; i < 5; i++) (5 - i, (edges[i + 1] - edges[i]).round()),
    ];
  }();

  final double? hpScore;

  /// Dış boşluk. Varsayılan, mevcut ekranlardaki (ürün detayı, öğün detayı,
  /// tarama sonucu) sabit değerle birebir aynı — bu 4 çağrı noktası
  /// davranış değişikliği görmez. Onboarding önizlemesi kendi sayfa
  /// gutter'ını zaten uyguladığı için sıfır yatay padding geçer.
  final EdgeInsets padding;

  const HealthScoreBar({
    super.key,
    required this.hpScore,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    if (hpScore == null) return const SizedBox.shrink();

    final colors = context.colors;
    final l10n = context.l10n;
    final gaugeLevel = ScoreConstants.hpToGauge(hpScore!);
    final gaugeColor = colors.gaugeColor(gaugeLevel);
    final shown = ScoreConstants.displayHp(hpScore!);

    return Padding(
      padding: padding,
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
              '${l10n.healthScoreLabel} ${l10n.hundredIsBest}',
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
                  '$shown',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: gaugeColor,
                    height: 1.0,
                  ),
                ),
                Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Arrow over the exact score, 0 at the start edge.
            Align(
              alignment: AlignmentDirectional(shown / 50 - 1, 0),
              child: Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: gaugeColor,
              ),
            ),

            // Band bar, worst → best; segment widths follow the thresholds.
            SizedBox(
              height: 12,
              child: Row(
                children: List.generate(_bands.length, (index) {
                  final (level, width) = _bands[index];
                  final segmentColor = colors.gaugeColor(level);
                  final isFirst = index == 0;
                  final isLast = index == _bands.length - 1;

                  return Expanded(
                    flex: width,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: isFirst ? 0 : 1.5,
                        end: isLast ? 0 : 1.5,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: level == gaugeLevel
                              ? segmentColor
                              : segmentColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadiusDirectional.horizontal(
                            start: isFirst
                                ? const Radius.circular(6)
                                : Radius.zero,
                            end: isLast
                                ? const Radius.circular(6)
                                : Radius.zero,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 6),

            // Worst / Best labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.worstScore,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  l10n.bestScore,
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
