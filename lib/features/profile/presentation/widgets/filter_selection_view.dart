import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/health_filter_options.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class FilterSelectionView extends ConsumerWidget {
  final String title;
  final List<FilterOption> options;
  final List<String> selectedIds;
  final void Function(String id) onToggle;

  const FilterSelectionView({
    super.key,
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = selectedIds.contains(option.id);
          
          return _FilterTile(
            title: _getLocalizedOptionName(context, option.nameKey),
            subtitle: _getLocalizedOptionDesc(context, option.descKey),
            isSelected: isSelected,
            onTap: () => onToggle(option.id),
          );
        },
      ),
    );
  }

  String _getLocalizedOptionName(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'filterGluten': return l10n.filterGluten;
      case 'filterLactose': return l10n.filterLactose;
      case 'filterPeanut': return l10n.filterPeanut;
      case 'filterSoy': return l10n.filterSoy;
      case 'filterEgg': return l10n.filterEgg;
      case 'filterFish': return l10n.filterFish;
      case 'filterVegan': return l10n.filterVegan;
      case 'filterVegetarian': return l10n.filterVegetarian;
      case 'filterHalal': return l10n.filterHalal;
      case 'filterPalmOil': return l10n.filterPalmOil;
      case 'filterTransFat': return l10n.filterTransFat;
      case 'filterCanola': return l10n.filterCanola;
      case 'filterMsg': return l10n.filterMsg;
      case 'filterAspartame': return l10n.filterAspartame;
      case 'filterHfcs': return l10n.filterHfcs;
      case 'filterNitrite': return l10n.filterNitrite;
      case 'filterColorant': return l10n.filterColorant;
      default: return key;
    }
  }

  String _getLocalizedOptionDesc(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'filterGlutenDesc': return l10n.filterGlutenDesc;
      case 'filterLactoseDesc': return l10n.filterLactoseDesc;
      case 'filterPeanutDesc': return l10n.filterPeanutDesc;
      case 'filterSoyDesc': return l10n.filterSoyDesc;
      case 'filterEggDesc': return l10n.filterEggDesc;
      case 'filterFishDesc': return l10n.filterFishDesc;
      case 'filterVeganDesc': return l10n.filterVeganDesc;
      case 'filterVegetarianDesc': return l10n.filterVegetarianDesc;
      case 'filterHalalDesc': return l10n.filterHalalDesc;
      case 'filterPalmOilDesc': return l10n.filterPalmOilDesc;
      case 'filterTransFatDesc': return l10n.filterTransFatDesc;
      case 'filterCanolaDesc': return l10n.filterCanolaDesc;
      case 'filterMsgDesc': return l10n.filterMsgDesc;
      case 'filterAspartameDesc': return l10n.filterAspartameDesc;
      case 'filterHfcsDesc': return l10n.filterHfcsDesc;
      case 'filterNitriteDesc': return l10n.filterNitriteDesc;
      case 'filterColorantDesc': return l10n.filterColorantDesc;
      default: return key;
    }
  }
}

class _FilterTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary.withValues(alpha: 0.1) : context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? context.colors.primary : context.colors.textMuted,
                  width: 2,
                ),
                color: isSelected ? context.colors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
