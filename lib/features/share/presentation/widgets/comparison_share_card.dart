import 'package:flutter/material.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../comparison/domain/product_comparison.dart';
import 'share_card_palette.dart';

/// Pure, fixed-size (360×360 logical) branded card for sharing a side-by-side
/// product comparison. Captured off-screen to a 1080px PNG by ShareService.
/// The healthier side (higher HP score) gets a green ring + "healthier" chip.
class ComparisonShareCard extends StatelessWidget {
  final ImageProvider? imageA;
  final ImageProvider? imageB;
  final String nameA;
  final String nameB;
  final int? hpA;
  final int? hpB;
  final BetterSide better;
  final String healthierLabel;
  final String footer;

  const ComparisonShareCard({
    super.key,
    required this.imageA,
    required this.imageB,
    required this.nameA,
    required this.nameB,
    required this.hpA,
    required this.hpB,
    required this.better,
    required this.healthierLabel,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      color: ShareCardPalette.bg,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _side(imageA, nameA, hpA, better == BetterSide.a),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ShareCardPalette.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: _side(imageB, nameB, hpB, better == BetterSide.b),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 26,
                color: ShareCardPalette.brand,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  footer,
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
          ),
        ],
      ),
    );
  }

  Widget _side(ImageProvider? img, String name, int? hp, bool isWinner) {
    final gauge = ScoreConstants.hpToGauge(hp?.toDouble());
    final color = ShareCardPalette.gaugeColor(gauge);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: isWinner
                ? Border.all(color: ShareCardPalette.brand, width: 3)
                : null,
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 84,
              height: 84,
              child: img != null
                  ? Image(
                      image: img,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ShareCardPalette.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            hp == null ? '—' : '$hp',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        if (isWinner) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                size: 14,
                color: ShareCardPalette.brand,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  healthierLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ShareCardPalette.brand,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _imgPlaceholder() => Container(
    color: ShareCardPalette.surface,
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_outlined,
      size: 30,
      color: ShareCardPalette.textMuted,
    ),
  );
}
