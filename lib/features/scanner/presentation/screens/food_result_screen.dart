import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/anthropic_ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/ocr_image_prep.dart';
import '../../../meals/data/services/meal_thumbnail_service.dart';
import '../../../meals/domain/entities/meal_entry_entity.dart';
import '../../../meals/domain/services/meal_defaults.dart';
import '../../../meals/presentation/providers/meal_provider.dart';
import '../../../product/domain/entities/nutriments_entity.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../product/presentation/widgets/bento_nutrition_grid.dart';
import '../../../product/presentation/widgets/editorial_nutrient_table.dart';
import '../../../product/presentation/widgets/health_score_bar.dart';

class FoodResultScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;

  const FoodResultScreen({super.key, required this.imageBytes});

  @override
  ConsumerState<FoodResultScreen> createState() => _FoodResultScreenState();
}

class _FoodResultScreenState extends ConsumerState<FoodResultScreen> {
  late final DateTime _capturedAt;
  late final TextEditingController _mealNameController;
  late final TextEditingController _brandController;

  MealAnalysisResult? _result;
  bool _loading = true;
  String? _error;
  bool _serviceUnavailable = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _capturedAt = DateTime.now();
    final defaults = mealDefaultsFor(_capturedAt);
    _mealNameController = TextEditingController(text: defaults.name);
    _brandController = TextEditingController(text: defaults.brand);
    _analyzeFood();
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _analyzeFood() async {
    setState(() {
      _loading = true;
      _error = null;
      _serviceUnavailable = false;
    });

    try {
      final prepared = await prepareOcrImage(widget.imageBytes);
      final aiService = ref.read(anthropicAiServiceProvider);
      final result = await aiService.analyzeMealFromBase64(prepared.base64);
      if (result == null) throw Exception('AI returned empty meal result');
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on AnthropicServiceException catch (e) {
      debugPrint('[FoodResult] Claude service unavailable: $e');
      if (!mounted) return;
      setState(() {
        _serviceUnavailable = true;
        _error = e.toString();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FoodResult] analysis error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveMeal() async {
    if (_result == null || _saving) return;

    setState(() => _saving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailedAuth)));
        }
        return;
      }

      const uuid = Uuid();
      final mealId = uuid.v4();
      final defaults = mealDefaultsFor(_capturedAt);
      final thumbnailPath = await const MealThumbnailService().saveThumbnail(
        mealId: mealId,
        imageBytes: widget.imageBytes,
      );

      final calculator = ref.read(hpScoreCalculatorProvider);
      final hpResult = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: _result!.nutriments,
        ingredientsText: _result!.ingredientsText,
      );

      final meal = MealEntryEntity(
        id: mealId,
        userId: userId,
        photoThumbnailPath: thumbnailPath,
        mealName: _mealNameController.text.trim().isEmpty
            ? defaults.name
            : _mealNameController.text.trim(),
        brand: _brandController.text.trim().isEmpty
            ? defaults.brand
            : _brandController.text.trim(),
        mealType: defaults.type,
        capturedAt: _capturedAt,
        ingredientsText: _result!.ingredientsText,
        nutriments: _result!.nutriments,
        calories: _result!.nutriments.energyKcal ?? 0,
        hpScore: hpResult.hpScore,
        confidence: _result!.confidence,
        aiRawJson: _result!.rawJson,
      );

      await ref.read(mealLocalDataSourceProvider).saveMeal(meal);
      ref.invalidate(mealsProvider);
      ref.invalidate(mealCalorieSummaryProvider);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Öğün kaydedildi'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FoodResult] save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.aiAnalysisResult),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? _buildLoading(l10n, colors)
          : _error != null
          ? _buildError(l10n, colors)
          : _buildResult(l10n, colors),
    );
  }

  Widget _buildLoading(dynamic l10n, AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 24),
          Text(
            l10n.aiAnalyzing,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(dynamic l10n, AppColorsExtension colors) {
    final isServiceDown = _serviceUnavailable;
    final iconColor = isServiceDown ? colors.warning : colors.error;
    final icon = isServiceDown
        ? Icons.cloud_off_rounded
        : Icons.error_outline_rounded;
    final message = isServiceDown
        ? l10n.aiServiceUnavailableNoFallback
        : l10n.aiFailed;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _analyzeFood,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.aiRetake),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(dynamic l10n, AppColorsExtension colors) {
    final result = _result!;
    final confidencePercent = (result.confidence * 100).toInt();
    final nutriments = result.nutriments;
    final hpScore = _estimateHpScore(nutriments);

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                result.foodName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mealNameController,
                    decoration: const InputDecoration(
                      labelText: 'Öğün adı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Kaynak',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildBadge(
                  '${l10n.aiEstimatedPortion}: ~${result.portionGrams}g',
                  colors,
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  '${l10n.aiConfidence}: %$confidencePercent',
                  colors,
                  isWarning: result.confidence < 0.6,
                ),
              ],
            ),
          ),
          if (result.confidence < 0.6) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.aiLowConfidence,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          HealthScoreBar(hpScore: hpScore),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                BentoNutritionGrid(nutriments: nutriments),
                const SizedBox(height: 16),
                EditorialNutrientTable(nutriments: nutriments),
              ],
            ),
          ),
          if ((result.ingredientsText ?? result.description).isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.ingredientsText != null) ...[
                      Text(
                        'Tahmini içerik',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.ingredientsText!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (result.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        result.description,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveMeal,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text('Öğünlere kaydet'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(l10n.aiRetake),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBadge(
    String text,
    AppColorsExtension colors, {
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning
            ? colors.warning.withValues(alpha: 0.12)
            : colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isWarning ? colors.warning : colors.primary,
        ),
      ),
    );
  }

  double _estimateHpScore(NutrimentsEntity n) {
    final sugarRisk =
        ((n.sugars ?? 0) / ScoreConstants.sugarMaxRef).clamp(0.0, 1.0) * 100;
    final saltRisk =
        ((n.salt ?? 0) / ScoreConstants.saltMaxRef).clamp(0.0, 1.0) * 100;
    final satFatRisk =
        ((n.saturatedFat ?? 0) / ScoreConstants.saturatedFatMaxRef).clamp(
          0.0,
          1.0,
        ) *
        100;
    final riskFactor =
        sugarRisk * ScoreConstants.sugarWeight +
        saltRisk * ScoreConstants.saltWeight +
        satFatRisk * ScoreConstants.saturatedFatWeight;

    final fiberBonus =
        ((n.fiber ?? 0) / ScoreConstants.fiberExcellent).clamp(0.0, 1.0) * 100;
    final proteinBonus =
        ((n.proteins ?? 0) / ScoreConstants.proteinExcellent).clamp(0.0, 1.0) *
        100;
    const naturalnessBonus = ScoreConstants.novaUnknownNaturalness;
    final nutriFactor =
        fiberBonus * ScoreConstants.fiberWeight +
        proteinBonus * ScoreConstants.proteinWeight +
        naturalnessBonus * ScoreConstants.naturalnessWeight;

    return (100 -
            riskFactor * ScoreConstants.riskWeight +
            nutriFactor * ScoreConstants.nutriWeight)
        .clamp(0.0, 100.0);
  }
}
