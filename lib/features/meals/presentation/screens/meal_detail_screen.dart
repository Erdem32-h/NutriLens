import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../product/presentation/widgets/bento_nutrition_grid.dart';
import '../../../product/presentation/widgets/editorial_nutrient_table.dart';
import '../../../product/presentation/widgets/health_score_bar.dart';
import '../../domain/entities/meal_entry_entity.dart';

class MealDetailScreen extends StatelessWidget {
  final MealEntryEntity meal;

  const MealDetailScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = DateFormat('dd MMMM yyyy, HH:mm').format(meal.capturedAt);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(meal.mealName),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meal.photoThumbnailPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(
                      File(meal.photoThumbnailPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          _photoFallback(colors),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                meal.mealName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${meal.brand} • $time',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Chip(text: '${meal.calories.round()} kcal', colors: colors),
                  if (meal.hpScore != null)
                    _Chip(
                      text: 'Skor ${ScoreConstants.hpToGauge(meal.hpScore!)}',
                      colors: colors,
                    ),
                  if (meal.confidence != null)
                    _Chip(
                      text: '%${(meal.confidence! * 100).round()} güven',
                      colors: colors,
                    ),
                ],
              ),
            ),
            if (meal.hpScore != null) ...[
              const SizedBox(height: 16),
              HealthScoreBar(hpScore: meal.hpScore!),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  BentoNutritionGrid(nutriments: meal.nutriments),
                  const SizedBox(height: 16),
                  EditorialNutrientTable(nutriments: meal.nutriments),
                ],
              ),
            ),
            if ((meal.ingredientsText ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İçerik',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meal.ingredientsText!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _photoFallback(AppColorsExtension colors) {
    return Container(
      color: colors.surface,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 40,
          color: colors.textMuted,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final AppColorsExtension colors;

  const _Chip({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
