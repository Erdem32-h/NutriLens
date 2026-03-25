import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/extensions/l10n_extension.dart';
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
        error: (_, __) {
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
                          errorBuilder: (_, __, ___) =>
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _showMessage(l10n.saveFailed);
        return;
      }

      // Upload image if selected
      String? imageUrl = _existingProduct?.imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(userId);
      }

      // Build updated product
      final updatedProduct = ProductEntity(
        barcode: widget.barcode,
        productName:
            _nameController.text.isNotEmpty ? _nameController.text : null,
        brands:
            _brandController.text.isNotEmpty ? _brandController.text : null,
        imageUrl: imageUrl,
        ingredientsText: _ingredientsController.text.isNotEmpty
            ? _ingredientsController.text
            : null,
        allergensTags: _existingProduct?.allergensTags ?? const [],
        additivesTags: _existingProduct?.additivesTags ?? const [],
        novaGroup: _existingProduct?.novaGroup,
        nutriscoreGrade: _existingProduct?.nutriscoreGrade,
        nutriments: NutrimentsEntity(
          energyKcal: _parseDouble(_energyController.text),
          fat: _parseDouble(_fatController.text),
          saturatedFat: _parseDouble(_saturatedFatController.text),
          sugars: _parseDouble(_sugarsController.text),
          salt: _parseDouble(_saltController.text),
          fiber: _parseDouble(_fiberController.text),
          proteins: _parseDouble(_proteinController.text),
        ),
        categoriesTags: _existingProduct?.categoriesTags ?? const [],
        countriesTags: _existingProduct?.countriesTags ?? const [],
        hpScore: _existingProduct?.hpScore,
        hpChemicalLoad: _existingProduct?.hpChemicalLoad,
        hpRiskFactor: _existingProduct?.hpRiskFactor,
        hpNutriFactor: _existingProduct?.hpNutriFactor,
      );

      // Save to community_products via CommunityProductSource
      final communitySource = ref.read(communityProductSourceProvider);
      await communitySource.addProduct(
        product: updatedProduct,
        userId: userId,
        source: _isNewProduct ? 'user_created' : 'user_edit',
      );

      // Also update local cache
      final localDS = ref.read(productLocalDataSourceProvider);
      await localDS.cacheProduct(updatedProduct);

      // Invalidate the product provider to refresh data
      ref.invalidate(productByBarcodeProvider(widget.barcode));

      if (!mounted) return;
      _showMessage(l10n.savedSuccessfully);

      // Navigate to product detail (replace edit screen in stack)
      context.pushReplacement('/product/${widget.barcode}');
    } catch (e) {
      if (!mounted) return;
      _showMessage(l10n.saveFailed);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;

    try {
      final ext = _selectedImage!.path.split('.').last;
      final path = 'products/${widget.barcode}_$userId.$ext';

      await Supabase.instance.client.storage
          .from('product-images')
          .upload(path, _selectedImage!,
              fileOptions: const FileOptions(upsert: true));

      return Supabase.instance.client.storage
          .from('product-images')
          .getPublicUrl(path);
    } catch (_) {
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
