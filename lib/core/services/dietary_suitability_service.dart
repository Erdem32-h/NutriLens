import '../constants/score_constants.dart';

/// Product-level dietary suitability (vegan / vegetarian / halal).
class DietarySuitability {
  final bool vegan;
  final bool vegetarian;
  final bool halal;

  const DietarySuitability({
    required this.vegan,
    required this.vegetarian,
    required this.halal,
  });
}

/// Heuristic dietary-suitability evaluator.
///
/// Combines two signals:
///   1. the product's additives (E-codes) — each carries vegan/vegetarian/
///      halal flags from the additive DB;
///   2. a keyword scan of the free-text ingredients for animal-derived or
///      non-halal markers (gelatin, pork, alcohol, carmine, …).
///
/// This is intentionally conservative: when a marker is found we mark the
/// diet *not suitable* rather than risk a misleading green check. It is a
/// best-effort signal, not a certification.
abstract final class DietarySuitabilityService {
  /// Returns null when there is no evidence at all (no additives and no
  /// ingredients) — the caller should hide the card rather than guess.
  static DietarySuitability? evaluate({
    required String? ingredientsText,
    required bool anyAdditiveNotVegan,
    required bool anyAdditiveNotVegetarian,
    required bool anyAdditiveNotHalal,
    required bool hasAdditiveData,
  }) {
    final hasIngredients =
        ingredientsText != null && ingredientsText.trim().isNotEmpty;
    if (!hasIngredients && !hasAdditiveData) return null;

    final t = hasIngredients
        ? ScoreConstants.normalizeTurkish(ingredientsText)
        : '';

    bool hasAny(List<String> words) =>
        t.isNotEmpty &&
        words.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(t));

    final nonVegan = anyAdditiveNotVegan || hasAny(_nonVeganTerms);
    final nonVegetarian =
        anyAdditiveNotVegetarian || hasAny(_nonVegetarianTerms);
    final nonHalal = anyAdditiveNotHalal || hasAny(_nonHalalTerms);

    return DietarySuitability(
      vegan: !nonVegan,
      vegetarian: !nonVegetarian,
      halal: !nonHalal,
    );
  }

  // Keywords are written in normalised form (lowercase, Turkish diacritics
  // folded to ASCII) to match ScoreConstants.normalizeTurkish output.

  /// Any animal-derived ingredient (incl. dairy / egg / honey) → not vegan.
  static const _nonVeganTerms = [
    'jelatin', 'gelatin', 'et', 'tavuk', 'dana', 'kuzu', 'sigir', 'beef',
    'chicken', 'meat', 'balik', 'fish', 'somon', 'salmon', 'ton baligi',
    'sut', 'sutlu', 'milk', 'peynir', 'cheese', 'yumurta', 'egg', 'bal',
    'honey', 'tereyagi', 'butter', 'krema', 'cream', 'whey', 'peynir alti',
    'kazein', 'casein', 'laktoz', 'lactose', 'yogurt', 'karmin', 'carmine',
    'e120', 'sellak', 'shellac', 'e904', 'balmumu', 'beeswax', 'e901',
    'domuz', 'pork', 'lard', 'jambon', 'ham', 'bacon', 'tallow', 'rennet',
    'peynir mayasi',
  ];

  /// Meat / fish / slaughter-derived ingredients → not vegetarian.
  static const _nonVegetarianTerms = [
    'jelatin', 'gelatin', 'et', 'tavuk', 'dana', 'kuzu', 'sigir', 'beef',
    'chicken', 'meat', 'balik', 'fish', 'somon', 'salmon', 'ton baligi',
    'domuz', 'pork', 'lard', 'jambon', 'ham', 'bacon', 'tallow', 'rennet',
    'peynir mayasi', 'karmin', 'carmine', 'e120',
  ];

  /// Pork, alcohol or non-certified animal markers → not halal.
  static const _nonHalalTerms = [
    'domuz', 'pork', 'lard', 'jambon', 'ham', 'bacon', 'jelatin', 'gelatin',
    'alkol', 'alcohol', 'etanol', 'ethanol', 'sarap', 'wine', 'bira', 'beer',
    'rom', 'likor', 'liqueur', 'viski', 'whisky', 'votka', 'vodka', 'konyak',
    'cognac',
  ];
}
