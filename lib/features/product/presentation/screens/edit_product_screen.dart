import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/ocr_text_processor.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/nutriments_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final String barcode;

  const EditProductScreen({super.key, required this.barcode});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _ingredientsController;
  late TextEditingController _energyController;
  late TextEditingController _fatController;
  late TextEditingController _saturatedFatController;
  late TextEditingController _sugarsController;
  late TextEditingController _saltController;
  late TextEditingController _fiberController;
  late TextEditingController _proteinController;

  File? _selectedImage;
  bool _saving = false;
  bool _ocrProcessing = false;
  ProductEntity? _existingProduct;
  bool _isNewProduct = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _brandController = TextEditingController();
    _ingredientsController = TextEditingController();
    _energyController = TextEditingController();
    _fatController = TextEditingController();
    _saturatedFatController = TextEditingController();
    _sugarsController = TextEditingController();
    _saltController = TextEditingController();
    _fiberController = TextEditingController();
    _proteinController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _ingredientsController.dispose();
    _energyController.dispose();
    _fatController.dispose();
    _saturatedFatController.dispose();
    _sugarsController.dispose();
    _saltController.dispose();
    _fiberController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  void _populateFromProduct(ProductEntity product) {
    if (_existingProduct != null) return;
    _existingProduct = product;
    _nameController.text = product.productName ?? '';
    _brandController.text = product.brands ?? '';
    _ingredientsController.text = product.ingredientsText ?? '';
    _energyController.text = product.nutriments.energyKcal?.toString() ?? '';
    _fatController.text = product.nutriments.fat?.toString() ?? '';
    _saturatedFatController.text =
        product.nutriments.saturatedFat?.toString() ?? '';
    _sugarsController.text = product.nutriments.sugars?.toString() ?? '';
    _saltController.text = product.nutriments.salt?.toString() ?? '';
    _fiberController.text = product.nutriments.fiber?.toString() ?? '';
    _proteinController.text = product.nutriments.proteins?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final productAsync = ref.watch(productByBarcodeProvider(widget.barcode));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.editProduct),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.primary,
                    ),
                  )
                : Text(
                    l10n.saveChanges,
                    style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: productAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (_, _) {
          // Error loading = treat as new product
          _isNewProduct = true;
          return _buildForm(context, null);
        },
        data: (product) {
          if (product != null) {
            _populateFromProduct(product);
          } else {
            _isNewProduct = true;
          }
          return _buildForm(context, product);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, ProductEntity? product) {
    final l10n = context.l10n;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info banner for new product or missing info
          if (_isNewProduct)
            _buildInfoBanner(
              context,
              icon: Icons.add_circle_outline_rounded,
              color: context.colors.primary,
              bgColor: context.colors.primary.withValues(alpha: 0.08),
              text: l10n.newProductHint,
            )
          else if (_hasMissingInfo(product))
            _buildInfoBanner(
              context,
              icon: Icons.info_outline_rounded,
              color: const Color(0xFFFF9800),
              bgColor: const Color(0xFFFFF3E0),
              text: l10n.completeProductInfo,
            ),

          const SizedBox(height: 8),

          // Barcode display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_rounded,
                    size: 20, color: context.colors.textMuted),
                const SizedBox(width: 10),
                Text(
                  '${l10n.barcode}: ${widget.barcode}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Product Photo
          _buildPhotoSection(context),
          const SizedBox(height: 24),

          // Product Name (required)
          _buildTextField(
            controller: _nameController,
            label: '${l10n.productName} *',
            icon: Icons.label_outline_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.fieldRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Brand (required)
          _buildTextField(
            controller: _brandController,
            label: '${l10n.brandName} *',
            icon: Icons.business_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.fieldRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Ingredients (required)
          _buildTextField(
            controller: _ingredientsController,
            label: '${l10n.ingredientsTextLabel} *',
            icon: Icons.list_alt_rounded,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.fieldRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // OCR Scan Ingredients button
          _buildOcrButton(
            context,
            label: l10n.scanIngredients,
            icon: Icons.document_scanner_rounded,
            onTap: () => _scanWithOcr(_OcrTarget.ingredients),
          ),
          const SizedBox(height: 24),

          // Nutrition Section Header
          Text(
            l10n.nutritionFacts,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '(${l10n.portion100g})',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // OCR Scan Nutrition button
          _buildOcrButton(
            context,
            label: l10n.scanNutrition,
            icon: Icons.document_scanner_rounded,
            onTap: () => _scanWithOcr(_OcrTarget.nutrition),
          ),
          const SizedBox(height: 16),

          // Nutrition Fields - 2 columns
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _energyController,
                  label: '${l10n.energyValue} *',
                  suffix: 'kcal',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.fieldRequired;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _fatController,
                  label: l10n.fatLabel,
                  suffix: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _saturatedFatController,
                  label: l10n.saturatedFatLabel,
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _sugarsController,
                  label: l10n.sugarLabel,
                  suffix: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _saltController,
                  label: l10n.saltLabel,
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _fiberController,
                  label: l10n.fiberLabel,
                  suffix: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _proteinController,
                  label: l10n.proteinLabel,
                  suffix: 'g',
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 32),

          // Save button
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _saving ? null : context.colors.primaryGradient,
                color: _saving ? context.colors.surfaceCard2 : null,
                borderRadius: BorderRadius.circular(50),
              ),
              child: _saving
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.saveAndView,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── OCR ──────────────────────────────────────────────────────────────

  Widget _buildOcrButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _ocrProcessing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_ocrProcessing)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.primary,
                ),
              )
            else
              Icon(icon, size: 20, color: context.colors.primary),
            const SizedBox(width: 10),
            Text(
              _ocrProcessing ? context.l10n.ocrProcessing : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanWithOcr(_OcrTarget target) async {
    final l10n = context.l10n;

    // Pick image from camera or gallery
    final source = await _showOcrSourcePicker();
    if (source == null) return;

    XFile? xFile;
    try {
      xFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
    } catch (_) {
      return;
    }
    if (xFile == null) return;

    setState(() => _ocrProcessing = true);

    try {
      final inputImage = InputImage.fromFilePath(xFile.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;

      if (recognizedText.text.trim().isEmpty) {
        _showMessage(l10n.ocrNoText);
        return;
      }

      // Process with multi-language support and artifact cleanup
      const processor = OcrTextProcessor();

      switch (target) {
        case _OcrTarget.ingredients:
          final mlKitResult = processor.processIngredients(recognizedText);
          if (mlKitResult.text.isEmpty) {
            _showMessage(l10n.ocrNoText);
            return;
          }

          // Try AI improvement (silent — fallback to ML Kit result on failure)
          final aiService = ref.read(geminiAiServiceProvider);
          final aiImproved =
              await aiService.improveIngredientsOcr(mlKitResult.text);

          setState(() {
            _ingredientsController.text = aiImproved ?? mlKitResult.text;
          });
          debugPrint('[OCR] ingredients ai=${aiImproved != null}, '
              'lang=${mlKitResult.language}');
          _showMessage(l10n.ocrSuccess);

        case _OcrTarget.nutrition:
          final mlKitResult = processor.processNutrition(recognizedText);
          if (mlKitResult.text.isEmpty) {
            _showMessage(l10n.ocrNoText);
            return;
          }

          // Try AI improvement for structured data
          final aiService = ref.read(geminiAiServiceProvider);
          final aiResult =
              await aiService.improveNutritionOcr(mlKitResult.text);

          if (aiResult != null) {
            // AI returned structured data — fill fields directly
            setState(() {
              if (aiResult.energyKcal != null &&
                  _energyController.text.isEmpty) {
                _energyController.text =
                    aiResult.energyKcal!.toStringAsFixed(1);
              }
              if (aiResult.fat != null && _fatController.text.isEmpty) {
                _fatController.text = aiResult.fat!.toStringAsFixed(1);
              }
              if (aiResult.saturatedFat != null &&
                  _saturatedFatController.text.isEmpty) {
                _saturatedFatController.text =
                    aiResult.saturatedFat!.toStringAsFixed(1);
              }
              if (aiResult.sugars != null && _sugarsController.text.isEmpty) {
                _sugarsController.text = aiResult.sugars!.toStringAsFixed(1);
              }
              if (aiResult.salt != null && _saltController.text.isEmpty) {
                _saltController.text = aiResult.salt!.toStringAsFixed(3);
              }
              if (aiResult.fiber != null && _fiberController.text.isEmpty) {
                _fiberController.text = aiResult.fiber!.toStringAsFixed(1);
              }
              if (aiResult.protein != null && _proteinController.text.isEmpty) {
                _proteinController.text =
                    aiResult.protein!.toStringAsFixed(1);
              }
            });
          } else {
            // AI failed — fallback to regex-based parsing
            _parseNutritionFromOcr(mlKitResult.text);
          }
          debugPrint('[OCR] nutrition ai=${aiResult != null}');
          _showMessage(l10n.ocrSuccess);
      }
    } catch (e) {
      debugPrint('[OCR] error: $e');
      if (mounted) _showMessage(l10n.ocrFailed);
    } finally {
      if (mounted) setState(() => _ocrProcessing = false);
    }
  }

  /// Parse OCR text to extract nutrition values and fill the fields.
  /// Handles both Turkish and English nutrition labels.
  /// Detects units (mg, mcg/µg) and converts to grams automatically.
  void _parseNutritionFromOcr(String text) {
    final lower = text.toLowerCase();

    // Helper: find a numeric value near a keyword.
    // Detects unit (g, mg, mcg, µg, kcal, kj) and converts to grams.
    // Returns the value in grams (or kcal for energy).
    String? findValue(List<String> keywords, {bool isEnergy = false}) {
      for (final keyword in keywords) {
        // Find all occurrences of the keyword
        int startIdx = 0;
        while (true) {
          final idx = lower.indexOf(keyword, startIdx);
          if (idx == -1) break;
          startIdx = idx + 1;

          // Look for numbers after the keyword within ~60 chars
          final searchEnd =
              (idx + keyword.length + 60).clamp(0, lower.length);
          final after = lower.substring(idx + keyword.length, searchEnd);

          // Match number + optional unit: "1500 mg", "3,5 g", "0.03g"
          final match = RegExp(
            r'(\d+[.,]?\d*)\s*(mg|mcg|µg|μg|g|kcal|kj)?',
          ).firstMatch(after);
          if (match != null) {
            final raw = match.group(1);
            final unit = match.group(2)?.toLowerCase();
            if (raw != null) {
              final normalized = raw.replaceAll(',', '.');
              var value = double.tryParse(normalized);
              if (value == null || value >= 10000) continue;

              // Convert units to grams (skip conversion for energy)
              if (!isEnergy && unit != null) {
                switch (unit) {
                  case 'mg':
                    value = value / 1000.0;
                  case 'mcg' || 'µg' || 'μg':
                    value = value / 1000000.0;
                  case 'g':
                    break; // already grams
                  default:
                    break;
                }
              }

              // For energy with kJ unit, convert to kcal (1 kcal ≈ 4.184 kJ)
              if (isEnergy && unit == 'kj') {
                value = value / 4.184;
              }

              // Return with appropriate precision
              if (value >= 1) {
                return value.toStringAsFixed(1);
              } else {
                return value.toStringAsFixed(3);
              }
            }
          }
        }
      }
      return null;
    }

    setState(() {
      // Energy (kcal) — Turkish labels often show kJ first, then kcal
      final energy = findValue([
        'kcal',
        'kalori',
        'enerji',
        'energy',
        'calories',
      ], isEnergy: true);
      if (energy != null && _energyController.text.isEmpty) {
        _energyController.text = energy;
      }

      // Total fat
      final fat = findValue([
        'toplam yağ',
        'total fat',
        'yağ',
        'fat',
      ]);
      if (fat != null && _fatController.text.isEmpty) {
        _fatController.text = fat;
      }

      // Saturated fat — search BEFORE total fat to avoid matching "fat" alone
      final saturated = findValue([
        'doymuş yağ',
        'doymuş',
        'of which saturates',
        'saturated fat',
        'saturated',
      ]);
      if (saturated != null && _saturatedFatController.text.isEmpty) {
        _saturatedFatController.text = saturated;
      }

      // Sugars
      final sugars = findValue([
        'şekerler',
        'şeker',
        'of which sugars',
        'sugars',
        'sugar',
      ]);
      if (sugars != null && _sugarsController.text.isEmpty) {
        _sugarsController.text = sugars;
      }

      // Salt / Sodium — convert sodium to salt if needed (salt = sodium * 2.5)
      // findValue already converts mg→g, so sodium value is in grams here
      final salt = findValue(['tuz', 'salt']);
      if (salt != null && _saltController.text.isEmpty) {
        _saltController.text = salt;
      } else if (_saltController.text.isEmpty) {
        final sodium = findValue(['sodyum', 'sodium']);
        if (sodium != null) {
          final sodiumVal = double.tryParse(sodium);
          if (sodiumVal != null) {
            // sodium is already in grams (mg→g converted by findValue)
            final saltVal = sodiumVal * 2.5;
            _saltController.text = saltVal >= 1
                ? saltVal.toStringAsFixed(1)
                : saltVal.toStringAsFixed(3);
          }
        }
      }

      // Fiber
      final fiber = findValue([
        'lif',
        'dietary fiber',
        'dietary fibre',
        'fiber',
        'fibre',
      ]);
      if (fiber != null && _fiberController.text.isEmpty) {
        _fiberController.text = fiber;
      }

      // Protein
      final protein = findValue(['protein', 'protei̇n']);
      if (protein != null && _proteinController.text.isEmpty) {
        _proteinController.text = protein;
      }
    });
  }

  Future<ImageSource?> _showOcrSourcePicker() async {
    final l10n = context.l10n;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded,
                    color: context.colors.primary),
                title: Text(l10n.takePhoto),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded,
                    color: context.colors.primary),
                title: Text(l10n.chooseFromGallery),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI Builders ─────────────────────────────────────────────────────

  Widget _buildInfoBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final l10n = context.l10n;
    final existingImageUrl = _existingProduct?.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.productPhoto,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.colors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.5),
                style: BorderStyle.solid,
              ),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : existingImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.network(
                          existingImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _buildPhotoPlaceholder(context),
                        ),
                      )
                    : _buildPhotoPlaceholder(context),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo_rounded,
          size: 40,
          color: context.colors.textMuted,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.takePhoto,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: maxLines == 1 ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: context.colors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: context.colors.border.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: context.colors.border.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: context.colors.textMuted),
        suffixText: suffix,
        suffixStyle: TextStyle(
          fontSize: 12,
          color: context.colors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: context.colors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: context.colors.border.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: context.colors.border.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  // ── Image Picker ────────────────────────────────────────────────────

  void _showImagePickerOptions() {
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded,
                    color: context.colors.primary),
                title: Text(l10n.takePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded,
                    color: context.colors.primary),
                title: Text(l10n.chooseFromGallery),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xFile != null) {
        setState(() {
          _selectedImage = File(xFile.path);
        });
      }
    } catch (_) {
      // Image picking cancelled or failed
    }
  }

  // ── Save ────────────────────────────────────────────────────────────

  bool _hasMissingInfo(ProductEntity? product) {
    if (product == null) return true;
    return !product.hasEssentialData;
  }

  double? _parseDouble(String text) {
    if (text.trim().isEmpty) return null;
    final normalized = text.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _save() async {
    final l10n = context.l10n;

    // Validate required fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      // Step 1: Auth check
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _showMessage(l10n.saveFailedAuth);
        return;
      }

      // Step 2: Upload product photo (optional, non-fatal)
      String? imageUrl = _existingProduct?.imageUrl;
      if (_selectedImage != null) {
        final uploadedPath = await _uploadImage(userId);
        if (uploadedPath != null) {
          imageUrl = uploadedPath;
        }
        // If uploadedPath is null, it failed. 
        // We log error but proceed with previous image or gracefully handle it.
      }

      // Step 3: Build nutriments and calculate HP Score
      final ingredientsText = _ingredientsController.text.isNotEmpty
          ? _ingredientsController.text
          : null;
      final nutriments = NutrimentsEntity(
        energyKcal: _parseDouble(_energyController.text),
        fat: _parseDouble(_fatController.text),
        saturatedFat: _parseDouble(_saturatedFatController.text),
        sugars: _parseDouble(_sugarsController.text),
        salt: _parseDouble(_saltController.text),
        fiber: _parseDouble(_fiberController.text),
        proteins: _parseDouble(_proteinController.text),
      );

      // Calculate HP Score with full data
      final calculator = ref.read(hpScoreCalculatorProvider);
      final hpResult = await calculator.calculateFull(
        additivesTags: _existingProduct?.additivesTags ?? const [],
        nutriments: nutriments,
        novaGroup: _existingProduct?.novaGroup,
        ingredientsText: ingredientsText,
      );

      final updatedProduct = ProductEntity(
        barcode: widget.barcode,
        productName:
            _nameController.text.isNotEmpty ? _nameController.text : null,
        brands:
            _brandController.text.isNotEmpty ? _brandController.text : null,
        imageUrl: imageUrl,
        ingredientsText: ingredientsText,
        allergensTags: _existingProduct?.allergensTags ?? const [],
        additivesTags: _existingProduct?.additivesTags ?? const [],
        novaGroup: _existingProduct?.novaGroup,
        nutriscoreGrade: _existingProduct?.nutriscoreGrade,
        nutriments: nutriments,
        categoriesTags: _existingProduct?.categoriesTags ?? const [],
        countriesTags: _existingProduct?.countriesTags ?? const [],
        hpScore: hpResult.hpScore,
        hpChemicalLoad: hpResult.chemicalLoad,
        hpRiskFactor: hpResult.riskFactor,
        hpNutriFactor: hpResult.nutriFactor,
      );

      // Step 4: Save to Supabase community_products
      try {
        final communitySource = ref.read(communityProductSourceProvider);
        await communitySource.addProduct(
          product: updatedProduct,
          userId: userId,
          source: _isNewProduct ? 'user_created' : 'user_edit',
        );
      } on SocketException {
        if (mounted) _showMessage(l10n.saveFailedNetwork);
        return;
      } catch (e) {
        debugPrint('[EditProduct] Supabase save error: $e');
        if (mounted) _showMessage(l10n.saveFailedDatabase);
        return;
      }

      // Step 5: Update local cache (non-fatal)
      try {
        final localDS = ref.read(productLocalDataSourceProvider);
        await localDS.cacheProduct(updatedProduct);
      } catch (_) {
        // Cache write failed — proceed without it
      }

      // Step 6: Invalidate and navigate
      ref.invalidate(productByBarcodeProvider(widget.barcode));

      if (!mounted) return;

      // Capture messenger BEFORE navigation disposes this Scaffold
      final messenger = ScaffoldMessenger.of(context);

      // Navigate first — pushReplacement disposes this screen
      context.pushReplacement('/product/${widget.barcode}');

      // Show success message on the NEW screen's scaffold via root messenger
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.savedSuccessfully),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return; // skip finally setState — screen is already disposed
    } catch (e) {
      debugPrint('[EditProduct] unexpected save error: $e');
      if (!mounted) return;
      if (e is SocketException) {
        _showMessage(l10n.saveFailedNetwork);
      } else {
        _showMessage(l10n.saveFailedDatabase);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;

    try {
      final fileSize = await _selectedImage!.length();
      debugPrint('[Upload] file: ${_selectedImage!.path}');
      debugPrint('[Upload] size: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(1)} KB)');

      final ext = _selectedImage!.path.split('.').last;
      final safeExt = (ext.length > 5 || ext.contains(RegExp(r'[^a-zA-Z0-9]')))
          ? 'jpg'
          : ext;
      debugPrint('[Upload] extension: "$ext" → "$safeExt"');

      final sanitizedBarcode =
          widget.barcode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final path = 'products/${sanitizedBarcode}_$userId.$safeExt';
      debugPrint('[Upload] storage path: "$path"');
      debugPrint('[Upload] barcode: "${widget.barcode}" → sanitized: "$sanitizedBarcode"');

      // Check file exists and is readable
      if (!await _selectedImage!.exists()) {
        debugPrint('[Upload] ERROR: file does not exist at path!');
        return null;
      }

      await Supabase.instance.client.storage
          .from('product-images')
          .upload(path, _selectedImage!,
              fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('product-images')
          .getPublicUrl(path);

      debugPrint('[Upload] SUCCESS → $publicUrl');
      return publicUrl;
    } catch (e, stack) {
      debugPrint('[Upload] ERROR: $e');
      debugPrint('[Upload] stack: $stack');
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

enum _OcrTarget { ingredients, nutrition }
