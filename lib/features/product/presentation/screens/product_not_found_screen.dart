import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

class ProductNotFoundScreen extends StatefulWidget {
  final String barcode;

  const ProductNotFoundScreen({super.key, required this.barcode});

  @override
  State<ProductNotFoundScreen> createState() => _ProductNotFoundScreenState();
}

class _ProductNotFoundScreenState extends State<ProductNotFoundScreen> {
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _picker = ImagePicker();
  String? _frontPhotoPath;

  @override
  void dispose() {
    _productNameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _takeFrontPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _frontPhotoPath = image.path);
    }
  }

  Map<String, dynamic> _buildProductInfo() {
    return {
      'productName': _productNameController.text.trim(),
      'brand': _brandController.text.trim(),
      'frontPhotoPath': _frontPhotoPath,
    };
  }

  void _goToOcr() {
    context.go('/product/${widget.barcode}/edit', extra: _buildProductInfo());
  }

  void _goToManual() {
    context.go('/product/${widget.barcode}/manual', extra: _buildProductInfo());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.productDetail),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.colors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              l10n.productNotFound,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              l10n.addProductIntro,
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Front photo
            GestureDetector(
              onTap: _takeFrontPhoto,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: context.colors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: _frontPhotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_frontPhotoPath!),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            size: 36,
                            color: context.colors.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.productPhotoOptional,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Product name
            TextField(
              controller: _productNameController,
              decoration: InputDecoration(
                labelText: l10n.productName,
                hintText: l10n.productNameHint,
                labelStyle: TextStyle(color: context.colors.textMuted),
                hintStyle: TextStyle(
                  color: context.colors.textMuted.withValues(alpha: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
                prefixIcon: Icon(
                  Icons.shopping_bag_outlined,
                  color: context.colors.textMuted,
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Brand
            TextField(
              controller: _brandController,
              decoration: InputDecoration(
                labelText: l10n.brandName,
                hintText: l10n.brandHint,
                labelStyle: TextStyle(color: context.colors.textMuted),
                hintStyle: TextStyle(
                  color: context.colors.textMuted.withValues(alpha: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary),
                ),
                prefixIcon: Icon(
                  Icons.business_outlined,
                  color: context.colors.textMuted,
                ),
              ),
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 24),

            // CTA: Take Ingredients Photo
            AppButton(
              label: l10n.completeWithPhoto,
              icon: Icons.camera_alt_rounded,
              onPressed: _goToOcr,
            ),
            const SizedBox(height: 12),

            // CTA: Manual Entry
            AppButton(
              label: l10n.manualEntry,
              variant: AppButtonVariant.secondary,
              icon: Icons.edit_note_rounded,
              onPressed: _goToManual,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
