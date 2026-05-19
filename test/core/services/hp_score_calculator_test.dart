// HP Score regression + property-based test suite.
//
// Mixes two test styles deliberately:
//
// 1. **Fixed cases** — hand-crafted product fingerprints (Sarelle,
//    Tadelli, olive oil, almond butter, sugarless gum, palm-oil
//    product) with explicit expected gauge ranges. These act as a
//    living spec for the formula and catch accidental regressions
//    after future algorithm bumps (v3 → v4 etc.).
//
// 2. **Property-based** (`glados`) — generates thousands of random
//    inputs and asserts invariants that must always hold no matter
//    the values: score is in [0, 100], the algorithm version is
//    pinned to the current constant, critical ingredients always
//    short-circuit to gauge 5, and so on.
//
// The DB is an in-memory Drift instance with no additives seeded;
// that's intentional — these tests cover formula correctness, not
// the additive lookup table. `_getAdditiveRiskLevel` falls back to
// risk 3 when the e-code isn't in the DB, which keeps the chemical
// load math deterministic.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports test/expect/group from package:test which clashes
// with flutter_test. Hide the clashes; we only need Glados' generators
// and the `Glados(...).test(...)` instance method.
import 'package:glados/glados.dart'
    hide test, expect, group, setUp, tearDown, setUpAll, tearDownAll;
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/constants/score_constants.dart';
import 'package:nutrilens/core/services/hp_score_calculator.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  late AppDatabase db;
  late HpScoreCalculator calculator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    calculator = HpScoreCalculator(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Fixed-case fingerprints ──────────────────────────────────────

  group('fixed cases', () {
    test('Sarelle (kakaolu fındık ezmesi) → gauge 3+', () async {
      // Approximate nutrition panel: ~50 g sugar / 7 g satFat per 100g.
      // Has added sugar in ingredients but no palm oil.
      final result = await calculator.calculateFull(
        additivesTags: const ['en:e322'],
        nutriments: const NutrimentsEntity(
          energyKcal: 540,
          sugars: 50,
          saturatedFat: 7,
          fiber: 2,
          proteins: 6,
          salt: 0.05,
        ),
        novaGroup: 4,
        ingredientsText:
            'Şeker, fındık, kakao tozu, ayçiçek yağı, '
            'süt tozu, soya lesitini (E322), vanilin',
      );
      expect(
        result.gaugeLevel,
        greaterThanOrEqualTo(3),
        reason: 'sweet+fatty added-sugar product must score worse than gauge 2',
      );
      expect(result.hpScore, inInclusiveRange(0, 55));
    });

    test('Tadelli (sütlü çikolata) → gauge 3+', () async {
      final result = await calculator.calculateFull(
        additivesTags: const ['en:e322'],
        nutriments: const NutrimentsEntity(
          energyKcal: 550,
          sugars: 45,
          saturatedFat: 15,
          fiber: 2,
          proteins: 7,
        ),
        novaGroup: 4,
        ingredientsText:
            'Şeker, kakao yağı, süt tozu, kakao kitlesi, '
            'lesitin, vanilin',
      );
      expect(result.gaugeLevel, greaterThanOrEqualTo(3));
    });

    test('zeytinyağı (high satFat, no added sugar) → gauge 1', () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(
          energyKcal: 884,
          saturatedFat: 14,
          fat: 100,
        ),
        novaGroup: 2,
        ingredientsText: 'Sızma zeytinyağı',
      );
      expect(
        result.gaugeLevel,
        1,
        reason:
            'olive oil has no added sugar so the sweet-treat penalty '
            'must not trigger despite high satFat',
      );
    });

    test('badem ezmesi sade (no added sugar) → gauge 1-2', () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(
          energyKcal: 614,
          sugars: 4, // natural sugar from almonds
          saturatedFat: 4,
          fiber: 10,
          proteins: 21,
        ),
        novaGroup: 1,
        ingredientsText: '%100 badem',
      );
      expect(result.gaugeLevel, inInclusiveRange(1, 2));
    });

    test('Falım şekersiz sakız scores better than Sarelle', () async {
      // The user's mental model: sugarless gum should not be tied with a
      // sugar/fat-laden hazelnut spread. We assert the *relative*
      // ordering rather than a hard gauge — the absolute score for the
      // gum is sensitive to the additives DB (risk levels), which isn't
      // seeded in this test container.
      final falim = await calculator.calculateFull(
        additivesTags: const ['en:e420', 'en:e421', 'en:e950', 'en:e951'],
        nutriments: const NutrimentsEntity(energyKcal: 100),
        novaGroup: 4,
        ingredientsText:
            'Sakız bazı, sorbitol, mannitol, aspartam, '
            'asesülfam-K, aromalar',
      );
      final sarelle = await calculator.calculateFull(
        additivesTags: const ['en:e322'],
        nutriments: const NutrimentsEntity(
          energyKcal: 540,
          sugars: 50,
          saturatedFat: 7,
          fiber: 2,
          proteins: 6,
        ),
        novaGroup: 4,
        ingredientsText:
            'Şeker, fındık, kakao tozu, ayçiçek yağı, '
            'süt tozu, soya lesitini',
      );
      expect(
        falim.hpScore,
        greaterThan(sarelle.hpScore),
        reason: 'sugarless gum should be ranked above sweet spread',
      );
      expect(falim.gaugeLevel, lessThanOrEqualTo(sarelle.gaugeLevel));
    });

    test('palm yağı içeren ürün → instant gauge 5', () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(energyKcal: 500),
        ingredientsText: 'Buğday unu, palm yağı, şeker',
      );
      expect(result.gaugeLevel, 5);
      expect(result.hpScore, 10.0);
    });

    test('glikoz şurubu critical → instant gauge 5', () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(energyKcal: 400),
        ingredientsText: 'Şeker, glikoz şurubu, aroma',
      );
      expect(result.gaugeLevel, 5);
    });

    test('şeker + buğday unu kombinasyonu (Beypazarı kurusu tipi) → '
        'düşük score', () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(),
        ingredientsText: 'İçindekiler: buğday unu, şeker, maya, tuz',
      );
      expect(result.hpScore, lessThan(75));
      expect(result.gaugeLevel, greaterThan(1));
    });

    test('empty / minimal input → safe default', () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(),
      );
      expect(result.hpScore, inInclusiveRange(0, 100));
      expect(result.isPartial, isFalse);
    });
  });

  // ── Sweet-treat penalty regression (the v3 bump) ──────────────────

  group('sweet-treat penalty (v3)', () {
    test('hasAddedSugar AND sugar≥25 triggers penalty', () async {
      final without = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(
          energyKcal: 200,
          sugars: 26,
          saturatedFat: 0,
        ),
        ingredientsText: 'Süt, krema', // no added-sugar keyword
      );
      final withSugarKeyword = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(
          energyKcal: 200,
          sugars: 26,
          saturatedFat: 0,
        ),
        ingredientsText: 'Süt, krema, şeker',
      );
      // The "şeker" trigger + sugar≥25 must shave at least the sweet-treat
      // penalty off the score. Allow small float wiggle.
      final delta = without.hpScore - withSugarKeyword.hpScore;
      expect(
        delta,
        greaterThanOrEqualTo(ScoreConstants.sweetTreatPenalty - 0.1),
      );
    });

    test('hasAddedSugar AND satFat≥8 also triggers penalty', () async {
      final without = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(
          energyKcal: 300,
          sugars: 5,
          saturatedFat: 10,
        ),
        ingredientsText: 'Süt, tereyağı',
      );
      final withSugar = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(
          energyKcal: 300,
          sugars: 5,
          saturatedFat: 10,
        ),
        ingredientsText: 'Süt, tereyağı, şeker',
      );
      expect(
        without.hpScore - withSugar.hpScore,
        greaterThanOrEqualTo(ScoreConstants.sweetTreatPenalty - 0.1),
      );
    });

    test(
      'no added sugar → penalty does NOT trigger even at high values',
      () async {
        // High sugar AND high satFat but no "şeker"/"sugar" in ingredients
        // (purely natural sugars from milk, for example). The sweet-treat
        // gate is `hasAddedSugar`, so this should be untouched by the v3
        // penalty branch.
        final result = await calculator.calculateFull(
          additivesTags: const [],
          nutriments: const NutrimentsEntity(
            energyKcal: 600,
            sugars: 40,
            saturatedFat: 12,
          ),
          ingredientsText: 'Süt, tereyağı, fındık',
        );
        // The risk factor will still hurt the score, but no IQP gets added.
        // We assert that score is HIGHER than the same nutrients WITH
        // "şeker" added.
        final withSugar = await calculator.calculateFull(
          additivesTags: const [],
          nutriments: const NutrimentsEntity(
            energyKcal: 600,
            sugars: 40,
            saturatedFat: 12,
          ),
          ingredientsText: 'Süt, tereyağı, fındık, şeker',
        );
        expect(result.hpScore, greaterThan(withSugar.hpScore));
      },
    );
  });

  // ── Algorithm version pin ─────────────────────────────────────────

  group('versioning', () {
    test('current version constant is 3', () {
      // Tripwire: if you bump the version without updating the sweet-
      // treat Supabase trigger and the local-cache invalidation path,
      // history scores will silently disagree across server/client.
      // Bump this expected value in lockstep with the migration.
      expect(ScoreConstants.hpScoreAlgorithmVersion, 3);
    });
  });

  // ── Property-based invariants ────────────────────────────────────

  group('property: result invariants', () {
    Glados2<int, int>(any.intInRange(0, 800), any.intInRange(0, 100)).test(
      'score stays in [0, 100] for arbitrary kcal+sugar',
      (kcal, sugars) async {
        final result = await calculator.calculateFull(
          additivesTags: const [],
          nutriments: NutrimentsEntity(
            energyKcal: kcal.toDouble(),
            sugars: sugars.toDouble(),
          ),
        );
        expect(result.hpScore, inInclusiveRange(0, 100));
        expect(result.gaugeLevel, inInclusiveRange(1, 5));
      },
    );

    Glados(any.intInRange(0, 50)).test(
      'critical ingredient ALWAYS short-circuits to 10 regardless of other inputs',
      (sugars) async {
        final result = await calculator.calculateFull(
          additivesTags: const [],
          nutriments: NutrimentsEntity(
            energyKcal: 100,
            sugars: sugars.toDouble(),
          ),
          ingredientsText: 'Tam buğday unu, palm yağı, vitamin',
        );
        expect(result.hpScore, 10.0);
        expect(result.gaugeLevel, 5);
      },
    );

    Glados(any.intInRange(1, 6)).test(
      'nova group 1-5 maps to non-null nutri factor',
      (novaGroup) async {
        final result = await calculator.calculateFull(
          additivesTags: const [],
          nutriments: const NutrimentsEntity(fiber: 3, proteins: 5),
          novaGroup: novaGroup,
        );
        expect(result.nutriFactor, isNotNull);
        expect(result.nutriFactor!, inInclusiveRange(0, 100));
      },
    );

    Glados(any.list(any.letterOrDigits)).test(
      'any additivesTags list produces non-null chemicalLoad in [0,100]',
      (tags) async {
        final result = await calculator.calculateFull(
          additivesTags: tags,
          nutriments: const NutrimentsEntity(),
        );
        expect(result.chemicalLoad, inInclusiveRange(0, 100));
      },
    );
  });

  // ── Pure helpers ──────────────────────────────────────────────────

  group('static helpers', () {
    test('normalizeECode handles common variants', () {
      expect(HpScoreCalculator.normalizeECode('en:e471'), 'E471');
      expect(HpScoreCalculator.normalizeECode('E 471'), 'E471');
      expect(HpScoreCalculator.normalizeECode('e-471'), 'E471');
      expect(HpScoreCalculator.normalizeECode('E471'), 'E471');
      expect(HpScoreCalculator.normalizeECode('E150d'), 'E150d');
    });

    test('extractECodesFromText finds inline codes', () {
      final codes = HpScoreCalculator.extractECodesFromText(
        'Şeker, su, E330, koruyucu (E211), aroma e621',
      );
      expect(codes, containsAll(['E330', 'E211', 'E621']));
    });

    test('extractECodesFromText handles empty/null input', () {
      expect(HpScoreCalculator.extractECodesFromText(null), isEmpty);
      expect(HpScoreCalculator.extractECodesFromText(''), isEmpty);
    });

    test('calculatePartial only fills chemical_load slot', () async {
      final result = await calculator.calculatePartial(
        additivesTags: const ['en:e211', 'en:e330'],
      );
      expect(result.isPartial, isTrue);
      expect(result.riskFactor, isNull);
      expect(result.nutriFactor, isNull);
      expect(result.chemicalLoad, greaterThan(0));
    });
  });
}
