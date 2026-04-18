import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/ocr_provider.dart';
import '../providers/product_provider.dart';

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
      final ocrService = ref.read(ocrServiceProvider);
      final geminiService = ref.read(geminiAiServiceProvider);

      // 1) Try Gemini vision first — it handles curved, rotated, glossy,
      //    multi-language labels far better than ML Kit's plain OCR.
      //    Normalize EXIF orientation: some Android cameras save bytes
      //    unrotated with only an orientation flag, which Gemini sometimes
      //    ignores — resulting in 90°-rotated input.
      final rawBytes = await File(image.path).readAsBytes();
      final imageBytes = await _normalizeOrientation(rawBytes);
      String? ingredientsText =
          await geminiService.extractIngredientsFromImage(imageBytes);

      // 2) Fall back to ML Kit only if Gemini failed (network error,
      //    rate limit, or couldn't see a Turkish ingredients list).
      String rawText;
      if (ingredientsText != null) {
        rawText = ingredientsText;
      } else {
        debugPrint(
          '[OCR] Gemini returned no ingredients — falling back to ML Kit',
        );
        rawText = await ocrService.extractText(image.path);
      }

      final result = await ocrService.parseIngredients(rawText);

      if (!mounted) return;

      // If both Gemini AND ML Kit failed to find an ingredients header and no
      // additives were matched, the photo almost certainly missed the list.
      if (ingredientsText == null &&
          !result.headerFound &&
          result.detectedAdditives.isEmpty) {
        _showHeaderMissingDialog();
        return;
      }

      if (result.confidence < 0.1 && ingredientsText == null) {
        _showOcrFailedDialog();
        return;
      }

      // When Gemini supplied the text, prefer it as the cleaned/raw text.
      // It's already a clean list, not a raw OCR dump.
      final cleanedText =
          ingredientsText ?? result.cleanedText;

      // Merge product info from not-found screen with OCR result
      final extra = <String, dynamic>{
        'cleanedText': cleanedText,
        'rawText': rawText,
        'detectedAdditives': result.detectedAdditives,
        'unmatchedAdditives': result.unmatchedAdditives,
        'confidence': result.confidence,
        'imagePath': image.path,
        'usedGemini': ingredientsText != null,
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

  /// Bake EXIF orientation into the pixels and re-encode as JPEG.
  ///
  /// Android's image_picker often returns a JPEG whose pixel data is stored
  /// landscape regardless of how the phone was held, with only the EXIF
  /// Orientation tag indicating the intended rotation. Some downstream
  /// consumers — including Gemini — honour this flag inconsistently, which
  /// means a portrait photo may reach the model sideways and become
  /// unreadable. `bakeOrientation` applies the rotation to the actual
  /// pixels and strips the EXIF tag, giving us a predictable upright image.
  Future<Uint8List> _normalizeOrientation(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final upright = img.bakeOrientation(decoded);
      // Downscale very large images — Gemini does not need more than ~1600px
      // on the long edge for legible package text, and smaller payloads
      // round-trip faster.
      final longestSide =
          upright.width > upright.height ? upright.width : upright.height;
      final resized = longestSide > 1600
          ? img.copyResize(
              upright,
              width: upright.width >= upright.height ? 1600 : null,
              height: upright.height > upright.width ? 1600 : null,
              interpolation: img.Interpolation.cubic,
            )
          : upright;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
    } catch (e) {
      debugPrint('[OCR] orientation normalize failed: $e');
      return bytes;
    }
  }

  void _showHeaderMissingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surfaceCard,
        title: Text(
          'İçindekiler Bölümü Bulunamadı',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'Fotoğrafta "İçindekiler:" yazan bölüm okunamadı. Lütfen:\n\n'
          '• Paketi düz tutun (yazılar yatay olsun)\n'
          '• İçindekiler yazan kısmı ortalayın\n'
          '• Işık yansımasından kaçının\n'
          '• Yazı net ve okunabilir mesafede olsun',
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
              'Manuel Gir',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _takePicture();
            },
            child: Text(
              'Tekrar Çek',
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
          'Metin Okunamadı',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'İçindekiler listesi okunamadı. Lütfen daha yakın ve net bir fotoğraf çekin.',
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
              'Manuel Gir',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _takePicture();
            },
            child: Text(
              'Tekrar Çek',
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
        title: const Text('İçindekiler Fotoğrafı'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'İçindekiler analiz ediliyor...',
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
                      'İçindekiler listesinin fotoğrafını çekin',
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
                            text: 'Paketi düz tutun, yazılar yatay olsun',
                          ),
                          const SizedBox(height: 10),
                          _TipRow(
                            icon: Icons.center_focus_strong_outlined,
                            text: '"İçindekiler" yazan bölümü ortalayın',
                          ),
                          const SizedBox(height: 10),
                          _TipRow(
                            icon: Icons.wb_sunny_outlined,
                            text: 'Parlama/yansımadan kaçının',
                          ),
                          const SizedBox(height: 10),
                          _TipRow(
                            icon: Icons.zoom_in,
                            text: 'Yazılar net okunabilsin — yakınlaşın',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: context.colors.primaryGradient,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_rounded,
                                color: Colors.black, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Fotoğraf Çek',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
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
            style: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
