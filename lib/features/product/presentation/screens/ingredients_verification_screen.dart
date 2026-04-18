import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/hp_score_calculator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';
import '../widgets/additive_chip.dart';
import '../widgets/chemical_load_gauge.dart';

class IngredientsVerificationScreen extends ConsumerStatefulWidget {
  final String barcode;
  final Map<String, dynamic>? extra;

  const IngredientsVerificationScreen({
    super.key,
    required this.barcode,
    this.extra,
  });

  @override
  ConsumerState<IngredientsVerificationScreen> createState() =>
      _IngredientsVerificationScreenState();
}

class _IngredientsVerificationScreenState
    extends ConsumerState<IngredientsVerificationScreen> {
  late TextEditingController _ingredientsController;
  late TextEditingController _productNameController;
  late TextEditingController _brandController;
  late List<String> _detectedAdditives;
  late List<String> _unmatchedAdditives;
  double? _confidence;
  String? _rawOcrText;
  bool _showRawOcr = false;
  HpScoreResult? _scoreResult;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final extra = widget.extra ?? {};
    _ingredientsController = TextEditingController(
      text: extra['cleanedText'] as String? ?? '',
    );
    _rawOcrText = extra['rawText'] as String?;
    _productNameController = TextEditingController(
      text: extra['productName'] as String? ?? '',
    );
    _brandController = TextEditingController(
      text: extra['brand'] as String? ?? '',
    );
    _detectedAdditives =
        List<String>.from(extra['detectedAdditives'] as List? ?? []);
    _unmatchedAdditives =
        List<String>.from(extra['unmatchedAdditives'] as List? ?? []);
    _confidence = extra['confidence'] as double?;

    // Calculate score after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateScore());
  }

  @override
  void dispose() {
    _ingredientsController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _calculateScore() async {
    final calculator = ref.read(hpScoreCalculatorProvider);
    final allAdditives = [..._detectedAdditives, ..._unmatchedAdditives];

    final result = await calculator.calculatePartial(
      additivesTags: allAdditives,
    );

    setState(() => _scoreResult = result);
  }

  Future<void> _saveProduct() async {
    setState(() => _isSaving = true);

    try {
      final allAdditives = [..._detectedAdditives, ..._unmatchedAdditives];
      final product = ProductEntity(
        barcode: widget.barcode,
        productName: _productNameController.text.isNotEmpty
            ? _productNameController.text
            : null,
        brands:
            _brandController.text.isNotEmpty ? _brandController.text : null,
        ingredientsText: _ingredientsController.text,
        additivesTags: allAdditives,
        hpScore: _scoreResult?.hpScore,
        hpChemicalLoad: _scoreResult?.chemicalLoad,
        hpRiskFactor: _scoreResult?.riskFactor,
        hpNutriFactor: _scoreResult?.nutriFactor,
      );

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final submitUseCase = ref.read(submitCommunityProductUseCaseProvider);
      await submitUseCase(
        product: product,
        userId: userId,
        source: 'ocr',
      );

      if (!mounted) return;

      // Invalidate the product provider to reflect new data
      ref.invalidate(productByBarcodeProvider(widget.barcode));

      // Navigate to product detail
      context.go('/product/${widget.barcode}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bu ürünü veritabanımıza eklediniz!'),
          backgroundColor: context.colors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('İçerik Doğrulama'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name & brand
            TextField(
              controller: _productNameController,
              decoration: InputDecoration(
                labelText: 'Ürün Adı',
                labelStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandController,
              decoration: InputDecoration(
                labelText: 'Marka',
                labelStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Ingredients text (editable)
            Text(
              'İçindekiler Metni',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'OCR ile okunan içindekiler metni...',
                hintStyle: TextStyle(color: context.colors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textPrimary,
              ),
            ),
            if (_rawOcrText != null && _rawOcrText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showRawOcr = !_showRawOcr),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showRawOcr
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: context.colors.textMuted,
                    ),
                    Text(
                      _showRawOcr
                          ? 'Ham OCR metnini gizle'
                          : 'Ham OCR metnini göster',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showRawOcr) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: SelectableText(
                    _rawOcrText!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: context.colors.textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),

            // Detected additives
            if (_detectedAdditives.isNotEmpty) ...[
              Text(
                'Tespit Edilen Katkı Maddeleri',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _detectedAdditives
                    .map((code) => AdditiveChip(
                          eCode: code,
                          riskLevel: 3, // Will be resolved from DB at runtime
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Unmatched additives
            if (_unmatchedAdditives.isNotEmpty) ...[
              Text(
                'Veritabanında Bulunamayan E Kodları',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.warning,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _unmatchedAdditives
                    .map((code) => AdditiveChip(
                          eCode: code,
                          riskLevel: 3, // Default moderate
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Chemical load gauge
            if (_scoreResult != null) ...[
              ChemicalLoadGauge(
                chemicalLoad: _scoreResult!.chemicalLoad,
                isPartial: true,
              ),
              const SizedBox(height: 16),
            ],

            // Confidence indicator
            if (_confidence != null)
              Text(
                'OCR Güvenilirlik: ${(_confidence! * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textMuted,
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                // Retake photo
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go('/product/${widget.barcode}/ocr'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceCard,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: context.colors.textPrimary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tekrar Çek',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Save
                Expanded(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _saveProduct,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: context.colors.primaryGradient,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSaving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          else ...[
                            const Icon(Icons.check_rounded,
                                color: Colors.black, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Onayla ve Kaydet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
