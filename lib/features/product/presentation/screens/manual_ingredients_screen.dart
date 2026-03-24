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

class ManualIngredientsScreen extends ConsumerStatefulWidget {
  final String barcode;

  const ManualIngredientsScreen({super.key, required this.barcode});

  @override
  ConsumerState<ManualIngredientsScreen> createState() =>
      _ManualIngredientsScreenState();
}

class _ManualIngredientsScreenState
    extends ConsumerState<ManualIngredientsScreen> {
  final _ingredientsController = TextEditingController();
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _eCodeController = TextEditingController();

  final _manualECodes = <String>[];
  HpScoreResult? _scoreResult;
  bool _isSaving = false;

  @override
  void dispose() {
    _ingredientsController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    _eCodeController.dispose();
    super.dispose();
  }

  void _addECode() {
    final code = _eCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    // Validate E-code format
    final normalized = HpScoreCalculator.normalizeECode(code);
    if (!RegExp(r'^E\d{3,4}[a-z]?$', caseSensitive: false)
        .hasMatch(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Geçersiz E kodu formatı (örn: E471)'),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    if (!_manualECodes.contains(normalized)) {
      setState(() {
        _manualECodes.add(normalized);
        _eCodeController.clear();
      });
      _calculateScore();
    }
  }

  void _removeECode(String code) {
    setState(() => _manualECodes.remove(code));
    _calculateScore();
  }

  Future<void> _calculateScore() async {
    if (_manualECodes.isEmpty) {
      setState(() => _scoreResult = null);
      return;
    }

    final calculator = ref.read(hpScoreCalculatorProvider);
    final result = await calculator.calculatePartial(
      additivesTags: _manualECodes,
    );
    setState(() => _scoreResult = result);
  }

  Future<void> _saveProduct() async {
    setState(() => _isSaving = true);

    try {
      final product = ProductEntity(
        barcode: widget.barcode,
        productName: _productNameController.text.isNotEmpty
            ? _productNameController.text
            : null,
        brands:
            _brandController.text.isNotEmpty ? _brandController.text : null,
        ingredientsText: _ingredientsController.text.isNotEmpty
            ? _ingredientsController.text
            : null,
        additivesTags: _manualECodes,
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
        source: 'community',
      );

      if (!mounted) return;

      ref.invalidate(productByBarcodeProvider(widget.barcode));
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
        title: const Text('Manuel Giriş'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
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

            // Brand
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

            // Ingredients text
            Text(
              'İçindekiler Metni (opsiyonel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'İçindekiler listesini buraya yapıştırın...',
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
            const SizedBox(height: 16),

            // E-code input
            Text(
              'Katkı Maddeleri (E Kodları)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _eCodeController,
                    decoration: InputDecoration(
                      hintText: 'E471',
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
                    style: TextStyle(color: context.colors.textPrimary),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _addECode(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addECode,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: context.colors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // E-code chips
            if (_manualECodes.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _manualECodes.map((code) {
                  return GestureDetector(
                    onTap: () => _removeECode(code),
                    child: AdditiveChip(
                      eCode: code,
                      riskLevel: 3,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Kaldırmak için dokunun',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Score gauge
            if (_scoreResult != null) ...[
              ChemicalLoadGauge(
                chemicalLoad: _scoreResult!.chemicalLoad,
                isPartial: true,
              ),
              const SizedBox(height: 16),
            ],

            // Save button
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isSaving ? null : _saveProduct,
              child: Container(
                width: double.infinity,
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
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
