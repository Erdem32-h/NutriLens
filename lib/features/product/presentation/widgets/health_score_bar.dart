import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cozy_tile.dart';

class HealthScoreBar extends StatelessWidget {
  final double? hpScore;

  /// Outer padding when rendered as a standalone card. Ignored when [embedded]
  /// is true.
  final EdgeInsets padding;

  /// When true, omits the outer card container so the gauge can sit directly
  /// inside another surface such as the product hero card.
  final bool embedded;

  /// Optional concise 1-line summary shown under the score (e.g. "NOVA 2 · 4g sugar").
  final String? summary;

  const HealthScoreBar({
    super.key,
    required this.hpScore,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.embedded = false,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (hpScore == null) return const SizedBox.shrink();

    final colors = context.colors;
    final l10n = context.l10n;
    final gaugeLevel = ScoreConstants.hpToGauge(hpScore!);
    final gaugeColor = colors.gaugeColor(gaugeLevel);
    final shown = ScoreConstants.displayHp(hpScore!);
    final verdict = switch (gaugeLevel) {
      1 => l10n.gaugeExcellent,
      2 => l10n.gaugeGood,
      3 => l10n.gaugeModerate,
      4 => l10n.gaugeWeak,
      _ => l10n.gaugeBad,
    };

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!embedded) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${l10n.healthScoreLabel} ${l10n.hundredIsBest}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 112,
          width: 230,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArcGaugePainter(
                    score: shown.toDouble(),
                    activeColor: gaugeColor,
                    trackColor: colors.border.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$shown',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gaugeColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          verdict,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gaugeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (summary != null && summary!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            summary!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (embedded) return content;

    return Padding(
      padding: padding,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: cozyCardDecoration(context),
        child: content,
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double score; // 0..100
  final Color activeColor;
  final Color trackColor;

  _ArcGaugePainter({
    required this.score,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const segmentCount = 5;
    const strokeWidth = 10.0;
    const gapAngle = 0.055; // radians between segments
    const startAngle = math.pi * 0.96;
    const totalSweep = math.pi * 1.08;
    final segmentSweep =
        (totalSweep - gapAngle * (segmentCount - 1)) / segmentCount;

    final radius = math.min(size.width / 2, size.height) - strokeWidth;
    final center = Offset(size.width / 2, size.height - strokeWidth * 0.5);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progress = (score / 100.0).clamp(0.0, 1.0);
    final filledSegments = progress * segmentCount;

    for (var i = 0; i < segmentCount; i++) {
      final segStart = startAngle + i * (segmentSweep + gapAngle);
      canvas.drawArc(rect, segStart, segmentSweep, false, trackPaint);

      final segFill = (filledSegments - i).clamp(0.0, 1.0);
      if (segFill > 0.01) {
        canvas.drawArc(
          rect,
          segStart,
          segmentSweep * segFill,
          false,
          activePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor;
}
