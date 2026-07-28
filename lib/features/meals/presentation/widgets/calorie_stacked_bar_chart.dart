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

  const CalorieStackedBarChart({super.key, required this.data});

  static const double _chartHeight = 160;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxKcal = data.buckets
        .map((b) => b.kcal)
        .fold<double>(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight + 24, // bar + etiket satırı
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.buckets.length; i++)
                Expanded(child: _bar(context, i, maxKcal)),
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
                overflow: TextOverflow.clip,
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
