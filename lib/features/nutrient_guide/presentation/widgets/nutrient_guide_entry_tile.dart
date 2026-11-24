import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cozy_tile.dart';

/// Entry point to the Nutrient Guide, shown where users meet nutrition
/// (Meals, product detail) rather than only in the profile settings list.
class NutrientGuideEntryTile extends StatelessWidget {
  /// Optional `?tab=` for the guide (`vitamin`, `mineral`, `amino`).
  final String? tab;

  const NutrientGuideEntryTile({super.key, this.tab});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CozyTile(
      tint: context.colors.cozy.lilac,
      icon: Icons.menu_book_rounded,
      title: l10n.nutrientGuideTitle,
      subtitle: l10n.nutrientGuideSubtitle,
      onTap: () => context.pushNamed(
        RouteNames.nutrientGuide,
        queryParameters: {'tab': ?tab},
      ),
    );
  }
}
