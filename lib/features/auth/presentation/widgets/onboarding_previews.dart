import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/scanning_photo.dart';
import '../../../product/presentation/widgets/health_score_bar.dart';

/// Onboarding'de gösterilen örnek değerler.
///
/// İllüstratiftir — hesaplanmış sonuç değildir. Fotoğraftaki yemek için
/// makul seçildiler (≈320 g kıymalı makarna). Ekranda "hesaplandı" iddiası
/// yok; amaç ürünün ne ürettiğini göstermek.
abstract final class _Sample {
  /// 62 → ScoreConstants.hpToGauge → 2. Bilinçli olarak "iyi ama mükemmel
  /// değil": 1/5 ürünü işlevsiz gösterir, 5/5 ilk ekranda suçlayıcı durur.
  static const double mealHp = 62.0;
  static const int kcal = 486;
  static const int proteinG = 24;

  /// 26 → gauge 4. Paketli ürünün skorun işe yaradığını göstermesi için
  /// kötümser tarafta.
  static const double productHp = 26.0;
  static const int sugarG = 21;
  static const int additiveCount = 4;
  static const double saltG = 1.2;
}

/// Sayfa 0 — asıl akış: tabak fotoğrafı → kalori/protein/puan.
class MealPreview extends StatelessWidget {
  const MealPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            // sweeps sonlu olmak ZORUNDA — bkz. ScanningPhoto belgesi.
            child: const ScanningPhoto(
              image: AssetImage('assets/images/onboarding_meal.jpg'),
              sweeps: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingSampleMealName,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.onboardingSamplePortion,
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCell(value: '${_Sample.kcal}', label: 'kcal'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value: '${_Sample.proteinG} g',
                label: l10n.proteinLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value: '${ScoreConstants.hpToGauge(_Sample.mealHp)}/5',
                label: l10n.healthScoreLabel,
                valueColor: colors.gaugeColor(
                  ScoreConstants.hpToGauge(_Sample.mealHp),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sayfa 1 — paketli ürün: gerçek HealthScoreBar + ambalajda görülebilen
/// somut değerler (jargon değil).
class ScorePreview extends StatelessWidget {
  const ScorePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ürün ekranındaki widget'ın ta kendisi — onboarding'in vaadi ile
        // uygulamanın gösterdiği şey birebir aynı olsun diye.
        const HealthScoreBar(hpScore: _Sample.productHp),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatCell(
                value: '${_Sample.sugarG} g',
                label: l10n.sugarLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value: '${_Sample.additiveCount}',
                label: l10n.additives,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCell(
                value:
                    '${NumberFormat.decimalPattern(locale).format(_Sample.saltG)} g',
                label: l10n.saltLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sayfa 2 — kişiselleştirmenin somut çıktısı: bir uyarı.
///
/// Burası yalnızca anlatım görselidir; gerçek filtre ayarı profilde kalır.
class FiltersPreview extends StatelessWidget {
  const FiltersPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(label: l10n.filterGluten, selected: true),
            _Chip(label: l10n.filterLactose, selected: true),
            _Chip(label: l10n.vegan, selected: false),
            _Chip(label: l10n.halal, selected: false),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: colors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.onboardingSampleWarning,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;

  const _Chip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.15)
            : colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? colors.primary : colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? colors.primary : colors.textMuted,
        ),
      ),
    );
  }
}
