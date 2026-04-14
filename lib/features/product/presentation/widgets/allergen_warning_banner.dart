import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../additive/domain/entities/allergen_entity.dart';

/// A red warning banner shown when the product contains allergens that the
/// user has marked as relevant to them.
///
/// Shows nothing when there is no overlap between [allergensTags] (product)
/// and [userAllergenIds] (user profile).
class AllergenWarningBanner extends ConsumerWidget {
  /// Allergen tags from the product (Open Food Facts format, e.g. "en:milk").
  final List<String> allergensTags;

  /// IDs from the user's allergen profile (e.g. "milk", "gluten").
  final List<String> userAllergenIds;

  /// Full allergen catalogue used to resolve display names.
  final List<AllergenEntity> allAllergens;

  const AllergenWarningBanner({
    super.key,
    required this.allergensTags,
    required this.userAllergenIds,
    required this.allAllergens,
  });

  /// Returns the set of [AllergenEntity] items that the product contains and
  /// the user is sensitive to.
  List<AllergenEntity> _matchedAllergens() {
    if (allergensTags.isEmpty || userAllergenIds.isEmpty) return [];

    final normalizedTags =
        allergensTags.map((t) => t.toLowerCase()).toList(growable: false);

    return allAllergens.where((allergen) {
      final id = allergen.id.toLowerCase();
      return userAllergenIds
              .any((uid) => uid.toLowerCase() == id) &&
          normalizedTags.any((tag) => tag.contains(id));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matched = _matchedAllergens();
    if (matched.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.error.withValues(alpha: 0.18),
              colors.warning.withValues(alpha: 0.10),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colors.error,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.allergenWarningTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.error,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: matched
                        .map((a) => _AllergenTag(
                              name: a.nameTr,
                              colors: colors,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergenTag extends StatelessWidget {
  final String name;
  final AppColorsExtension colors;

  const _AllergenTag({required this.name, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.error,
        ),
      ),
    );
  }
}
