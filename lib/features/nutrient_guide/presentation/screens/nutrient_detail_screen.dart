import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../../domain/entities/nutrient_entity.dart';
import '../amino_class_label.dart';
import '../providers/nutrient_provider.dart';

class NutrientDetailScreen extends ConsumerWidget {
  final String nutrientId;

  const NutrientDetailScreen({super.key, required this.nutrientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final nutrient = ref.watch(nutrientByIdProvider(nutrientId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: nutrient.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Message(context.l10n.nutrientLoadError),
        data: (n) => n == null
            ? _Message(context.l10n.nutrientNotFound)
            : _DetailBody(nutrient: n),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: TextStyle(color: context.colors.textMuted)),
  );
}

class _DetailBody extends StatelessWidget {
  final NutrientEntity nutrient;

  const _DetailBody({required this.nutrient});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final alt = nutrient.altName?.of(lang);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          nutrient.name.of(lang),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        if (alt != null) ...[
          const SizedBox(height: 2),
          Text(alt, style: TextStyle(fontSize: 14, color: colors.textMuted)),
        ],
        if (nutrient.aminoClass != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              label: Text(aminoClassLabel(l10n, nutrient.aminoClass!)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.favorite_outline_rounded,
          title: l10n.nutrientSectionFunction,
          child: _BodyText(nutrient.function.of(lang)),
        ),
        _SectionCard(
          icon: Icons.trending_down_rounded,
          title: l10n.nutrientSectionDeficiency,
          child: _Bullets(nutrient.deficiency.of(lang)),
        ),
        _SectionCard(
          icon: Icons.trending_up_rounded,
          title: l10n.nutrientSectionExcess,
          child: _Bullets(nutrient.excess.of(lang)),
        ),
        _SectionCard(
          icon: Icons.restaurant_rounded,
          title: l10n.nutrientSectionSources,
          child: _Bullets(nutrient.sources.of(lang)),
        ),
        _SectionCard(
          icon: Icons.scale_outlined,
          title: l10n.nutrientSectionDailyNeed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BodyText(nutrient.dailyNeed ?? l10n.nutrientNoDailyNeed),
              if (nutrient.upperLimit != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.nutrientUpperLimitLabel,
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                const SizedBox(height: 2),
                _BodyText(nutrient.upperLimit!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.nutrientSourceLabel(nutrient.source),
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.nutrientDisclaimer,
          style: TextStyle(fontSize: 12, color: colors.textMuted, height: 1.4),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: cozyCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;

  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: context.colors.textSecondary,
    ),
  );
}

class _Bullets extends StatelessWidget {
  final List<String> items;

  const _Bullets(this.items);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _BodyText('• $item'),
        ),
    ],
  );
}
