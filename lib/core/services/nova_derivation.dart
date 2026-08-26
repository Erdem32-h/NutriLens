import '../constants/score_constants.dart';

/// Derives a NOVA processing group from what a label actually says.
///
/// Open Food Facts leaves `nova_group` empty on roughly two thirds of the
/// products we see (48 of 71 in the community table), and Turkish coverage is
/// the weakest part of that. Without a value the score falls back to a neutral
/// "unknown" naturalness, which means an ultra-processed product is treated as
/// mildly better than a merely processed one purely because nobody filled in
/// the field.
///
/// **Only group 4 is derived.** Proving a product is ultra-processed needs one
/// positive marker; proving it is *un*processed needs the absence of every
/// marker, and an OCR'd label that captured half the ingredient list looks
/// exactly like a clean one. Since a derived 4 now caps the score
/// ([ScoreConstants.ultraProcessedCeiling]), a false positive costs the product
/// real points — so this errs towards returning null.
abstract final class NovaDerivation {
  /// Additive classes that exist to make an industrial formulation look, feel
  /// or taste like food: colours (E1xx), emulsifiers and thickeners (E4xx),
  /// flavour enhancers (E62x–E65x) and sweeteners (E95x–E96x). These are the
  /// "cosmetic additives" NOVA treats as the marker of group 4. Deliberately
  /// excluded: E2xx preservatives and E3xx antioxidants (salting and
  /// vitamin C have kitchen equivalents), and E5xx (E500 is baking soda).
  ///
  /// E322 is the one number pulled out of the excluded E3xx block: lecithin is
  /// an emulsifier that happens to be filed with the antioxidants, and it is
  /// the most common one on a Turkish confectionery label.
  static final _cosmeticECode = RegExp(
    r'\be[\s-]?(1\d{2}|322|4\d{2}|6[2-5]\d|9[5-6]\d)[a-z]?\b',
    caseSensitive: false,
  );

  /// Substances never found in a domestic kitchen, plus the Turkish, English
  /// and German category words that stand in for them when a label names the
  /// function instead of the E-number ("Tatlandırıcılar (…)", "Farbstoff").
  /// Written pre-normalised — see [ScoreConstants.normalizeTurkish].
  static final _industrialMarker = RegExp(
    r'hidrojenize|hydrogenated|maltodekstrin|maltodextrin|'
    r'glikoz-fruktoz|fruktoz-glukoz|fruktoz-glikoz|glucose-fructose|high fructose|'
    r'invert (seker|sugar)|'
    r'modifiye nisasta|modified (potato |corn |food )?starch|'
    r'protein izolat|protein isolate|'
    r'tatlandirici|sweetener|emulgator|emulsifier|'
    r'renklendirici|farbstoff|colou?ring|artificial (flavor|colour|color)|'
    r'natural flavor|aroma verici|aromen|kivam artirici|thickener',
  );

  /// Returns 4 when the label carries a marker of ultra-processing, otherwise
  /// null. Never returns 1, 2 or 3 — absence of evidence is not evidence of a
  /// whole food.
  static int? deriveNovaGroup({
    String? ingredientsText,
    List<String> additivesTags = const [],
  }) {
    final raw = '${ingredientsText ?? ''} ${additivesTags.join(' ')}';
    if (raw.trim().isEmpty) return null;

    final text = ScoreConstants.normalizeTurkish(raw);
    final isUltraProcessed =
        _cosmeticECode.hasMatch(text) || _industrialMarker.hasMatch(text);
    return isUltraProcessed ? 4 : null;
  }
}
