import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../share/presentation/widgets/share_card_palette.dart';

/// Pure, fixed-size (360×640 logical) branded card summarizing a Ramadan:
/// days fasted out of the period and total water drunk. Rendered off-screen
/// and captured to a 1080×1920 PNG by `ShareService` (see `RamadanScreen`).
/// Localizes its own copy from `context.l10n` — unlike the meal/product/
/// comparison cards, none of its text varies by call site, so there's
/// nothing for the caller to pass in beyond the raw numbers.
class RamadanShareCard extends StatelessWidget {
  final int fasted;
  final int total;
  final double liters;

  const RamadanShareCard({
    super.key,
    required this.fasted,
    required this.total,
    required this.liters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final litersText = NumberFormat('#0.#', locale).format(liters);

    return Container(
      width: 360,
      height: 640,
      color: ShareCardPalette.bg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.nightlight_round,
            size: 32,
            color: ShareCardPalette.brand,
          ),
          const Spacer(),
          Text(
            l10n.ramadanShareFasted(fasted),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: ShareCardPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ramadanDaysProgress(fasted, total),
            style: const TextStyle(
              fontSize: 15,
              color: ShareCardPalette.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.ramadanShareWater(litersText),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ShareCardPalette.textPrimary,
            ),
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
              const Text(
                'NutriLens',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ShareCardPalette.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
