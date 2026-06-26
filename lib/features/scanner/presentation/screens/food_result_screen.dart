import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_links.dart';
import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/services/anthropic_ai_service.dart';
import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/ocr_image_prep.dart';
import '../providers/scanner_mode_provider.dart';
import '../../../meals/data/services/meal_thumbnail_service.dart';
import '../../../meals/domain/entities/meal_entry_entity.dart';
import '../../../meals/domain/services/meal_defaults.dart';
import '../../../meals/presentation/meal_display.dart';
import '../../../meals/presentation/providers/meal_provider.dart';
import '../../../product/domain/entities/nutriments_entity.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../product/presentation/widgets/bento_nutrition_grid.dart';
import '../../../product/presentation/widgets/editorial_nutrient_table.dart';
import '../../../product/presentation/widgets/health_score_bar.dart';
import '../../../share/domain/share_caption.dart';
import '../../../share/presentation/widgets/meal_share_card.dart';

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
  late final TextEditingController _ingredientsController;
  late final TextEditingController _portionNoteController;

  MealAnalysisResult? _result;
  bool _loading = true;
  String? _error;
  bool _serviceUnavailable = false;
  bool _quotaExhausted = false;
  bool _saving = false;
  bool _recalcLoading = false;

  /// User-tunable multiplier applied to portion grams + nutrition before
  /// the meal is saved. 1.0 = trust the AI estimate (default), 0.5 =
  /// "I ate half", 1.5 = "bigger portion", 2.0 = "I ate twice the
  /// estimate". Reset on a fresh _analyzeFood / _recalculateNutrition.
  double _portionMultiplier = 1.0;

  /// Prefill is deferred to [didChangeDependencies] so the default meal
  /// name/source render in the *active* locale (Localizations isn't ready
  /// inside initState).
  bool _defaultsPrefilled = false;

  @override
  void initState() {
    super.initState();
    _capturedAt = DateTime.now();
    _mealNameController = TextEditingController();
    _brandController = TextEditingController();
    _ingredientsController = TextEditingController();
    _portionNoteController = TextEditingController();
    _analyzeFood();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultsPrefilled) return;
    _defaultsPrefilled = true;
    final defaults = mealDefaultsFor(_capturedAt);
    final l10n = context.l10n;
    _mealNameController.text = mealTypeLabel(l10n, defaults.type);
    _brandController.text = l10n.mealBrandHomemade;
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _brandController.dispose();
    _ingredientsController.dispose();
    _portionNoteController.dispose();
    super.dispose();
  }

  Future<void> _analyzeFood() async {
    setState(() {
      _loading = true;
      _error = null;
      _serviceUnavailable = false;
      _quotaExhausted = false;
    });

    try {
      final prepared = await prepareMealAnalysisImage(widget.imageBytes);
      // Generate the food name / ingredients / description in the app's
      // active language so an English user gets "Rice with Meat" rather
      // than "Etli Pilav" from the start (locale-aware generation).
      final languageCode = ref.read(localeProvider).languageCode;
      // Everyone — guests included — now goes through the server-side
      // OpenRouter proxy (key never on the client). The device hash lets the
      // edge function rate-limit anon (guest) callers without a user JWT.
      // Label OCR (ingredients/nutrition) now uses the same OpenRouter path.
      final deviceHash = await ref.read(deviceIdServiceProvider).deviceHash();
      final result = await ref
          .read(geminiAiServiceProvider)
          .analyzeMeal(
            prepared.base64,
            languageCode: languageCode,
            deviceHash: deviceHash,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _ingredientsController.text = result.ingredientsText ?? '';
        _loading = false;
      });
      // Non-homemade food (packaged product, restaurant, or takeout/delivery)
      // → default the source label to "Hazır Gıda" instead of "Ev yapımı",
      // unless the user already changed it.
      final l10n = context.l10n;
      if (result.foodSource != MealFoodSource.homemade &&
          _brandController.text.trim() == l10n.mealBrandHomemade) {
        _brandController.text = l10n.mealBrandReadyMade;
      }
      // Packaged retail product photographed in the AI tab → the meal
      // estimate is meaningless for it (wrong name + harsh score). Steer the
      // user to barcode scanning, but let them analyze anyway if they insist.
      if (result.isPackagedProduct) {
        _showPackagedProductDialog();
      }
    } on GeminiServiceException catch (e, st) {
      debugPrint('[FoodResult] proxy meal analysis failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
      if (!mounted) return;
      setState(() {
        _serviceUnavailable = true;
        // Proxy maps OpenRouter out-of-credit/rate-limit to HTTP 429.
        _quotaExhausted = e.statusCode == 429;
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

  /// Packaged product detected by the meal model. Offer to switch to barcode
  /// scanning (accurate score path) or analyze the photo as a meal anyway.
  void _showPackagedProductDialog() {
    final l10n = context.l10n;
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        icon: Icon(
          Icons.inventory_2_outlined,
          color: colors.primary,
          size: 36,
        ),
        title: Text(
          l10n.aiPackagedTitle,
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          l10n.aiPackagedBody,
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.aiAnalyzeAnyway,
              style: TextStyle(color: colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Ask the scanner to come back up in barcode mode, then leave
              // this screen — the scanner consumes the request on resume.
              ref.read(pendingScannerModeProvider.notifier).state = 0;
              context.pop();
            },
            child: Text(
              l10n.scanBarcodeTitle,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recalculateNutrition() async {
    final text = _ingredientsController.text.trim();
    final portionNote = _portionNoteController.text.trim();
    if (_recalcLoading || _result == null) return;
    if (text.isEmpty && portionNote.isEmpty) return;
    setState(() => _recalcLoading = true);
    try {
      final ingredients = text.isEmpty
          ? (_result!.ingredientsText ?? '')
          : text;
      final note = portionNote.isEmpty ? null : portionNote;
      // Proxy for everyone (guests included), same as _analyzeFood.
      final deviceHash = await ref.read(deviceIdServiceProvider).deviceHash();
      final recalc = await ref.read(geminiAiServiceProvider).recalculateMeal(
        ingredientsText: ingredients,
        portionNote: note,
        deviceHash: deviceHash,
      );
      if (!mounted) return;
      if (recalc != null) {
        setState(() {
          _result = MealAnalysisResult(
            foodName: _result!.foodName,
            // Prefer the model's new portion estimate; fall back to old.
            portionGrams: recalc.portionGrams > 0
                ? recalc.portionGrams
                : _result!.portionGrams,
            ingredientsText: text.isEmpty ? _result!.ingredientsText : text,
            nutriments: recalc.nutriments,
            confidence: _result!.confidence,
            description: _result!.description,
            rawJson: _result!.rawJson,
            foodSource: _result!.foodSource,
          );
          // Fresh estimate → discard any portion adjustment the user
          // had applied to the previous values. The new portion_note
          // they may have just typed is already baked into the
          // recalc result, so 1× is the right starting point.
          _portionMultiplier = 1.0;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.recalcFailedNutrition)),
          );
        }
      }
    } on GeminiServiceException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recalcFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _recalcLoading = false);
    }
  }

  Future<void> _saveMeal() async {
    if (_result == null || _saving) return;

    setState(() => _saving = true);

    try {
      // Guests get the kGuestUserId sentinel so meals land in local
      // Drift the same as authenticated users — no auth check needed.
      final userId = ref.read(effectiveUserIdProvider);
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

      // Apply the user-chosen portion multiplier (½× / 1× / 1½× / 2×)
      // to both the macros and the kcal total before persistence. HP
      // Score is calculated on the original per-portion nutrition (it
      // measures food quality, not quantity), so scaling there would
      // distort the result — we score before scaling.
      final scaledNutriments = _result!.nutriments.scaled(_portionMultiplier);
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
        ingredientsText: _ingredientsController.text.trim().isNotEmpty
            ? _ingredientsController.text.trim()
            : _result!.ingredientsText,
        nutriments: scaledNutriments,
        calories: scaledNutriments.energyKcal ?? 0,
        hpScore: hpResult.hpScore,
        confidence: _result!.confidence,
        aiRawJson: _result!.rawJson,
      );

      await ref.read(mealLocalDataSourceProvider).saveMeal(meal);
      // Premium users get a cloud backup; free users stay local-only.
      // Best-effort, fire-and-forget — the local save above is authoritative.
      if (ref.read(isPremiumProvider)) {
        unawaited(ref.read(mealSyncServiceProvider).pushMeal(meal));
      }
      ref.invalidate(mealsProvider);
      ref.invalidate(mealCalorieSummaryProvider);
      // Home-screen widget reflects today's kcal — refresh on save so the
      // user sees the new total without waiting for the OS scheduler.
      unawaited(ref.read(homeWidgetServiceProvider).refresh(userId: userId));

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final savedMsg = context.l10n.mealSavedToast;
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(savedMsg),
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

  Future<void> _shareMeal() async {
    final result = _result;
    if (result == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final image = MemoryImage(widget.imageBytes);
      await precacheImage(image, context);
      if (!mounted) return;

      final n = result.nutriments.scaled(_portionMultiplier);
      final cals = (n.energyKcal ?? 0).round();
      final card = MealShareCard(
        image: image,
        foodName: result.foodName,
        calories: cals,
        protein: (n.proteins ?? 0).round(),
        carbs: (n.carbohydrates ?? 0).round(),
        fat: (n.fat ?? 0).round(),
        portionGrams: (result.portionGrams * _portionMultiplier).round(),
        footer: l10n.shareCalculatedWith,
      );
      final caption = ShareCaption.forMeal(
        foodName: result.foodName,
        calories: cals,
        calculatedLabel: l10n.shareCalculatedWith,
        storeUrl: AppLinks.shareStoreUrl,
      );

      await ref.read(shareServiceProvider).captureAndShare(
        context: context,
        card: card,
        logicalSize: const Size(360, 360),
        pixelRatio: 3.0,
        fileName: 'nutrilens_meal_${DateTime.now().millisecondsSinceEpoch}.png',
        caption: caption,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
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
        actions: [
          if (!_loading && _error == null && _result != null)
            IconButton(
              tooltip: l10n.share,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _shareMeal,
            ),
        ],
      ),
      body: _loading
          ? _buildLoading(l10n, colors)
          : _error != null
          ? _buildError(l10n, colors)
          : _buildResult(l10n, colors),
    );
  }

  /// Loading view: shows the captured photo with a scanning-line animation
  /// sweeping vertically — gives the user concrete visual feedback that
  /// the image is being processed instead of a generic spinner.
  Widget _buildLoading(dynamic l10n, AppColorsExtension colors) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _ScanningPhoto(imageBytes: widget.imageBytes),
              ),
            ),
          ),
          const SizedBox(height: 32),
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 16),
          Text(
            l10n.aiAnalyzing,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
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
    final message = _quotaExhausted
        ? l10n.aiQuotaExhausted
        : isServiceDown
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
    // All UI below renders the SCALED nutrients so the BentoGrid,
    // EditorialTable and HP-Score bar update live as the user picks a
    // portion-multiplier chip. Save path applies the same factor (see
    // _saveMeal).
    final nutriments = result.nutriments.scaled(_portionMultiplier);
    final hpScore = _estimateHpScore(result.nutriments);
    final scaledPortion = (result.portionGrams * _portionMultiplier).round();

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
                    decoration: InputDecoration(
                      labelText: l10n.mealNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _brandController,
                    decoration: InputDecoration(
                      labelText: l10n.mealSourceLabel,
                      border: const OutlineInputBorder(),
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
                  '${l10n.aiEstimatedPortion}: ~${scaledPortion}g',
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
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.aiConfidenceHint,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: colors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _PortionMultiplierSelector(
              value: _portionMultiplier,
              onChanged: (v) => setState(() => _portionMultiplier = v),
              colors: colors,
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.estimatedContent,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _ingredientsController,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.textSecondary,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.editIngredientsHint,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.portionNoteLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _portionNoteController,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.portionNoteHint,
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12.5,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _recalcLoading ? null : _recalculateNutrition,
                    icon: _recalcLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.recalculate),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.recalcHint,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textMuted,
                    height: 1.4,
                  ),
                ),
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
                    label: Text(l10n.saveToMeals),
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

/// Meal photo with a scanning-line overlay. The line sweeps from top to
/// bottom (and back) while AI analysis is in flight. A soft tint band
/// trails behind the line so the effect reads even on low-contrast
/// photos. Stops automatically when the widget is disposed.
class _ScanningPhoto extends StatefulWidget {
  final Uint8List imageBytes;

  const _ScanningPhoto({required this.imageBytes});

  @override
  State<_ScanningPhoto> createState() => _ScanningPhotoState();
}

class _ScanningPhotoState extends State<_ScanningPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(widget.imageBytes, fit: BoxFit.cover),
        // Subtle dim so the scan line stays readable.
        Container(color: Colors.black.withValues(alpha: 0.18)),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ScanLinePainter(
                progress: _controller.value,
                color: colors.primary,
              ),
            );
          },
        ),
        // Viewfinder corner accents — completes the "scanning" feel.
        IgnorePointer(
          child: CustomPaint(
            painter: _ViewfinderCornersPainter(color: colors.primary),
          ),
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 12.0;
    final top = inset;
    final bottom = size.height - inset;
    final y = top + (bottom - top) * progress;

    // Trailing gradient band behind the line for a glow effect.
    final bandHeight = size.height * 0.18;
    final bandTop = y - bandHeight;
    final bandRect = Rect.fromLTWH(
      inset,
      bandTop,
      size.width - inset * 2,
      bandHeight,
    );
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.22)],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);

    // The line itself.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress || old.color != color;
}

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;

  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pad = 12.0;
    final len = size.shortestSide * 0.10;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(len * dx, 0), p);
      canvas.drawLine(origin, origin.translate(0, len * dy), p);
    }

    corner(Offset(pad, pad), 1, 1);
    corner(Offset(size.width - pad, pad), -1, 1);
    corner(Offset(pad, size.height - pad), 1, -1);
    corner(Offset(size.width - pad, size.height - pad), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter old) =>
      old.color != color;
}

/// Four-chip portion selector shown below the AI's portion badge.
/// Lets the user say "AI guessed roughly right, but I ate
/// half / 1.5× / twice as much" without having to write a free-form
/// portion note. The multiplier scales both the visible nutrition
/// preview and the values that ultimately land in the meal_entries
/// row. 1× is the default; the chip with the matching value renders
/// filled with the brand gradient.
class _PortionMultiplierSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final AppColorsExtension colors;

  const _PortionMultiplierSelector({
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  static const _options = <_PortionOption>[
    _PortionOption(value: 0.5, emoji: '🥄', sub: '½'),
    _PortionOption(value: 1.0, emoji: '🍽', sub: '1×'),
    _PortionOption(value: 1.5, emoji: '🍴', sub: '1½×'),
    _PortionOption(value: 2.0, emoji: '🍛', sub: '2×'),
  ];

  String _label(BuildContext context, double value) {
    final l10n = context.l10n;
    if (value <= 0.5) return l10n.portionLittle;
    if (value <= 1.0) return l10n.portionNormal;
    if (value <= 1.5) return l10n.portionLots;
    return l10n.portionTwoServings;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.portionQuestion,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final opt in _options) ...[
              Expanded(child: _chip(context, opt)),
              if (opt != _options.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, _PortionOption opt) {
    final selected = (value - opt.value).abs() < 0.001;
    return GestureDetector(
      onTap: () => onChanged(opt.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? colors.primaryGradient : null,
          color: selected ? null : colors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : colors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(opt.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(
              _label(context, opt.value),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : colors.textPrimary,
              ),
            ),
            Text(
              opt.sub,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? Colors.black.withValues(alpha: 0.6)
                    : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortionOption {
  final double value;
  final String emoji;
  final String sub;
  const _PortionOption({
    required this.value,
    required this.emoji,
    required this.sub,
  });
}
