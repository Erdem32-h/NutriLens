import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_tap_card.dart';
import '../../domain/entities/meal_entry_entity.dart';
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
        onLongPress: () => _confirmDelete(context, ref),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMealTitle),
        content: Text(l10n.deleteMealConfirm(displayMealName(l10n, meal))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(mealLocalDataSourceProvider).deleteMeal(meal.id);
    // Premium: also remove the cloud copy (row + photo). Best-effort.
    if (ref.read(isPremiumProvider)) {
      final userId = ref.read(effectiveUserIdProvider);
      if (userId != null) {
        unawaited(
          ref
              .read(mealSyncServiceProvider)
              .deleteMeal(id: meal.id, userId: userId),
        );
      }
    }
    ref.invalidate(mealsProvider);
    ref.invalidate(calorieChartDataProvider);
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
                CalorieStackedBarChart(data: data),
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
