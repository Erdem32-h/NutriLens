// NOVA group derivation.
//
// The fingerprints below are real `ingredients_text` values from the
// production `community_products` table, kept verbatim — including the German
// label on Falim and the OCR noise — because the derivation exists to survive
// exactly the mess the field produces. Against the 23 rows that carry a
// source-supplied NOVA group, this rule flags 15 of 15 group-4 rows and none
// of the 8 group-1/3 rows.
//
// A false positive is not free: a derived 4 caps the score at
// [ScoreConstants.ultraProcessedCeiling], so the negative cases here matter as
// much as the positive ones.

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/nova_derivation.dart';

void main() {
  int? derive(String? text, {List<String> tags = const []}) =>
      NovaDerivation.deriveNovaGroup(ingredientsText: text, additivesTags: tags);

  group('ultra-processed markers', () {
    test('colour E-code on a German label', () {
      // Falim gum. The text markers are all German — "Aromen", "Farbstoff" —
      // so the E-number is what actually carries this one.
      expect(
        derive(
          'Kaumasse, Säureregulator (E500), Aromen, Farbstoff (E171), '
          'Antioxidationsmittel (E320), Süßungsmittel (Acesulfam K)',
        ),
        4,
      );
    });

    test('"natural flavorings" in an otherwise plain tomato sauce', () {
      // Scored gauge 1 before the ceiling: nothing in the nutrition panel is
      // wrong with it, but the label is a formulation, not a kitchen.
      expect(
        derive(
          'Tomatoes and less than 2% of: sea salt, dehydrated onions, '
          'dehydrated garlic, spices, natural flavorings, sweetener',
        ),
        4,
      );
    });

    test('Turkish category word, no E-numbers written out', () {
      expect(
        derive(
          'İçindekiler: Tatlandırıcılar (sorbitoller, maltitoller, ksilitol, '
          'aspartam, asesülfam K, sukraloz), sakız mayası',
        ),
        4,
      );
    });

    test('reads the additive tags, not just the text', () {
      // A product can carry the additive as structured data while its
      // ingredient text says nothing useful.
      expect(derive('çikolata', tags: const ['en:e171']), 4);
    });

    test('lecithin (E322) counts even though it sits in the E3xx block', () {
      expect(derive('şeker, kakao yağı, emülgatör (E322)'), 4);
    });

    test('industrial substance with no additive number at all', () {
      expect(derive('ROASTED PEANUTS, SUGAR, HYDROGENATED VEGETABLE OIL'), 4);
    });
  });

  group('not enough evidence', () {
    // Every one of these carries a source NOVA group of 1 or 3 in production.
    const wholeFoods = <String, String>{
      'ayran': 'Yoğurt (pastorize inek sütü yoğurt mayası), tuz, su.',
      'ton balığı': 'tuna, sunflower oil, salt',
      'hardal': 'VINEGAR, WATER, MUSTARD SEED, SALT, TURMERIC, PAPRIKA.',
      'nohut makarnası': 'Organic chickpea flour, organic corn flour.',
      'fıstık': 'pistachios, sea salt',
      'parmesan': 'CRAFTED IN WISCONSIN FROM CULTURED MILK, ENZYMES, SALT.',
    };

    for (final entry in wholeFoods.entries) {
      test('${entry.key} is left unclassified', () {
        expect(derive(entry.value), isNull);
      });
    }

    test('preservatives and antioxidants alone are not ultra-processing', () {
      // E223 metabisulfite + E385 EDTA on tinned chickpeas, which Open Food
      // Facts itself files as group 3. Salting has a kitchen equivalent.
      expect(
        derive('PREPARED GARBANZO BEANS, WATER, SALT, SODIUM METABISULFITE'),
        isNull,
      );
    });

    test('baking soda (E500) alone is not ultra-processing', () {
      expect(derive('un, su, tuz, kabartma tozu (E500)'), isNull);
    });

    test('no text and no tags', () {
      expect(derive(null), isNull);
      expect(derive('   '), isNull);
    });
  });

  test('never claims a product is a whole food', () {
    // Only group 4 is ever derived. Absence of evidence is not evidence that
    // something came off a tree.
    for (final text in ['su', 'domates', 'siyah çay', '']) {
      expect(derive(text), anyOf(isNull, 4));
    }
    expect(derive('su'), isNull);
  });
}
