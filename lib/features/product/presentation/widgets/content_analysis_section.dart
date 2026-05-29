import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/content_analysis_service.dart';
import '../../../../core/services/hp_score_calculator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../config/router/route_names.dart';
import '../../domain/entities/product_entity.dart';
import '../../../additive/presentation/providers/additive_provider.dart';
import '../../../profile/presentation/providers/health_filters_provider.dart';

class ContentAnalysisSection extends ConsumerWidget {
  final ProductEntity product;

  const ContentAnalysisSection({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final filters = ref.watch(healthFiltersProvider);
    final warnings = ContentAnalysisService.analyzeIngredients(
      product: product,
      activeAllergens: filters.allergens,
      activeDiets: filters.diets,
      activeOils: filters.oils,
      activeChemicals: filters.chemicals,
    );
    final additivesAsync = ref.watch(
      additiveEntitiesByCodesProvider(product.additivesTags),
    );
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Analysis section
          if (warnings.isNotEmpty) ...[
            _SectionTitle(title: l10n.contentAnalysis),
            const SizedBox(height: 8),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WarningCard(warning: warning),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // E-Code Analysis section
          _SectionTitle(title: l10n.eCodeAnalysis),
          const SizedBox(height: 8),
          additivesAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            error: (_, _) => _EmptyAdditives(),
            data: (additives) {
              if (product.additivesTags.isEmpty) return _EmptyAdditives();

              // Index DB matches by normalised E-code so we can attach a name
              // and a precise risk level; codes not in the DB fall back to a
              // moderate risk with no name (still shown).
              final byCode = {
                for (final a in additives)
                  HpScoreCalculator.normalizeECode(a.eNumber): a,
              };

              final cards = <_AdditiveCardData>[];
              final seen = <String>{};
              for (final raw in product.additivesTags) {
                final code = HpScoreCalculator.normalizeECode(raw);
                if (!seen.add(code)) continue;
                final entity = byCode[code];
                cards.add(
                  _AdditiveCardData(
                    eCode: code,
                    name: entity == null
                        ? null
                        : (isTr ? (entity.nameTr ?? entity.nameEn) : entity.nameEn),
                    riskLevel: entity?.riskLevel ?? 3,
                  ),
                );
              }

              if (cards.isEmpty) return _EmptyAdditives();
              cards.sort((a, b) => b.riskLevel.compareTo(a.riskLevel));

              return Column(
                children: cards.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AdditiveCard(
                      eCode: c.eCode,
                      name: c.name,
                      riskLevel: c.riskLevel,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final ContentWarning warning;

  const _WarningCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final (badgeColor, badgeText) = switch (warning.level) {
      WarningLevel.risky => (colors.error, l10n.risky),
      WarningLevel.caution => (colors.warning, l10n.caution),
      WarningLevel.safe => (colors.riskSafe, l10n.safeLabel),
      WarningLevel.natural => (colors.primary, l10n.naturalLabel),
    };

    final message = _resolveMessage(l10n, warning);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left colored border
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(warning.icon, size: 20, color: badgeColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(text: badgeText, color: badgeColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveMessage(dynamic l10n, ContentWarning warning) {
    if (warning.messageKey == 'containsFilteredItem' &&
        warning.placeholderKey != null) {
      final filterName = switch (warning.placeholderKey) {
        'filterGluten' => l10n.filterGluten,
        'filterLactose' => l10n.filterLactose,
        'filterPeanut' => l10n.filterPeanut,
        'filterSoy' => l10n.filterSoy,
        'filterEgg' => l10n.filterEgg,
        'filterFish' => l10n.filterFish,
        'filterVegan' => l10n.filterVegan,
        'filterVegetarian' => l10n.filterVegetarian,
        'filterHalal' => l10n.filterHalal,
        'filterPalmOil' => l10n.filterPalmOil,
        'filterTransFat' => l10n.filterTransFat,
        'filterCanola' => l10n.filterCanola,
        'filterMsg' => l10n.filterMsg,
        'filterAspartame' => l10n.filterAspartame,
        'filterHfcs' => l10n.filterHfcs,
        'filterNitrite' => l10n.filterNitrite,
        'filterColorant' => l10n.filterColorant,
        _ => warning.placeholderKey!,
      };
      return l10n.containsFilteredItem(filterName);
    }

    return switch (warning.messageKey) {
      'ultraProcessed' => l10n.ultraProcessed,
      'highSugar' => l10n.highSugar,
      'moderateSugar' => l10n.moderateSugar,
      'highSaturatedFat' => l10n.highSaturatedFat,
      'containsPalmOil' => l10n.containsPalmOil,
      'mayContainTransFat' => l10n.mayContainTransFat,
      'containsFlavoring' => l10n.containsFlavoring,
      'highSalt' => l10n.highSalt,
      _ => warning.messageKey,
    };
  }
}

class _AdditiveCardData {
  final String eCode;
  final String? name;
  final int riskLevel;

  const _AdditiveCardData({
    required this.eCode,
    required this.name,
    required this.riskLevel,
  });
}

class _AdditiveCard extends StatelessWidget {
  final String eCode;
  final String? name;
  final int riskLevel;

  const _AdditiveCard({
    required this.eCode,
    required this.name,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final riskColor = colors.riskColor(riskLevel);
    final badgeText = _riskLabel(l10n, riskLevel);

    // Clean e-code display
    final displayCode = eCode.startsWith('en:') ? eCode.substring(3) : eCode;
    final navigateCode = displayCode.toUpperCase();

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.additiveDetail,
        pathParameters: {'eCode': navigateCode},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: riskColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18, color: riskColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              navigateCode,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (name != null && name!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                name!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Badge(text: badgeText, color: riskColor),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _riskLabel(dynamic l10n, int level) => switch (level) {
    1 => l10n.risk1,
    2 => l10n.risk2,
    3 => l10n.risk3,
    4 => l10n.risk4,
    _ => l10n.risk5,
  };
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyAdditives extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: colors.riskSafe),
          const SizedBox(width: 10),
          Text(
            l10n.noAdditives,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
