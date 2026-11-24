import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../../domain/entities/nutrient_entity.dart';
import '../../domain/nutrient_search.dart';
import '../amino_class_label.dart';
import '../providers/nutrient_provider.dart';

/// Vitamins / minerals / amino acids reference, searchable by name.
class NutrientGuideScreen extends ConsumerStatefulWidget {
  /// Tab to open on: `vitamin`, `mineral` or `amino` (the `?tab=` query
  /// parameter). Anything else opens on vitamins.
  final String? initialTab;

  const NutrientGuideScreen({super.key, this.initialTab});

  @override
  ConsumerState<NutrientGuideScreen> createState() =>
      _NutrientGuideScreenState();
}

class _NutrientGuideScreenState extends ConsumerState<NutrientGuideScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final nutrients = ref.watch(nutrientsProvider);

    return DefaultTabController(
      length: NutrientCategory.values.length,
      initialIndex: switch (widget.initialTab) {
        'mineral' => NutrientCategory.mineral.index,
        'amino' => NutrientCategory.aminoAcid.index,
        _ => NutrientCategory.vitamin.index,
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l10n.nutrientGuideTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: nutrients.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              _LoadError(onRetry: () => ref.invalidate(nutrientsProvider)),
          data: (all) => _GuideBody(
            all: all,
            query: _query,
            onQueryChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
    );
  }
}

class _GuideBody extends StatelessWidget {
  final List<NutrientEntity> all;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _GuideBody({
    required this.all,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final matches = searchNutrients(all, query, lang);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.nutrientSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.nutrientTabVitamins),
            Tab(text: l10n.nutrientTabMinerals),
            Tab(text: l10n.nutrientTabAminoAcids),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              for (final category in NutrientCategory.values)
                _CategoryList(
                  items: matches.where((n) => n.category == category).toList(),
                  category: category,
                  languageCode: lang,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<NutrientEntity> items;
  final NutrientCategory category;
  final String languageCode;

  const _CategoryList({
    required this.items,
    required this.category,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.nutrientNoResults,
          style: TextStyle(color: context.colors.textMuted),
        ),
      );
    }
    final cozy = context.colors.cozy;
    final (CozyTint tint, IconData icon) = switch (category) {
      NutrientCategory.vitamin => (cozy.peach, Icons.eco_rounded),
      NutrientCategory.mineral => (cozy.sky, Icons.diamond_outlined),
      NutrientCategory.aminoAcid => (cozy.lilac, Icons.bubble_chart_rounded),
    };

    Widget tile(NutrientEntity n) => CozyTile(
      tint: tint,
      icon: icon,
      title: n.name.of(languageCode),
      subtitle: n.altName?.of(languageCode),
      onTap: () => context.pushNamed(
        RouteNames.nutrientDetail,
        pathParameters: {'id': n.id},
      ),
    );

    if (category != NutrientCategory.aminoAcid) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: items.length,
        itemBuilder: (context, i) => tile(items[i]),
      );
    }

    // Amino acids: essential first, then conditional, then non-essential,
    // each under a header; groups emptied by the search are left out.
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (final cls in AminoAcidClass.values)
          if (items.any((n) => n.aminoClass == cls)) ...[
            _GroupHeader(
              '${aminoClassLabel(l10n, cls)} '
              '(${items.where((n) => n.aminoClass == cls).length})',
            ),
            for (final n in items.where((n) => n.aminoClass == cls)) tile(n),
          ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String text;

  const _GroupHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.nutrientLoadError,
            style: TextStyle(color: context.colors.textPrimary),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.nutrientRetry)),
        ],
      ),
    );
  }
}
