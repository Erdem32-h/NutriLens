import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';

class EditorialHeader extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback? onEditPressed;

  const EditorialHeader({
    super.key,
    required this.product,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: colors.surfaceCard,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: colors.surfaceCard,
                    child: Center(
                      child: Icon(
                        Icons.fastfood_rounded,
                        size: 48,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: colors.surfaceCard,
                  child: Center(
                    child: Icon(
                      Icons.fastfood_rounded,
                      size: 64,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Category badge
          if (_categoryLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categoryLabel!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),

          if (_categoryLabel != null) const SizedBox(height: 8),

          // Product name + edit button row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.productName ?? product.barcode,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              if (onEditPressed != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEditPressed,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Brand
          if (product.brands != null && product.brands!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              product.brands!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _categoryLabel {
    if (product.categoriesTags.isEmpty) return null;
    final raw = product.categoriesTags.first;
    // Clean "en:xxx" or "tr:xxx" format
    final cleaned = raw.contains(':') ? raw.split(':').last : raw;
    return cleaned.replaceAll('-', ' ').toUpperCase();
  }
}
