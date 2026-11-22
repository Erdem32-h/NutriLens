import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/nutrient_guide/data/nutrient_parser.dart';
import 'package:nutrilens/features/nutrient_guide/domain/entities/nutrient_entity.dart';

Map<String, dynamic> _entry({
  String id = 'vitamin_c',
  String category = 'vitamin',
  Map<String, dynamic>? overrides,
}) {
  final base = <String, dynamic>{
    'id': id,
    'category': category,
    'name_tr': 'C Vitamini',
    'name_en': 'Vitamin C',
    'function_tr': 'Bağışıklığı destekler.',
    'function_en': 'Supports immunity.',
    'deficiency_tr': ['Yorgunluk', 'Diş eti kanaması'],
    'deficiency_en': ['Fatigue', 'Bleeding gums'],
    'excess_tr': ['Mide bulantısı', 'İshal'],
    'excess_en': ['Nausea', 'Diarrhea'],
    'sources_tr': ['Portakal', 'Biber', 'Kivi'],
    'sources_en': ['Orange', 'Pepper', 'Kiwi'],
    'daily_need': '75–90 mg',
    'upper_limit': '2000 mg',
    'source': 'NIH ODS',
  };
  if (overrides != null) base.addAll(overrides);
  return base;
}

String _doc(List<Map<String, dynamic>> entries) => jsonEncode({
  'version': '1.0',
  'updated_at': '2026-11-23',
  'nutrients': entries,
});

void main() {
  group('parseNutrients', () {
    test('parses a complete entry', () {
      final list = parseNutrients(_doc([_entry()]));
      final n = list.single;
      expect(n.id, 'vitamin_c');
      expect(n.category, NutrientCategory.vitamin);
      expect(n.name.tr, 'C Vitamini');
      expect(n.deficiency.en.length, 2);
      expect(n.upperLimit, '2000 mg');
      expect(n.source, 'NIH ODS');
    });

    test('maps amino_acid category', () {
      final list = parseNutrients(
        _doc([_entry(id: 'lysine', category: 'amino_acid')]),
      );
      expect(list.single.category, NutrientCategory.aminoAcid);
    });

    test('altName is null when absent', () {
      final list = parseNutrients(_doc([_entry()]));
      expect(list.single.altName, isNull);
    });

    test('altName is parsed when both languages are present', () {
      final list = parseNutrients(
        _doc([
          _entry(
            overrides: {
              'alt_name_tr': 'Askorbik asit',
              'alt_name_en': 'Ascorbic acid',
            },
          ),
        ]),
      );
      expect(list.single.altName?.tr, 'Askorbik asit');
      expect(list.single.altName?.en, 'Ascorbic acid');
    });

    test('upperLimit is null when absent', () {
      final e = _entry()..remove('upper_limit');
      expect(parseNutrients(_doc([e])).single.upperLimit, isNull);
    });

    test('Localized.of falls back to en for non-tr locales', () {
      const l = Localized<String>(tr: 'tr değer', en: 'en value');
      expect(l.of('tr'), 'tr değer');
      expect(l.of('en'), 'en value');
      expect(l.of('ar'), 'en value');
      expect(l.of('zh'), 'en value');
      expect(l.of('es'), 'en value');
    });

    test('throws FormatException on malformed json', () {
      expect(() => parseNutrients('{not json'), throwsFormatException);
    });

    test('throws FormatException naming the id when a field is missing', () {
      final e = _entry(id: 'broken_one')..remove('function_en');
      expect(
        () => parseNutrients(_doc([e])),
        throwsA(
          isA<FormatException>().having(
            (x) => x.message,
            'message',
            contains('broken_one'),
          ),
        ),
      );
    });

    test('throws FormatException naming the id when a list is empty', () {
      final e = _entry(
        id: 'empty_list',
        overrides: {'deficiency_tr': <String>[]},
      );
      expect(
        () => parseNutrients(_doc([e])),
        throwsA(
          isA<FormatException>().having(
            (x) => x.message,
            'message',
            contains('empty_list'),
          ),
        ),
      );
    });

    test('throws FormatException on empty string field', () {
      final e = _entry(overrides: {'source': '  '});
      expect(() => parseNutrients(_doc([e])), throwsFormatException);
    });

    test('throws FormatException on unknown category', () {
      final e = _entry(category: 'herb');
      expect(() => parseNutrients(_doc([e])), throwsFormatException);
    });

    test('throws FormatException on duplicate ids', () {
      expect(
        () => parseNutrients(_doc([_entry(), _entry()])),
        throwsFormatException,
      );
    });

    test(
      'throws FormatException when only one alt_name language is present',
      () {
        final e = _entry(overrides: {'alt_name_tr': 'Askorbik asit'});
        expect(() => parseNutrients(_doc([e])), throwsFormatException);
      },
    );
  });
}
