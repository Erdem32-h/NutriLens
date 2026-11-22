import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/nutrient_guide/domain/entities/nutrient_entity.dart';
import 'package:nutrilens/features/nutrient_guide/domain/nutrient_search.dart';

NutrientEntity _n(
  String id,
  String tr,
  String en, {
  String? altTr,
  String? altEn,
}) {
  const one = Localized<List<String>>(tr: ['x'], en: ['x']);
  return NutrientEntity(
    id: id,
    category: NutrientCategory.mineral,
    name: Localized(tr: tr, en: en),
    altName: altTr == null ? null : Localized(tr: altTr, en: altEn ?? altTr),
    function: const Localized(tr: 'a', en: 'a'),
    deficiency: one,
    excess: one,
    sources: one,
    dailyNeed: '1 mg',
    upperLimit: null,
    source: 'NIH ODS',
  );
}

void main() {
  final iodine = _n('iodine', 'İyot', 'Iodine');
  final selenium = _n('selenium', 'Selenyum', 'Selenium');
  final milkThing = _n(
    'x',
    'Kalsiyum',
    'Calcium',
    altTr: 'Süt mineralı',
    altEn: 'Milk mineral',
  );
  final all = [iodine, selenium, milkThing];

  group('foldForSearch', () {
    test('İ, I and ı all fold to i', () {
      expect(foldForSearch('İYOT'), foldForSearch('iyot'));
      expect(foldForSearch('IYOT'), foldForSearch('iyot'));
      expect(foldForSearch('ığüöşç'), 'iguosc');
    });

    test('uppercase Turkish letters fold like lowercase ones', () {
      expect(foldForSearch('ŞEKER'), 'seker');
      expect(foldForSearch('Süt'), 'sut');
    });
  });

  group('searchNutrients', () {
    test('"iyot" finds İyot', () {
      expect(searchNutrients(all, 'iyot', 'tr'), [iodine]);
    });

    test('"selenyum" finds Selenyum', () {
      expect(searchNutrients(all, 'selenyum', 'tr'), [selenium]);
    });

    test('"sut" finds an entry through its alt name', () {
      expect(searchNutrients(all, 'sut', 'tr'), [milkThing]);
    });

    test('blank query returns everything in the same order', () {
      expect(searchNutrients(all, '', 'tr'), all);
      expect(searchNutrients(all, '   ', 'tr'), all);
    });

    test('no match returns an empty list', () {
      expect(searchNutrients(all, 'zzz', 'tr'), isEmpty);
    });

    test('en searches English names, not Turkish ones', () {
      expect(searchNutrients(all, 'iodine', 'en'), [iodine]);
      expect(searchNutrients(all, 'iyot', 'en'), isEmpty);
    });
  });
}
