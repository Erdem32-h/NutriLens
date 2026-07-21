import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart'
    show deviceIdServiceProvider;
import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/ocr_image_prep.dart';
import '../providers/ocr_provider.dart';
import '../providers/product_provider.dart';
import '../../../../core/widgets/app_button.dart';

/// First-save ingredients capture flow.
///
/// **Gemini-only**: ML Kit fallback was removed deliberately. When Gemini's
/// vision OCR can't read the ingredients (or the service is down), we surface
/// a clear "retry / enter manually" dialog instead of silently substituting
/// a less-accurate ML Kit result that often picks up the producer address.
class IngredientsCameraScreen extends ConsumerStatefulWidget {
  final String barcode;
  final Map<String, dynamic>? productInfo;

  const IngredientsCameraScreen({
    super.key,
    required this.barcode,
    this.productInfo,
  });

  @override
  ConsumerState<IngredientsCameraScreen> createState() =>
      _IngredientsCameraScreenState();
}

class _IngredientsCameraScreenState
    extends ConsumerState<IngredientsCameraScreen> {
  final _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Auto-launch camera on enter
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePicture());
  }

  Future<void> _takePicture() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 100, // OCR needs maximum clarity — small ingredient text
    );

    if (image == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final geminiService = ref.read(geminiAiServiceProvider);

      // Gemini vision is the only OCR path. It handles curved, rotated,
      // glossy, multi-language labels far better than ML Kit's plain OCR
      // and avoids the failure mode where ML Kit substitutes the producer
      // address when the ingredients section is missed.
      //
      // EXIF orientation baking + downscale + base64 encode all happen on a
      // worker isolate via [prepareOcrImage]. Doing this synchronously on
      // the main isolate blocks the UI long enough on a 12 MP capture to
      // trigger Android's "App not responding" dialog.
      final rawBytes = await File(image.path).readAsBytes();
      final prepared = await prepareOcrImage(rawBytes);
      final deviceHash = await ref.read(deviceIdServiceProvider).deviceHash();

      final String? ingredientsText;
      try {
        ingredientsText = await geminiService.extractIngredientsFromBase64(
          prepared.base64,
          deviceHash: deviceHash,
        );
      } on GeminiServiceException catch (e) {
        // Service-level failure (auth, network, rate limit). No fallback —
        // ask the user to retry or enter manually.
        debugPrint('[OCR] Gemini service failure: $e');
        if (mounted) _showAiServiceDownDialog();
        return;
      }

      if (!mounted) return;

      // Gemini ran but couldn't read an ingredients list (sentinel returned).
      // Almost always means the photo missed the section, was too far away,
      // or showed only the address/nutrition side of the package.
      if (ingredientsText == null) {
        _showHeaderMissingDialog();
        return;
      }

      // Parse for additive detection (E-codes + Turkish name matching).
      // The Gemini text is already clean; parseIngredients runs E-code and
      // additive-name regex over it for the verify screen.
      final ocrService = ref.read(ocrServiceProvider);
      final result = await ocrService.parseIngredients(ingredientsText);

      if (!mounted) return;

      final extra = <String, dynamic>{
        'cleanedText': ingredientsText,
        'rawText': ingredientsText,
        'detectedAdditives': result.detectedAdditives,
        'unmatchedAdditives': result.unmatchedAdditives,
        'confidence': result.confidence,
        'imagePath': image.path,
        // Carry forward product info from not-found screen
        if (widget.productInfo != null) ...widget.productInfo!,
      };

      context.go('/product/${widget.barcode}/verify', extra: extra);
    } catch (e) {
      debugPrint('[OCR] pipeline error: $e');
      if (mounted) _showOcrFailedDialog();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Shown when the Gemini service itself failed (network/auth/rate limit).
  /// Without an ML Kit fallback there's nothing we can do automatically, so
  /// give the user a clear retry/manual choice.
  void _showAiServiceDownDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceCard,
        icon: Icon(
          Icons.cloud_off_rounded,
          color: const Color(0xFFFF9800),
          size: 36,
        ),
        title: Text(
          context.l10n.aiServiceDownTitle,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          context.l10n.aiServiceDownBody,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(
                '/product/${widget.barcode}/manual',
                extra: widget.productInfo,
              );
            },
            child: Text(
              context.l10n.manualEntry,
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _takePicture();
            },
            child: Text(
              context.l10n.tryAgain,
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showHeaderMissingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceCard,
        title: Text(
          context.l10n.ingredientsSectionNotFound,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          context.l10n.ingredientsSectionNotFoundBody,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(
                '/product/${widget.barcode}/manual',
                extra: widget.productInfo,
              );
            },
            child: Text(
              context.l10n.manualEntry,
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _takePicture();
            },
            child: Text(
              context.l10n.retakePhoto,
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showOcrFailedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceCard,
        title: Text(
          context.l10n.textUnreadable,
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          context.l10n.textUnreadableBody,
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(
                '/product/${widget.barcode}/manual',
                extra: widget.productInfo,
              );
            },
            child: Text(
              context.l10n.manualEntry,
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _takePicture();
            },
            child: Text(
              context.l10n.retakePhoto,
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(context.l10n.ingredientsPhotoTitle),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: context.colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.analyzingIngredients,
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.photographIngredientsList,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TipRow(
                            icon: Icons.screen_rotation_outlined,
                            text: context.l10n.tipHoldFlat,
                          ),
                          const SizedBox(height: 10),
                          _TipRow(
                            icon: Icons.center_focus_strong_outlined,
                            text: context.l10n.tipCenterIngredients,
                          ),
                          const SizedBox(height: 10),
                          _TipRow(
                            icon: Icons.wb_sunny_outlined,
                            text: context.l10n.tipAvoidGlare,
                          ),
                          const SizedBox(height: 10),
                          _TipRow(
                            icon: Icons.zoom_in,
                            text: context.l10n.tipZoomIn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: context.l10n.takePhoto,
                      icon: Icons.camera_alt_rounded,
                      expand: false,
                      onPressed: _takePicture,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
