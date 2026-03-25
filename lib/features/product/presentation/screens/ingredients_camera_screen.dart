import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/ocr_provider.dart';

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
      imageQuality: 90,
    );

    if (image == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final rawText = await ocrService.extractText(image.path);
      final result = await ocrService.parseIngredients(rawText);

      if (!mounted) return;

      if (result.confidence < 0.1) {
        _showOcrFailedDialog();
        return;
      }

      // Merge product info from not-found screen with OCR result
      final extra = <String, dynamic>{
        'cleanedText': result.cleanedText,
        'detectedAdditives': result.detectedAdditives,
        'unmatchedAdditives': result.unmatchedAdditives,
        'confidence': result.confidence,
        'imagePath': image.path,
        // Carry forward product info from not-found screen
        if (widget.productInfo != null) ...widget.productInfo!,
      };

      context.go('/product/${widget.barcode}/verify', extra: extra);
    } catch (e) {
      if (mounted) _showOcrFailedDialog();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
            : Column(
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
                      color: context.colors.textSecondary,
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
    );
  }
}
