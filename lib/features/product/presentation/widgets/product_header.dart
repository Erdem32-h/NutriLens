import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';

class ProductHeader extends StatelessWidget {
  final ProductEntity product;

  const ProductHeader({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 100, height: 100,
              color: AppColors.surfaceCard2,
              child: product.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 36,
                          color: AppColors.textMuted,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 36,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 36,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName ?? 'Bilinmeyen Ürün',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.brands != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.brands!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                if (product.nutriscoreGrade != null)
                  _NutriScoreBadge(grade: product.nutriscoreGrade!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutriScoreBadge extends StatelessWidget {
  final String grade;

  const _NutriScoreBadge({required this.grade});

  Color _gradeColor() {
    return switch (grade.toLowerCase()) {
      'a' => const Color(0xFF038141),
      'b' => const Color(0xFF85BB2F),
      'c' => const Color(0xFFFECB02),
      'd' => const Color(0xFFEE8100),
      'e' => const Color(0xFFE63E11),
      _ => AppColors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _gradeColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gradeColor().withValues(alpha: 0.4)),
      ),
      child: Text(
        'Nutri-Score ${grade.toUpperCase()}',
        style: TextStyle(
          color: _gradeColor(),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
