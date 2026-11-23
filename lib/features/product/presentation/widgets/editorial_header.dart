import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../../domain/entities/product_entity.dart';
import 'community_badge.dart';
import 'health_score_bar.dart';

class EditorialHeader extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback? onEditPressed;
  final bool isCommunity;

  const EditorialHeader({
    super.key,
    required this.product,
    this.onEditPressed,
    this.isCommunity = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hp = product.calculatedHpScore;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: cozyCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductThumbnail(imageUrl: product.imageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_categoryLabel != null || isCommunity) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_categoryLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.cozy.mint.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _categoryLabel!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.cozy.mint.ink,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            if (isCommunity) const CommunityBadge(),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.productName ?? product.barcode,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (onEditPressed != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: onEditPressed,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: colors.surfaceCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product.brands != null &&
                          product.brands!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.brands!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hp != null) ...[
              const SizedBox(height: 16),
              Center(
                child: HealthScoreBar(
                  hpScore: hp,
                  embedded: true,
                  summary: _buildSummaryLine(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildSummaryLine(BuildContext context) {
    final l10n = context.l10n;
    final parts = <String>[];

    final additiveCount = product.additivesTags.length;
    if (additiveCount == 0) {
      parts.add('0 ${l10n.scoreBreakdownAdditives}');
    } else {
      parts.add('$additiveCount ${l10n.scoreBreakdownAdditives}');
    }

    if (product.novaGroup != null) {
      parts.add('NOVA ${product.novaGroup}');
    }

    final sugar = product.nutriments.sugars;
    if (sugar != null) {
      parts.add('${l10n.sugarLabel} ${sugar.toStringAsFixed(1)}g');
    }

    return parts.join(' · ');
  }

  String? get _categoryLabel {
    if (product.categoriesTags.isEmpty) return null;
    final raw = product.categoriesTags.first;
    final cleaned = raw.contains(':') ? raw.split(':').last : raw;
    return cleaned.replaceAll('-', ' ').toUpperCase();
  }
}

class _ProductThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _ProductThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 84,
        height: 84,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: colors.surfaceCard,
                  child: Icon(
                    Icons.image_outlined,
                    size: 28,
                    color: colors.textMuted,
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: colors.surfaceCard,
                  child: Icon(
                    Icons.fastfood_rounded,
                    size: 28,
                    color: colors.textMuted,
                  ),
                ),
              )
            : Container(
                color: colors.surfaceCard,
                child: Icon(
                  Icons.fastfood_rounded,
                  size: 32,
                  color: colors.textMuted,
                ),
              ),
      ),
    );
  }
}
