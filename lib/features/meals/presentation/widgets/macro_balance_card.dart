import 'package:flutter/material.dart';

import '../../../../core/constants/macro_reference_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/macro_colors.dart';
import '../../domain/entities/calorie_chart_data.dart';

class MacroBalanceCard extends StatelessWidget {
  final CalorieChartData data;

  const MacroBalanceCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDay = data.period == CaloriePeriod.day;
    final kcalValue = isDay ? data.totalKcal : data.avgKcalPerDay;
    // kcal var ama makro dökümü yok (örn. sadece kalori girilmiş bir öğün) —
    // bu durumda %0/Düşük göstermek "eksik besleniyorsun" yanılgısı üretir;
    // calorie_stacked_bar_chart.dart'taki nötr gri bar ile aynı ruhta,
    // pay+etiket yerine nötr bir yer tutucu gösteriyoruz.
    final hasMacroData =
        data.proteinKcal + data.carbKcal + data.fatKcal > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // toUpperCase() BİLEREK yok: Dart'ın toUpperCase()'i locale-aware
            // değil (Türkçe "i" → "İ" değil "I" olur) ve widget testi bu
            // metni verbatim ("Toplam"/"Günlük ortalama") arıyor — l10n
            // değeri zaten doğru büyük/küçük harfle yazılmış, üstüne
            // dokunmuyoruz.
            isDay ? l10n.calorieCardTotal : l10n.calorieCardAverageDaily,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${kcalValue.round()}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'kcal',
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _macroRow(context, l10n.macroProtein, MacroColors.protein,
              data.proteinPct, data.proteinLevel, hasMacroData),
          const SizedBox(height: 10),
          _macroRow(context, l10n.macroCarbs, MacroColors.carbs, data.carbPct,
              data.carbLevel, hasMacroData),
          const SizedBox(height: 10),
          _macroRow(context, l10n.macroFat, MacroColors.fat, data.fatPct,
              data.fatLevel, hasMacroData),
        ],
      ),
    );
  }

  Widget _macroRow(
    BuildContext context,
    String name,
    Color identityColor,
    double pct,
    MacroLevel level,
    bool hasMacroData,
  ) {
    final colors = context.colors;
    final l10n = context.l10n;
    final levelLabel = switch (level) {
      MacroLevel.low => l10n.macroLevelLow,
      MacroLevel.normal => l10n.macroLevelNormal,
      MacroLevel.high => l10n.macroLevelHigh,
    };
    final levelColor =
        MacroColors.levelColor(level, Theme.of(context).brightness);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: identityColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (!hasMacroData)
          Text(
            '—',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          )
        else ...[
          Text(
            '%${pct.round()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              levelLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: levelColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
