import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_tap_card.dart';
import '../../../profile/presentation/providers/user_metrics_provider.dart';
import '../../domain/entities/calorie_chart_data.dart';
import '../../domain/entities/meal_entry_entity.dart';
import '../meal_actions.dart';
import '../meal_display.dart';
import '../providers/meal_chart_provider.dart';
import '../providers/meal_provider.dart';
import '../widgets/calorie_period_selector.dart';
import '../widgets/calorie_stacked_bar_chart.dart';
import '../widgets/macro_balance_card.dart';
import '../../../scanner/presentation/providers/scanner_mode_provider.dart';

class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mealsAsync = ref.watch(mealsProvider);
    // Premium-only one-shot: push pending local meals + pull cloud meals down.
    ref.watch(mealCloudSyncProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.myMeals),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mealsProvider);
          ref.invalidate(calorieChartDataProvider);
          ref.invalidate(todayCalorieTotalProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: _CalorieInsights(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: _DailyTargetSummary(),
              ),
            ),
            mealsAsync.when(
              data: (meals) {
                if (meals.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyMeals(),
                  );
                }
                return SliverList.separated(
                  itemCount: meals.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _MealTile(meal: meals[index]),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => SliverFillRemaining(
                child: Center(child: Text(context.l10n.mealsLoadError)),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _MealTile extends ConsumerWidget {
  final MealEntryEntity meal;

  const _MealTile({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final time = DateFormat('dd MMM HH:mm').format(meal.capturedAt);
    final gauge = meal.hpScore != null
        ? ScoreConstants.hpToGauge(meal.hpScore!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppTapCard(
        onTap: () => context.pushNamed(RouteNames.mealDetail, extra: meal),
        onLongPress: () =>
            confirmAndDeleteMeal(context: context, ref: ref, meal: meal),
        semanticLabel: displayMealName(l10n, meal),
        borderRadius: BorderRadius.circular(14),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: meal.photoThumbnailPath != null
                      ? Image.file(
                          File(meal.photoThumbnailPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _thumbFallback(colors),
                        )
                      : _thumbFallback(colors),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayMealName(l10n, meal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${displayMealBrand(l10n, meal.brand)} • $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pill(text: '${meal.calories.round()} kcal'),
                        if (gauge != null)
                          _Pill(text: '${context.l10n.scoreLabel} $gauge'),
                        if (meal.confidence != null)
                          _Pill(text: '%${(meal.confidence! * 100).round()}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback(AppColorsExtension colors) {
    return Container(
      color: colors.surface,
      child: Icon(Icons.restaurant_rounded, color: colors.textMuted),
    );
  }

}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyMeals extends ConsumerWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 64,
            color: colors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMealsYet,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noMealsHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: 28),
          // This is the landing screen on every launch, so for a new
          // user it is the first thing they see — previously an icon
          // and two lines of text with nothing to tap. Send them to
          // the one action the whole app is built around.
          // Meals are logged by photographing food, not by scanning a
          // barcode — so this opens the scanner already in AI Analysis
          // mode rather than dropping the user on the barcode reader.
          AppButton(
            label: l10n.scanFood,
            icon: Icons.center_focus_strong_rounded,
            expand: false,
            onPressed: () {
              ref.read(pendingScannerModeProvider.notifier).state = 1;
              context.goNamed(RouteNames.scanner);
            },
          ),
        ],
      ),
    );
  }
}

class _CalorieInsights extends ConsumerWidget {
  const _CalorieInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final chartAsync = ref.watch(calorieChartDataProvider);

    return Column(
      children: [
        const CaloriePeriodSelector(),
        const SizedBox(height: 14),
        chartAsync.when(
          // Sekme/dönem değişiminde provider yeniden yüklenirken önceki
          // grafik ekranda kalmalı: loading dalı grafiği ~40px'lik
          // spinner'a çökertip alttaki öğün listesini zıplatıyor. Spinner
          // yalnızca ilk yüklemede (henüz hiç veri yokken) görünür.
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                context.l10n.mealsLoadError,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
          data: (data) {
            if (data.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    context.l10n.calorieChartEmptyPeriod,
                    style: TextStyle(color: colors.textMuted),
                  ),
                ),
              );
            }
            return Column(
              children: [
                CalorieStackedBarChart(
                  data: data,
                  // Yalnızca günlük kova (hafta/ay) barlarında hedef çizgisi
                  // anlamlıdır: gün görünümü öğün tipine göre, yıl görünümü
                  // ay toplamına göre kovalar — ikisinde de günlük hedef
                  // çizgisi anlamsız olur. Metrics yoksa null: hiçbir
                  // no-metrics kullanıcı çizgi/rescale görmez (bkz. widget
                  // dokstring'i).
                  targetKcal:
                      (data.period == CaloriePeriod.week ||
                              data.period == CaloriePeriod.month)
                          ? ref.watch(personalDailyCaloriesProvider)
                          : null,
                ),
                const SizedBox(height: 14),
                MacroBalanceCard(data: data),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Günün toplam alınan kalorisi / günlük hedef özeti + ilerleme çubuğu.
/// Öğün listesinin başlığının üstünde yaşar — [_CalorieInsights]'taki
/// grafik hangi dönem sekmesinde olursa olsun (Gün/Hafta/Ay/Yıl) bu satır
/// her zaman BUGÜNÜ gösterir; [todayCalorieTotalProvider] bilerek grafiğin
/// caloriePeriodProvider/calorieOffsetProvider durumundan bağımsızdır.
///
/// Metrics kaydı yoksa [dailyCalorieTargetProvider] varsayılan 2000 kcal'e
/// düşer — bu widget o durumda da çökmeden, aynı satırı 2000 hedefiyle
/// gösterir (bkz. task brief'teki global kısıt).
class _DailyTargetSummary extends ConsumerWidget {
  const _DailyTargetSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final totalAsync = ref.watch(todayCalorieTotalProvider);
    final target = ref.watch(dailyCalorieTargetProvider);

    return totalAsync.when(
      data: (total) {
        final consumed = total.round();
        final over = consumed - target;
        final progress = target <= 0 ? 0.0 : (total / target).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dailyCalorieSummary(consumed, target),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: colors.border,
                  color: over > 0 ? colors.error : colors.primary,
                ),
              ),
              if (over > 0) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.dailyCalorieOver(over),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              // Metrics girilmemiş kullanıcılar için hedef sessizce
              // varsayılan 2000 kcal'e düşer (bkz. sınıf dokstring'i) — bu
              // satır her zaman görünür, çünkü gösterilen sayı ne olursa
              // olsun (kişisel veya varsayılan) tıbbi tavsiye değil, tahmini
              // bir referanstır. Sessiz/ikincil renk: bir uyarı değil, bir
              // niteleyici.
              Text(
                l10n.metricsMedicalDisclaimer,
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        );
      },
      // İlk yüklemede/hata durumunda sessizce boş bırak — bu satırın kendi
      // spinner'ı, üstündeki grafik bölümünün spinner'ıyla aynı anda çakışıp
      // ekranı zıplatmasın (bkz. calorieChartDataProvider.skipLoadingOnReload
      // yorumu, aynı gerekçe).
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
