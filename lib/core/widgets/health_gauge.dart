import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../extensions/l10n_extension.dart';
import '../theme/app_colors.dart';

/// Animated semicircular HP gauge widget.
///
/// [gaugeLevel] 1–5 where 1 = best (green) and 5 = worst (red).
/// [hpScore] 0–100 displayed in the center; higher = better.
class HealthGauge extends StatefulWidget {
  final int gaugeLevel;
  final double? hpScore;
  final double size;
  final Duration animationDuration;

  const HealthGauge({
    super.key,
    required this.gaugeLevel,
    this.hpScore,
    this.size = 160,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<HealthGauge> createState() => _HealthGaugeState();
}

class _HealthGaugeState extends State<HealthGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _needleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _needleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(HealthGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hpScore != widget.hpScore ||
        oldWidget.gaugeLevel != widget.gaugeLevel) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Maps hpScore 0–100 → angle 0–π (π = left/best, 0 = right/worst).
  double _targetAngle() {
    final score = (widget.hpScore ?? 0.0).clamp(0.0, 100.0);
    return (score / 100.0) * math.pi;
  }

  Color _gaugeColor(BuildContext context) =>
      context.colors.gaugeColor(widget.gaugeLevel.clamp(1, 5));

  String _levelLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.gaugeLevel) {
      1 => l10n.gaugeExcellent,
      2 => l10n.gaugeGood,
      3 => l10n.gaugeModerate,
      4 => l10n.gaugeWeak,
      _ => l10n.gaugeBad,
    };
  }

  @override
  Widget build(BuildContext context) {
    final gaugeColor = _gaugeColor(context);
    final colors = context.colors;

    return SizedBox(
      width: widget.size,
      height: widget.size * 0.72,
      child: AnimatedBuilder(
        animation: _needleAnimation,
        builder: (context, _) {
          final angle = _targetAngle() * _needleAnimation.value;
          return CustomPaint(
            painter: _GaugePainter(
              needleAngle: angle,
              gaugeColor: gaugeColor,
              trackColor: colors.surfaceCard2,
            ),
            child: Align(
              alignment: const Alignment(0, 0.4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.hpScore != null
                        ? widget.hpScore!.toStringAsFixed(0)
                        : '--',
                    style: TextStyle(
                      fontSize: widget.size * 0.185,
                      fontWeight: FontWeight.w800,
                      color: gaugeColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _levelLabel(context),
                    style: TextStyle(
                      fontSize: widget.size * 0.09,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                  Text(
                    context.l10n.hpScoreLabel,
                    style: TextStyle(
                      fontSize: widget.size * 0.075,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double needleAngle;
  final Color gaugeColor;
  final Color trackColor;

  const _GaugePainter({
    required this.needleAngle,
    required this.gaugeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final radius = size.width / 2 - strokeWidth;
    final center = Offset(size.width / 2, size.height * 0.72);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track: full 180° arc (π to 2π, i.e., left to right along top)
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    // Score arc from left (π) sweeping clockwise by (π - needleAngle)
    // needleAngle: π = fully left (best), 0 = fully right (worst)
    // We want to fill from left up to the needle position.
    // Arc sweep = π - needleAngle
    final sweep = math.pi - needleAngle;
    if (sweep > 0.01) {
      canvas.drawArc(rect, math.pi, sweep, false, arcPaint);
    }

    // Needle
    // The arc starts at angle π (left) and each radian corresponds to
    // counter-clockwise movement. The needle sits at angle (π + (π - needleAngle))
    // measured from the positive x-axis in Flutter's coordinate system.
    // Simplification: needle direction angle from center = π + (π - needleAngle)
    //                 = 2π - needleAngle  ≡  -needleAngle
    // But let's reason carefully:
    //   In Flutter, 0 = right, π/2 = down, π = left.
    //   drawArc startAngle=π means 9-o'clock (left). As sweepAngle increases
    //   positively, it goes clockwise: left → bottom → right.
    //   At sweep s the tip is at angle π + s from positive x-axis.
    //   The needle tip angle = π + (π - needleAngle) = 2π - needleAngle.
    final needleTipAngle = math.pi + sweep;
    final needleLength = radius - strokeWidth / 2;
    final tipX = center.dx + needleLength * math.cos(needleTipAngle);
    final tipY = center.dy + needleLength * math.sin(needleTipAngle);

    final needlePaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, Offset(tipX, tipY), needlePaint);

    // Center pivot circle
    final pivotPaint = Paint()..color = gaugeColor;
    canvas.drawCircle(center, 5, pivotPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.needleAngle != needleAngle ||
      old.gaugeColor != gaugeColor ||
      old.trackColor != trackColor;
}
