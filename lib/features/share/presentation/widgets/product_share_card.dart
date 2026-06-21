import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import 'share_card_palette.dart';

/// Pure, fixed-size (360×360 logical) branded card for sharing a product.
/// Rendered off-screen and captured to a 1080px PNG by ShareService.
class ProductShareCard extends StatelessWidget {
  final ImageProvider? image;
  final String name;
  final String brand;
  final int? hpScore;
  final List<String> chips;
  final String footer;

  const ProductShareCard({
    super.key,
    required this.image,
    required this.name,
    required this.brand,
    required this.hpScore,
    required this.chips,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final gauge = ScoreConstants.hpToGauge(hpScore?.toDouble());
    final scoreColor = ShareCardPalette.gaugeColor(gauge);

    return Container(
      width: 360,
      height: 360,
      color: ShareCardPalette.bg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: image != null
                      ? Image(
                          image: image!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                ),
              ),
              const Spacer(),
              if (hpScore != null) _scoreBadge(hpScore!, scoreColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ShareCardPalette.textPrimary,
              height: 1.15,
            ),
          ),
          if (brand.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: ShareCardPalette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in chips) _chip(c)],
          ),
          const Spacer(),
          _footerRow(footer),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: ShareCardPalette.surface,
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_outlined,
      size: 36,
      color: ShareCardPalette.textMuted,
    ),
  );

  Widget _scoreBadge(int score, Color color) => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 3),
    ),
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$score',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const Text(
          'HP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ShareCardPalette.textMuted,
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: ShareCardPalette.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ShareCardPalette.border),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: ShareCardPalette.textPrimary,
      ),
    ),
  );

  Widget _footerRow(String text) => Row(
    children: [
      const Icon(
        Icons.qr_code_2_rounded,
        size: 28,
        color: ShareCardPalette.brand,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ShareCardPalette.brand,
          ),
        ),
      ),
    ],
  );
}
