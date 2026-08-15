import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/macro_colors.dart';
import '../../domain/entities/calorie_chart_data.dart';
import '../../domain/entities/meal_entry_entity.dart';
import '../meal_display.dart';

class CalorieStackedBarChart extends StatelessWidget {
  final CalorieChartData data;

  /// Günlük kalori hedefi. Verilirse barların üstüne yatay kesikli bir
  /// referans çizgisi çizilir. `null` geçildiğinde (varsayılan) grafik
  /// bu parametre eklenmeden önceki haliyle bit bit aynı render olur —
  /// hiçbir mevcut ekran bu parametreyi geçmeye zorlanmaz.
  final int? targetKcal;

  const CalorieStackedBarChart({super.key, required this.data, this.targetKcal});

  static const double _chartHeight = 160;
  static const double _labelRowHeight = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxKcal = data.buckets
        .map((b) => b.kcal)
        .fold<double>(0, (max, v) => v > max ? v : max);
    // Hedef, görünen en yüksek bardan büyükse ölçeği hedefe göre genişlet —
    // aksi halde hedef çizgisi grafiğin üstünden taşar. targetKcal null
    // olduğunda (varsayılan davranış) effectiveMax == maxKcal, yani mevcut
    // render'da hiçbir değişiklik olmaz.
    final effectiveMax = (targetKcal != null && targetKcal! > maxKcal)
        ? targetKcal!.toDouble()
        : maxKcal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight + _labelRowHeight,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < data.buckets.length; i++)
                    Expanded(child: _bar(context, i, effectiveMax)),
                ],
              ),
              if (targetKcal != null && effectiveMax > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  // Kesikli çizginin taşan barları işaretlediği durum
                  // (target < effectiveMax) zaten `bottom`u chartHeight'in
                  // içinde tutar. targetKcal >= effectiveMax olduğunda
                  // (yani hedef hiçbir barı aşmadığı en yaygın durumda)
                  // ham hesap `bottom`u Stack'in tam yüksekliğine, hatta
                  // üstüne taşırıp çizgiyi Clip.hardEdge ile keserdi — bu
                  // yüzden en fazla "üst kenara yaslı" konuma clamp'liyoruz.
                  bottom: math.min(
                    _labelRowHeight + _chartHeight - _TargetLine.height,
                    _labelRowHeight +
                        _chartHeight * (targetKcal! / effectiveMax),
                  ),
                  child: IgnorePointer(
                    child: _TargetLine(color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _legend(context, colors),
      ],
    );
  }

  Widget _bar(BuildContext context, int index, double maxKcal) {
    final colors = context.colors;
    final bucket = data.buckets[index];
    final heightFactor = maxKcal == 0 ? 0.0 : bucket.kcal / maxKcal;
    final barHeight = _chartHeight * heightFactor;
    final macro = bucket.macroKcal;

    // Ay görünümünde her barın etiketi sığmaz — 1, 8, 15, 22, 29.
    final showLabel =
        data.period != CaloriePeriod.month || index % 7 == 0;

    Widget segment(double kcal, Color color) {
      if (macro == 0 || kcal == 0) return const SizedBox.shrink();
      return SizedBox(
        // ColoredBox olmadan child verildiğinde, gevşek genişlik
        // kısıtında en küçük boyutu (0) seçer — width olmadan segment
        // görünmez bir dilime çöker.
        width: double.infinity,
        height: barHeight * (kcal / macro),
        child: ColoredBox(color: color),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: data.buckets.length > 12 ? 1.5 : 5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            child: bucket.kcal == 0
                ? const SizedBox.shrink()
                : macro == 0
                    // kcal var ama makro dökümü yok → nötr tek renk bar
                    ? SizedBox(
                        height: barHeight,
                        width: double.infinity,
                        child: ColoredBox(
                          color: colors.textMuted.withValues(alpha: 0.35),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            segment(bucket.proteinKcal, MacroColors.protein),
                            segment(bucket.carbKcal, MacroColors.carbs),
                            segment(bucket.fatKcal, MacroColors.fat),
                          ],
                        ),
                      ),
          ),
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                showLabel ? _labelFor(context, index) : '',
                style: TextStyle(fontSize: 10, color: colors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, int index) {
    final locale = Localizations.localeOf(context).toString();
    switch (data.period) {
      case CaloriePeriod.day:
        return mealTypeLabel(context.l10n, MealType.values[index]);
      case CaloriePeriod.week:
        final day = data.rangeStart.add(Duration(days: index));
        return DateFormat.E(locale).format(day);
      case CaloriePeriod.month:
        return '${index + 1}';
      case CaloriePeriod.year:
        final month = DateTime(data.rangeStart.year, index + 1);
        return DateFormat.MMM(locale).format(month);
    }
  }

  Widget _legend(BuildContext context, AppColorsExtension colors) {
    final l10n = context.l10n;
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        item(MacroColors.protein, l10n.macroProtein),
        item(MacroColors.carbs, l10n.macroCarbs),
        item(MacroColors.fat, l10n.macroFat),
      ],
    );
  }
}

/// Hedef kalorinin barlar üzerindeki konumunu işaretleyen ince yatay
/// kesikli çizgi. Sabit renk çözünürlüğü/kalınlık — dolgu barları
/// (ColoredBox segmentleri) ile karışmasın diye düz renk yerine kesikli
/// çizilir.
class _TargetLine extends StatelessWidget {
  final Color color;

  const _TargetLine({required this.color});

  static const double height = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _DashedLinePainter(color: color),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  static const double _dashWidth = 6;
  static const double _dashGap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + _dashWidth, y), paint);
      x += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
