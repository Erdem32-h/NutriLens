import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/calorie_chart_data.dart';
import '../../domain/services/calorie_chart_aggregator.dart';
import '../providers/meal_chart_provider.dart';

class CaloriePeriodSelector extends ConsumerWidget {
  const CaloriePeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final period = ref.watch(caloriePeriodProvider);
    final offset = ref.watch(calorieOffsetProvider);

    String labelFor(CaloriePeriod p) => switch (p) {
          CaloriePeriod.day => l10n.caloriePeriodDay,
          CaloriePeriod.week => l10n.caloriePeriodWeek,
          CaloriePeriod.month => l10n.caloriePeriodMonth,
          CaloriePeriod.year => l10n.caloriePeriodYear,
        };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              for (final p in CaloriePeriod.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(caloriePeriodProvider.notifier).state = p;
                      ref.read(calorieOffsetProvider.notifier).state = 0;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: p == period ? colors.primary : null,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labelFor(p),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          // AppColorsExtension'da onPrimary yok; AppButton'ın
                          // primary-dolgu konvansiyonu (app_button.dart:112-116)
                          // seçili pilin üstünde de aynı şekilde Colors.black
                          // kullanır — iki temada da primary dolgu üstünde
                          // okunur kalır.
                          color: p == period
                              ? Colors.black
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: colors.textMuted,
              onPressed: () =>
                  ref.read(calorieOffsetProvider.notifier).state = offset + 1,
            ),
            Text(
              _rangeLabel(context, period, offset),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: colors.textMuted,
              // IconButton disabled durumda `color`'u değil `disabledColor`'ı
              // kullanır (Flutter davranışı) — disabledColor açıkça
              // verilmezse tema varsayılanına döner, tasarımdaki soluk
              // görünüm kaybolur.
              disabledColor: colors.textMuted.withValues(alpha: 0.3),
              // Gelecek döneme geçilemez (spec §11).
              onPressed: offset == 0
                  ? null
                  : () => ref.read(calorieOffsetProvider.notifier).state =
                      offset - 1,
            ),
          ],
        ),
      ],
    );
  }

  String _rangeLabel(BuildContext context, CaloriePeriod period, int offset) {
    final locale = Localizations.localeOf(context).toString();
    final range =
        CalorieChartAggregator.rangeFor(period, offset, DateTime.now());
    switch (period) {
      case CaloriePeriod.day:
        return DateFormat('d MMMM', locale).format(range.start);
      case CaloriePeriod.week:
        final end = range.end.subtract(const Duration(days: 1));
        final fmt = DateFormat('d MMM', locale);
        return '${fmt.format(range.start)} – ${fmt.format(end)}';
      case CaloriePeriod.month:
        return DateFormat('MMMM yyyy', locale).format(range.start);
      case CaloriePeriod.year:
        return DateFormat('yyyy', locale).format(range.start);
    }
  }
}
