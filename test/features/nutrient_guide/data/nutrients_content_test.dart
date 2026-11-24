import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/nutrient_guide/data/nutrient_parser.dart';
import 'package:nutrilens/features/nutrient_guide/domain/entities/nutrient_entity.dart';

/// Guards the shipped content file (`assets/nutrients/nutrients.json`), not
/// the parser: a malformed or incomplete entry fails here before release.
void main() {
  late List<NutrientEntity> all;

  setUpAll(() {
    all = parseNutrients(
      File('assets/nutrients/nutrients.json').readAsStringSync(),
    );
  });

  test('every nutrient carries its required fields in tr and en', () {
    for (final n in all) {
      expect(n.source.trim(), isNotEmpty, reason: '${n.id} source');
      if (n.category != NutrientCategory.aminoAcid ||
          n.aminoClass == AminoAcidClass.essential) {
        expect(n.dailyNeed?.trim(), isNotEmpty, reason: '${n.id} daily_need');
      }
      expect(n.name.tr.trim(), isNotEmpty, reason: '${n.id} name_tr');
      expect(n.name.en.trim(), isNotEmpty, reason: '${n.id} name_en');
      expect(n.function.tr.trim(), isNotEmpty, reason: '${n.id} function_tr');
      expect(n.function.en.trim(), isNotEmpty, reason: '${n.id} function_en');
      expect(
        n.deficiency.tr.length,
        n.deficiency.en.length,
        reason: '${n.id} deficiency parity',
      );
      expect(
        n.excess.tr.length,
        n.excess.en.length,
        reason: '${n.id} excess parity',
      );
      expect(
        n.sources.tr.length,
        n.sources.en.length,
        reason: '${n.id} sources parity',
      );
    }
  });

  test('ids are unique', () {
    expect(all.map((n) => n.id).toSet().length, all.length);
  });

  test('expected number of entries per category', () {
    int count(NutrientCategory c) => all.where((n) => n.category == c).length;
    expect(count(NutrientCategory.vitamin), 13);
    expect(count(NutrientCategory.mineral), 14);
    expect(count(NutrientCategory.aminoAcid), 20);
  });

  test('amino acids split 9 essential / 6 conditional / 5 non-essential', () {
    int count(AminoAcidClass c) => all.where((n) => n.aminoClass == c).length;
    expect(count(AminoAcidClass.essential), 9);
    expect(count(AminoAcidClass.conditional), 6);
    expect(count(AminoAcidClass.nonEssential), 5);
  });

  test('every amino acid is fully translated into all six languages', () {
    // The 11 amino acids added later must not silently fall back to
    // English in es/pt/ar/zh like an untranslated entry would.
    for (final n in all.where((n) => n.category == NutrientCategory.aminoAcid)) {
      for (final l in [n.name, n.function]) {
        expect([l.es, l.pt, l.ar, l.zh], everyElement(isNotNull),
            reason: n.id);
      }
      for (final l in [n.deficiency, n.excess, n.sources]) {
        expect([l.es, l.pt, l.ar, l.zh], everyElement(isNotNull),
            reason: n.id);
        for (final t in [l.es, l.pt, l.ar, l.zh]) {
          expect(t!.length, l.en.length, reason: '${n.id} list parity');
        }
      }
    }
  });
}
