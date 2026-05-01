import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/constants/score_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/meal_entry_entity.dart';
import '../providers/meal_provider.dart';

class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mealsAsync = ref.watch(mealsProvider);
    final summaryAsync = ref.watch(mealCalorieSummaryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Öğünlerim'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mealsProvider);
          ref.invalidate(mealCalorieSummaryProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: summaryAsync.when(
                data: (summary) => _SummaryCards(summary: summary),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: LinearProgressIndicator(),
                ),
                error: (error, stackTrace) => const SizedBox.shrink(),
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
              error: (error, stackTrace) => const SliverFillRemaining(
                child: Center(child: Text('Öğünler yüklenemedi.')),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final MealCalorieSummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(label: 'Bugün', kcal: summary.today),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(label: 'Hafta', kcal: summary.week),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(label: 'Ay', kcal: summary.month),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double kcal;

  const _SummaryCard({required this.label, required this.kcal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${kcal.round()} kcal',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
    final time = DateFormat('dd MMM HH:mm').format(meal.capturedAt);
    final gauge = meal.hpScore != null
        ? ScoreConstants.hpToGauge(meal.hpScore!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.pushNamed(RouteNames.mealDetail, extra: meal),
        onLongPress: () => _confirmDelete(context, ref),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
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
                      meal.mealName,
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
                      '${meal.brand} • $time',
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
                        if (gauge != null) _Pill(text: 'Skor $gauge'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Öğünü sil'),
        content: Text('"${meal.mealName}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(mealLocalDataSourceProvider).deleteMeal(meal.id);
    ref.invalidate(mealsProvider);
    ref.invalidate(mealCalorieSummaryProvider);
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

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
            'Henüz öğün yok',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tarama ekranındaki AI Analysis ile yemeğini fotoğraflayıp buraya kaydedebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
