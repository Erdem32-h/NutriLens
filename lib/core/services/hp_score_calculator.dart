import 'dart:math';

import '../../config/drift/app_database.dart';
import '../constants/score_constants.dart';
import '../../features/product/domain/entities/nutriments_entity.dart';

class HpScoreResult {
  final double hpScore;
  final double chemicalLoad;
  final double? riskFactor;
  final double? nutriFactor;
  final bool isPartial;
  final int gaugeLevel;

  const HpScoreResult({
    required this.hpScore,
    required this.chemicalLoad,
    this.riskFactor,
    this.nutriFactor,
    required this.isPartial,
    required this.gaugeLevel,
  });
}

class HpScoreCalculator {
  final AppDatabase _db;

  const HpScoreCalculator(this._db);

  /// Normalize E-code tags from various formats to "E471" format.
  /// Handles: "en:e471", "E471", "e471", "E 471", "E-471"
  static String normalizeECode(String tag) {
    var code = tag.trim().toLowerCase();
    // Remove "en:" prefix from OFF format
    if (code.startsWith('en:')) {
      code = code.substring(3);
    }
    // Remove spaces and hyphens
    code = code.replaceAll(' ', '').replaceAll('-', '');
    // Ensure starts with 'e' followed by digits
    final match = RegExp(r'^e(\d{3,4}[a-z]?)$').firstMatch(code);
    if (match == null) return tag; // Return original if no match
    return 'E${match.group(1)!}';
  }

  /// Extract E-codes from free-text ingredients.
  /// Finds patterns like: E471, E 150d, E-330, (E211), e621
  static List<String> extractECodesFromText(String? ingredientsText) {
    if (ingredientsText == null || ingredientsText.isEmpty) return [];

    final matches = RegExp(
      r'\bE[\s\-]?(\d{3,4}[a-z]?)\b',
      caseSensitive: false,
    ).allMatches(ingredientsText);

    final codes = <String>{};
    for (final m in matches) {
      final digits = m.group(1);
      if (digits != null) {
        codes.add('E$digits');
      }
    }
    return codes.toList();
  }

  /// Full HP Score — all data available (API sources or user entry)
  Future<HpScoreResult> calculateFull({
    required List<String> additivesTags,
    required NutrimentsEntity nutriments,
    int? novaGroup,
    String? ingredientsText,
  }) async {
    // Merge explicit additive tags with E-codes found in text
    final allAdditives = await _mergeAdditives(additivesTags, ingredientsText);

    final chemicalLoad = await _calculateChemicalLoad(allAdditives);
    final riskFactor = _calculateRiskFactor(nutriments);
    final nutriFactor = _calculateNutriFactor(nutriments, novaGroup);
    final ingredientQualityPenalty = _calculateIngredientQualityPenalty(
      ingredientsText,
    );

    final hpScore =
        (100 -
                (chemicalLoad * ScoreConstants.chemicalWeight) -
                (riskFactor * ScoreConstants.riskWeight) +
                (nutriFactor * ScoreConstants.nutriWeight) -
                ingredientQualityPenalty)
            .clamp(0.0, 100.0);

    // ── Critical ingredient blacklist ──
    // If ANY of these are found → instant worst score (10.0 → gauge 5)
    final String t = ingredientsText != null
        ? ScoreConstants.normalizeTurkish(ingredientsText)
        : '';

    final bool hasCriticalIngredients = ScoreConstants.criticalPatterns.any(
      (pattern) => t.contains(pattern),
    );

    final double finalHpScore = hasCriticalIngredients ? 10.0 : hpScore;
    final int finalGaugeLevel = hasCriticalIngredients
        ? 5
        : ScoreConstants.hpToGauge(finalHpScore);

    return HpScoreResult(
      hpScore: finalHpScore,
      chemicalLoad: chemicalLoad,
      riskFactor: riskFactor,
      nutriFactor: nutriFactor,
      isPartial: false,
      gaugeLevel: finalGaugeLevel,
    );
  }

  /// Partial HP Score — only chemical load (OCR-only)
  Future<HpScoreResult> calculatePartial({
    required List<String> additivesTags,
  }) async {
    final chemicalLoad = await _calculateChemicalLoad(additivesTags);

    // Partial score: only chemical load component, no risk/nutri
    final hpScore = (100 - (chemicalLoad * ScoreConstants.chemicalWeight))
        .clamp(0.0, 100.0);

    return HpScoreResult(
      hpScore: hpScore,
      chemicalLoad: chemicalLoad,
      riskFactor: null,
      nutriFactor: null,
      isPartial: true,
      gaugeLevel: ScoreConstants.hpToGauge(hpScore),
    );
  }

  /// Merge additive sources into one deduplicated list of normalised E-codes:
  ///   1. Explicit additive tags from the OFF API (e.g. "en:e322")
  ///   2. E-codes written inline in ingredients text (e.g. "(E476)")
  ///   3. Name-based DB lookup — matches Turkish/English additive names found
  ///      in the ingredients text so that products that write "Poligliserol
  ///      Polirisinoleat" instead of "E476" are still detected.
  Future<List<String>> _mergeAdditives(
    List<String> additivesTags,
    String? ingredientsText,
  ) async {
    final codes = <String>{};

    // ── 1. API tags ──────────────────────────────────────────────────
    for (final tag in additivesTags) {
      codes.add(normalizeECode(tag));
    }

    // ── 2. Inline E-codes in text ────────────────────────────────────
    for (final code in extractECodesFromText(ingredientsText)) {
      codes.add(code);
    }

    // ── 3. Name-based lookup ─────────────────────────────────────────
    if (ingredientsText != null && ingredientsText.isNotEmpty) {
      final byName = await _extractAdditivesByName(ingredientsText);
      codes.addAll(byName);
    }

    return codes.toList();
  }

  /// Look up additives in the local DB whose Turkish or English name appears
  /// in [ingredientsText].  Uses normalised (ASCII) comparison so that OCR
  /// errors and missing Turkish diacritics don't prevent matching.
  Future<List<String>> _extractAdditivesByName(String ingredientsText) async {
    try {
      final allRows = await _db.select(_db.additives).get();
      if (allRows.isEmpty) return [];

      final normText = ScoreConstants.normalizeTurkish(ingredientsText);
      final found = <String>{};

      for (final row in allRows) {
        // Build candidate names: try Turkish first, then English
        final candidates = <String>[];
        if (row.nameTr != null && row.nameTr!.isNotEmpty) {
          candidates.add(row.nameTr!);
        }
        candidates.add(row.nameEn);

        for (final rawName in candidates) {
          // Strip parenthetical suffixes: "Poligliserol Polirisinoleat (PGPR)"
          // → "Poligliserol Polirisinoleat"
          final clean = rawName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

          // Ignore very short names to avoid false positives
          if (clean.length < 6) continue;

          final normName = ScoreConstants.normalizeTurkish(clean);
          if (normText.contains(normName)) {
            found.add(row.eNumber);
            break; // Found via this additive, no need to check English name
          }
        }
      }

      return found.toList();
    } catch (_) {
      return [];
    }
  }

  Future<double> _calculateChemicalLoad(List<String> additivesTags) async {
    if (additivesTags.isEmpty) return 0.0;

    double totalPenalty = 0.0;

    for (final tag in additivesTags) {
      final eCode = normalizeECode(tag);
      final riskLevel = await _getAdditiveRiskLevel(eCode);
      totalPenalty += ScoreConstants.additivePenalties[riskLevel] ?? 10.0;
    }

    // Normalize to 0-100 scale, cap at 100
    return min(totalPenalty, 100.0);
  }

  Future<int> _getAdditiveRiskLevel(String eCode) async {
    try {
      final query = _db.select(_db.additives)
        ..where((t) => t.eNumber.equals(eCode));
      final row = await query.getSingleOrNull();
      return row?.riskLevel ?? 3; // Default moderate if not found
    } catch (_) {
      return 3; // Default moderate on error
    }
  }

  double _calculateRiskFactor(NutrimentsEntity n) {
    final sugarRatio =
        min((n.sugars ?? 0) / ScoreConstants.sugarMaxRef, 1.0) * 100;
    final saltRatio = min((n.salt ?? 0) / ScoreConstants.saltMaxRef, 1.0) * 100;
    final satFatRatio =
        min((n.saturatedFat ?? 0) / ScoreConstants.saturatedFatMaxRef, 1.0) *
        100;

    return (sugarRatio * ScoreConstants.sugarWeight) +
        (saltRatio * ScoreConstants.saltWeight) +
        (satFatRatio * ScoreConstants.saturatedFatWeight);
  }

  double _calculateNutriFactor(NutrimentsEntity n, int? novaGroup) {
    final fiberScore =
        min((n.fiber ?? 0) / ScoreConstants.fiberExcellent, 1.0) * 100;
    final proteinScore =
        min((n.proteins ?? 0) / ScoreConstants.proteinExcellent, 1.0) * 100;
    final naturalness =
        ScoreConstants.novaNaturalness[novaGroup] ??
        ScoreConstants.novaUnknownNaturalness;

    return (fiberScore * ScoreConstants.fiberWeight) +
        (proteinScore * ScoreConstants.proteinWeight) +
        (naturalness * ScoreConstants.naturalnessWeight);
  }

  double _calculateIngredientQualityPenalty(String? ingredientsText) {
    if (ingredientsText == null || ingredientsText.trim().isEmpty) return 0.0;

    final text = ScoreConstants.normalizeTurkish(ingredientsText);
    final hasAddedSugar = ScoreConstants.addedSugarPatterns.any(text.contains);
    final hasRefinedFlour =
        ScoreConstants.refinedFlourPatterns.any(text.contains) ||
        RegExp(r'(^|[^a-z])un([^a-z]|$)').hasMatch(text);

    var penalty = 0.0;
    if (hasAddedSugar) penalty += ScoreConstants.addedSugarPenalty;
    if (hasRefinedFlour) penalty += ScoreConstants.refinedFlourPenalty;
    if (hasAddedSugar && hasRefinedFlour) {
      penalty += ScoreConstants.refinedCarbComboPenalty;
    }

    return min(penalty, ScoreConstants.ingredientQualityPenaltyCap);
  }
}
