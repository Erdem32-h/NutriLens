import 'package:flutter/material.dart';

import 'share_card_palette.dart';

/// Pure, fixed-size (360×360 logical) branded card for sharing an AI meal.
/// Macro column labels use compact tokens (kcal / P / K / Y) — TR-first.
class MealShareCard extends StatelessWidget {
  final ImageProvider image;
  final String foodName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int portionGrams;
  final String footer;

  const MealShareCard({
    super.key,
    required this.image,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.portionGrams,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: ShareCardPalette.surface,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 36,
                    color: ShareCardPalette.textMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            foodName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ShareCardPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$portionGrams g',
            style: const TextStyle(
              fontSize: 13,
              color: ShareCardPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _macro('$calories', 'kcal', ShareCardPalette.brand),
              _macro('${protein}g', 'P', ShareCardPalette.textPrimary),
              _macro('${carbs}g', 'K', ShareCardPalette.textPrimary),
              _macro('${fat}g', 'Y', ShareCardPalette.textPrimary),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 28,
                color: ShareCardPalette.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
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

  Widget _macro(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ShareCardPalette.textMuted,
          ),
        ),
      ],
    ),
  );
}
