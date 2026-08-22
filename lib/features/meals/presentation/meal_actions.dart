import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/monetization_provider.dart';
import '../../../core/session/app_session.dart';
import '../domain/entities/meal_entry_entity.dart';
import 'meal_display.dart';
import 'providers/meal_chart_provider.dart';
import 'providers/meal_provider.dart';

/// Shows the delete-confirmation dialog and, if confirmed, deletes [meal]
/// locally (+ best-effort cloud, for premium) and invalidates every
/// provider the meal list/detail/chart screens depend on. Shared by
/// [MealsScreen]'s long-press and [MealDetailScreen]'s app bar action so
/// the cloud-sync-aware delete path lives in exactly one place.
///
/// Returns whether the meal was actually deleted (false on cancel).
Future<bool> confirmAndDeleteMeal({
  required BuildContext context,
  required WidgetRef ref,
  required MealEntryEntity meal,
}) async {
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
  if (confirmed != true) return false;

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
  ref.invalidate(todayCalorieTotalProvider);
  return true;
}
