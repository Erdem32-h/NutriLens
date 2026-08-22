import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/meal_entry_entity.dart';
import '../providers/meal_chart_provider.dart';
import '../providers/meal_provider.dart';

/// Manual correction screen for an already-saved meal — name, source,
/// ingredients text and the four numbers the app actually shows
/// (calories, protein, carbs, fat). Deliberately does not re-run AI
/// analysis or let the user swap the photo: those are materially bigger
/// features (a fresh API call, thumbnail regeneration) than "the AI
/// misread the label, let me fix the protein number".
class MealEditScreen extends ConsumerStatefulWidget {
  final MealEntryEntity meal;

  const MealEditScreen({super.key, required this.meal});

  @override
  ConsumerState<MealEditScreen> createState() => _MealEditScreenState();
}

class _MealEditScreenState extends ConsumerState<MealEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _nameController = TextEditingController(text: meal.mealName);
    _brandController = TextEditingController(text: meal.brand);
    _ingredientsController = TextEditingController(
      text: meal.ingredientsText ?? '',
    );
    _caloriesController = TextEditingController(
      text: meal.calories.round().toString(),
    );
    _proteinController = TextEditingController(
      text: _formatOrEmpty(meal.nutriments.proteins),
    );
    _carbsController = TextEditingController(
      text: _formatOrEmpty(meal.nutriments.carbohydrates),
    );
    _fatController = TextEditingController(
      text: _formatOrEmpty(meal.nutriments.fat),
    );
  }

  String _formatOrEmpty(double? value) =>
      value == null ? '' : value.round().toString();

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _ingredientsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final calories = double.tryParse(_caloriesController.text) ?? 0;
      final updated = widget.meal.copyWith(
        mealName: _nameController.text.trim().isEmpty
            ? widget.meal.mealName
            : _nameController.text.trim(),
        brand: _brandController.text.trim(),
        ingredientsText: _ingredientsController.text.trim(),
        calories: calories,
        nutriments: widget.meal.nutriments.copyWith(
          energyKcal: calories,
          proteins: double.tryParse(_proteinController.text),
          carbohydrates: double.tryParse(_carbsController.text),
          fat: double.tryParse(_fatController.text),
        ),
        updatedAt: DateTime.now(),
      );

      await ref.read(mealLocalDataSourceProvider).saveMeal(updated);
      ref.read(analyticsServiceProvider).track(FunnelEvents.mealEdited);
      // Premium users get the correction mirrored to the cloud; free users
      // stay local-only. Best-effort, matches the original save path.
      if (ref.read(isPremiumProvider)) {
        unawaited(ref.read(mealSyncServiceProvider).pushMeal(updated));
      }
      ref.invalidate(mealsProvider);
      ref.invalidate(calorieChartDataProvider);
      ref.invalidate(todayCalorieTotalProvider);
      unawaited(
        ref.read(homeWidgetServiceProvider).refresh(userId: updated.userId),
      );

      if (!mounted) return;
      Navigator.of(context).pop(updated);
      messenger.showSnackBar(SnackBar(content: Text(l10n.mealUpdatedToast)));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.editMeal),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(label: l10n.mealNameLabel, controller: _nameController),
              const SizedBox(height: 14),
              _Field(
                label: l10n.mealSourceLabel,
                controller: _brandController,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: l10n.caloriesLabel,
                      controller: _caloriesController,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      label: l10n.proteinLabel,
                      controller: _proteinController,
                      numeric: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: l10n.carbohydrates,
                      controller: _carbsController,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      label: l10n.fatLabel,
                      controller: _fatController,
                      numeric: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Field(
                label: l10n.ingredientsTitle,
                controller: _ingredientsController,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: l10n.saveChanges,
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.numeric = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: false)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}
