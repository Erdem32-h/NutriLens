import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/constants/health_filter_options.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../../core/widgets/cozy_tile.dart';

class FilterSelectionView extends ConsumerWidget {
  final String title;

  /// One line under the title saying what checking things here does.
  final String subtitle;

  /// The accent this filter wears on the profile screen. Carried through so
  /// the sub-screen looks like the row the user just tapped.
  final CozyTint tint;

  final List<FilterOption> options;
  final List<String> selectedIds;
  final void Function(String id) onToggle;

  const FilterSelectionView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          CozyHeader(
            title: title,
            subtitle: subtitle,
            tint: tint,
            // These screens are pushed from the profile tab, so popping is
            // the normal exit; the go() covers a deep link that landed here
            // with nothing underneath.
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/profile'),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = selectedIds.contains(option.id);

                return _FilterTile(
                  title: _getLocalizedOptionName(context, option.nameKey),
                  subtitle: _getLocalizedOptionDesc(context, option.descKey),
                  isSelected: isSelected,
                  tint: tint,
                  onTap: () => onToggle(option.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedOptionName(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'filterGluten':
        return l10n.filterGluten;
      case 'filterLactose':
        return l10n.filterLactose;
      case 'filterPeanut':
        return l10n.filterPeanut;
      case 'filterSoy':
        return l10n.filterSoy;
      case 'filterEgg':
        return l10n.filterEgg;
      case 'filterFish':
        return l10n.filterFish;
      case 'filterVegan':
        return l10n.filterVegan;
      case 'filterVegetarian':
        return l10n.filterVegetarian;
      case 'filterHalal':
        return l10n.filterHalal;
      case 'filterPalmOil':
        return l10n.filterPalmOil;
      case 'filterTransFat':
        return l10n.filterTransFat;
      case 'filterCanola':
        return l10n.filterCanola;
      case 'filterMsg':
        return l10n.filterMsg;
      case 'filterAspartame':
        return l10n.filterAspartame;
      case 'filterHfcs':
        return l10n.filterHfcs;
      case 'filterNitrite':
        return l10n.filterNitrite;
      case 'filterColorant':
        return l10n.filterColorant;
      default:
        return key;
    }
  }

  String _getLocalizedOptionDesc(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'filterGlutenDesc':
        return l10n.filterGlutenDesc;
      case 'filterLactoseDesc':
        return l10n.filterLactoseDesc;
      case 'filterPeanutDesc':
        return l10n.filterPeanutDesc;
      case 'filterSoyDesc':
        return l10n.filterSoyDesc;
      case 'filterEggDesc':
        return l10n.filterEggDesc;
      case 'filterFishDesc':
        return l10n.filterFishDesc;
      case 'filterVeganDesc':
        return l10n.filterVeganDesc;
      case 'filterVegetarianDesc':
        return l10n.filterVegetarianDesc;
      case 'filterHalalDesc':
        return l10n.filterHalalDesc;
      case 'filterPalmOilDesc':
        return l10n.filterPalmOilDesc;
      case 'filterTransFatDesc':
        return l10n.filterTransFatDesc;
      case 'filterCanolaDesc':
        return l10n.filterCanolaDesc;
      case 'filterMsgDesc':
        return l10n.filterMsgDesc;
      case 'filterAspartameDesc':
        return l10n.filterAspartameDesc;
      case 'filterHfcsDesc':
        return l10n.filterHfcsDesc;
      case 'filterNitriteDesc':
        return l10n.filterNitriteDesc;
      case 'filterColorantDesc':
        return l10n.filterColorantDesc;
      default:
        return key;
    }
  }
}

/// One selectable filter.
///
/// Selection is carried by the card's own fill — checked rows sit on the
/// screen's tint, unchecked ones on the neutral floating card — so the state
/// is legible from across the list, not just from a 24px circle.
class _FilterTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final CozyTint tint;
  final VoidCallback onTap;

  const _FilterTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(24);

    // Hand-rolled rather than an AppTapCard because the fill has to animate
    // between the two states; AppTapCard paints a fixed decoration. The
    // Material/InkWell arrangement below mirrors its ripple handling so the
    // press feedback still matches the rest of the app.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: cozyCardDecoration(
        context,
      ).copyWith(color: isSelected ? tint.surface : colors.cozy.floating),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.cozy.bodyOnTint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? tint.ink : colors.textMuted,
                      width: 2,
                    ),
                    color: isSelected ? tint.ink : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: colors.cozy.floating,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
