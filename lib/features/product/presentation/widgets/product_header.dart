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
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 100, height: 100,
              color: context.colors.surfaceCard2,
              child: product.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 36,
                          color: context.colors.textMuted,
                        ),
                      ),
                      errorWidget: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 36,
                          color: context.colors.textMuted,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 36,
                        color: context.colors.textMuted,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.brands != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.brands!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
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

  Color _gradeColor(BuildContext context) {
    return switch (grade.toLowerCase()) {
      'a' => const Color(0xFF038141),
      'b' => const Color(0xFF85BB2F),
      'c' => const Color(0xFFFECB02),
      'd' => const Color(0xFFEE8100),
      'e' => const Color(0xFFE63E11),
      _ => context.colors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _gradeColor(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gradeColor(context).withValues(alpha: 0.4)),
      ),
      child: Text(
        'Nutri-Score ${grade.toUpperCase()}',
        style: TextStyle(
          color: _gradeColor(context),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}