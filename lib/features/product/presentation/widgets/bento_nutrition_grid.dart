import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nutriments_entity.dart';

class BentoNutritionGrid extends StatelessWidget {
  final NutrimentsEntity nutriments;

  const BentoNutritionGrid({super.key, required this.nutriments});

  // Daily reference values (grams)
  static const _dailyFat = 70.0;
  static const _dailySugar = 50.0;
  static const _dailySatFat = 20.0;
  static const _dailySalt = 6.0;
  static const _dailyCalories = 2000.0;
  static const _dailyCarbs = 260.0;

  static int _riskLevel(double percent) {
    if (percent < 15) return 1;
    if (percent < 30) return 2;
    if (percent < 50) return 3;
    if (percent < 75) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    final hasData = nutriments.energyKcal != null ||
        nutriments.fat != null ||
        nutriments.sugars != null;

    if (!hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              l10n.noNutrientData,
              style: TextStyle(
                fontSize: 14,
                color: colors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    final kcal = nutriments.energyKcal ?? 0;
    final kcalPercent = (kcal / _dailyCalories * 100).clamp(0, 100).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Calorie card (full width)
          _CalorieCard(
            kcal: kcal,
            percent: kcalPercent,
          ),

          const SizedBox(height: 12),

          // 2x2 macro grid
          Row(
            children: [
              Expanded(
                child: _MacroCard(
                  label: l10n.fatLabel,
                  value: nutriments.fat,
                  dailyRef: _dailyFat,
                  unit: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroCard(
                  label: l10n.sugarLabel,
                  value: nutriments.sugars,
                  dailyRef: _dailySugar,
                  unit: 'g',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MacroCard(
                  label: l10n.saturatedFatLabel,
                  value: nutriments.saturatedFat,
                  dailyRef: _dailySatFat,
                  unit: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroCard(
                  label: l10n.saltLabel,
                  value: nutriments.salt,
                  dailyRef: _dailySalt,
                  unit: 'g',
                ),
              ),
            ],
          ),

          if (nutriments.carbohydrates != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MacroCard(
                    label: l10n.carbohydrateLabel,
                    value: nutriments.carbohydrates,
                    dailyRef: _dailyCarbs,
                    unit: 'g',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final double kcal;
  final double percent;

  const _CalorieCard({required this.kcal, required this.percent});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.energyValue,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      kcal.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Circular progress
          SizedBox(
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: percent / 100,
                trackColor: colors.surfaceCard2,
                progressColor: colors.primary,
              ),
              child: Center(
                child: Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 5.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    final progressAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double? value;
  final double dailyRef;
  final String unit;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.dailyRef,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final amount = value ?? 0.0;
    final percent = (amount / dailyRef * 100).clamp(0, 999).toDouble();
    final risk = BentoNutritionGrid._riskLevel(percent);
    final riskColor = colors.gaugeColor(risk);

    final riskLabel = switch (risk) {
      1 => l10n.lowLevel,
      2 => l10n.moderateLevel,
      3 => l10n.highLevel,
      4 => l10n.criticalLevel,
      _ => l10n.veryHighLevel,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border(
          bottom: BorderSide(color: riskColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amount.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                backgroundColor: colors.surfaceCard2,
                valueColor: AlwaysStoppedAnimation(riskColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                riskLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: riskColor,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
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
    );
  }
}
