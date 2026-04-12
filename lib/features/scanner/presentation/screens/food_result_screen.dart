import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../product/domain/entities/nutriments_entity.dart';
import '../../../product/domain/entities/product_entity.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../product/presentation/widgets/health_score_bar.dart';

class FoodResultScreen extends ConsumerStatefulWidget {
  final Uint8List imageBytes;

  const FoodResultScreen({super.key, required this.imageBytes});

  @override
  ConsumerState<FoodResultScreen> createState() => _FoodResultScreenState();
}

class _FoodResultScreenState extends ConsumerState<FoodResultScreen> {
  FoodRecognitionResult? _result;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _analyzeFood();
  }

  Future<void> _analyzeFood() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final aiService = ref.read(geminiAiServiceProvider);
      final result = await aiService.recognizeFood(widget.imageBytes);
      if (!mounted) return;
      setState(() {
        _result = result;
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

  Future<void> _saveToHistory() async {
    if (_result == null || _saving) return;

    setState(() => _saving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.saveFailedAuth)),
          );
        }
        return;
      }

      // Generate virtual barcode
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final shortUuid = DateTime.now().microsecond.toRadixString(16);
      final virtualBarcode = 'ai_${timestamp}_$shortUuid';

      final product = ProductEntity(
        barcode: virtualBarcode,
        productName: _result!.foodName,
        brands: context.l10n.aiEstimate,
        nutriments: _result!.toNutriments(),
      );

      // Calculate HP score
      final calculator = ref.read(hpScoreCalculatorProvider);
      final hpResult = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: _result!.toNutriments(),
      );

      // Save to community_products
      final communitySource = ref.read(communityProductSourceProvider);
      await communitySource.addProduct(
        product: product.copyWith(hpScore: hpResult.hpScore),
        userId: userId,
        source: 'ai_recognition',
      );

      // Add to scan history
      if (mounted) {
        await addScanToHistory(
          ref,
          barcode: virtualBarcode,
          hpScore: hpResult.hpScore,
        );
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSaved),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('[FoodResult] save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.saveFailed)),
        );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: colors.error),
            const SizedBox(height: 16),
            Text(
              l10n.aiFailed,
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

    // Calculate HP score from AI nutrients
    final nutriments = result.toNutriments();
    final hpScore = _estimateHpScore(nutriments);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Photo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Food name
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

          const SizedBox(height: 8),

          // Portion + Confidence badges
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

          // Low confidence warning
          if (result.confidence < 0.6) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: colors.warning),
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

          // Health score
          HealthScoreBar(hpScore: hpScore),

          const SizedBox(height: 16),

          // Macro grid
          _buildMacroGrid(result, l10n, colors),

          // Description
          if (result.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  result.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveToHistory,
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
                    label: Text(l10n.aiSaveToHistory),
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

  Widget _buildBadge(String text, AppColorsExtension colors,
      {bool isWarning = false}) {
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

  Widget _buildMacroGrid(
      FoodRecognitionResult result, dynamic l10n, AppColorsExtension colors) {
    final items = [
      _MacroItem(
          result.energyKcal.toStringAsFixed(0), 'kcal', colors.error),
      _MacroItem(
          '${result.protein.toStringAsFixed(1)}g', l10n.proteinLabel, colors.info),
      _MacroItem(
          '${result.fat.toStringAsFixed(1)}g', l10n.fatLabel, colors.warning),
      _MacroItem('${result.sugars.toStringAsFixed(1)}g', l10n.sugarLabel,
          colors.error),
      _MacroItem(
          '${result.fiber.toStringAsFixed(1)}g', l10n.fiberLabel, colors.success),
      _MacroItem(
          '${result.salt.toStringAsFixed(2)}g', l10n.saltLabel, colors.textMuted),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: items
                  .sublist(0, 3)
                  .map((item) => Expanded(child: _buildMacroCell(item, colors)))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: items
                  .sublist(3, 6)
                  .map((item) => Expanded(child: _buildMacroCell(item, colors)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCell(_MacroItem item, AppColorsExtension colors) {
    return Column(
      children: [
        Text(
          item.value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: item.color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  /// Estimates HP score from nutriments alone (no additive data available).
  /// Uses the same [ScoreConstants] as [HpScoreCalculator] for consistency.
  double _estimateHpScore(NutrimentsEntity n) {
    final sugarRisk =
        ((n.sugars ?? 0) / ScoreConstants.sugarMaxRef).clamp(0.0, 1.0) * 100;
    final saltRisk =
        ((n.salt ?? 0) / ScoreConstants.saltMaxRef).clamp(0.0, 1.0) * 100;
    final satFatRisk =
        ((n.saturatedFat ?? 0) / ScoreConstants.saturatedFatMaxRef)
            .clamp(0.0, 1.0) *
        100;
    final riskFactor = sugarRisk * ScoreConstants.sugarWeight +
        saltRisk * ScoreConstants.saltWeight +
        satFatRisk * ScoreConstants.saturatedFatWeight;

    final fiberBonus =
        ((n.fiber ?? 0) / ScoreConstants.fiberExcellent).clamp(0.0, 1.0) * 100;
    final proteinBonus =
        ((n.proteins ?? 0) / ScoreConstants.proteinExcellent).clamp(0.0, 1.0) *
        100;
    // No NOVA data from AI recognition — use unknown naturalness default
    final naturalnessBonus = ScoreConstants.novaUnknownNaturalness;
    final nutriFactor = fiberBonus * ScoreConstants.fiberWeight +
        proteinBonus * ScoreConstants.proteinWeight +
        naturalnessBonus * ScoreConstants.naturalnessWeight;

    return (100 -
            riskFactor * ScoreConstants.riskWeight +
            nutriFactor * ScoreConstants.nutriWeight)
        .clamp(0.0, 100.0);
  }
}

class _MacroItem {
  final String value;
  final String label;
  final Color color;

  const _MacroItem(this.value, this.label, this.color);
}
