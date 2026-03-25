import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/content_analysis_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';

class ContentAnalysisSection extends ConsumerWidget {
  final ProductEntity product;

  const ContentAnalysisSection({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final warnings = ContentAnalysisService.analyzeIngredients(product);
    final additivesAsync = ref.watch(
      additivesByCodesProvider(product.additivesTags),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Analysis section
          if (warnings.isNotEmpty) ...[
            _SectionTitle(title: l10n.contentAnalysis),
            const SizedBox(height: 8),
            ...warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WarningCard(warning: warning),
                )),
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
            error: (_, __) => _EmptyAdditives(),
            data: (additiveMap) {
              if (additiveMap.isEmpty) return _EmptyAdditives();

              final sorted = additiveMap.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Column(
                children: sorted.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AdditiveCard(
                      eCode: entry.key,
                      riskLevel: entry.value,
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

    final message = _resolveMessage(l10n, warning.messageKey);

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

  String _resolveMessage(dynamic l10n, String key) {
    return switch (key) {
      'ultraProcessed' => l10n.ultraProcessed,
      'highSugar' => l10n.highSugar,
      'moderateSugar' => l10n.moderateSugar,
      'highSaturatedFat' => l10n.highSaturatedFat,
      'containsPalmOil' => l10n.containsPalmOil,
      'mayContainTransFat' => l10n.mayContainTransFat,
      'containsFlavoring' => l10n.containsFlavoring,
      'highSalt' => l10n.highSalt,
      _ => key,
    };
  }
}

class _AdditiveCard extends StatelessWidget {
  final String eCode;
  final int riskLevel;

  const _AdditiveCard({required this.eCode, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final (badgeColor, badgeText) = switch (riskLevel) {
      1 || 2 => (colors.riskSafe, l10n.safeLabel),
      3 => (colors.warning, l10n.caution),
      _ => (colors.error, l10n.risky),
    };

    // Clean e-code display
    final displayCode = eCode.startsWith('en:') ? eCode.substring(3) : eCode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
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
                    Icon(Icons.science_outlined, size: 18, color: badgeColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayCode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
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
