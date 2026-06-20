import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/data/mappers/category_mapper.dart';

void main() {
  group('CategoryMapper.fromOffTags', () {
    test('maps milk tags to sut', () {
      expect(CategoryMapper.fromOffTags(['en:dairies', 'en:milks']), 'sut');
    });
    test('maps yogurt before generic dairy', () {
      expect(
        CategoryMapper.fromOffTags(['en:dairies', 'en:fermented-foods', 'en:yogurts']),
        'yogurt',
      );
    });
    test('maps biscuit/cookie tags to biskuvi', () {
      expect(
        CategoryMapper.fromOffTags(['en:biscuits-and-cakes', 'en:biscuits']),
        'biskuvi',
      );
    });
    test('maps sodas to gazli_icecek', () {
      expect(CategoryMapper.fromOffTags(['en:beverages', 'en:sodas']), 'gazli_icecek');
    });
    test('returns null for empty', () {
      expect(CategoryMapper.fromOffTags(const []), isNull);
    });
    test('returns null for unmatched', () {
      expect(CategoryMapper.fromOffTags(['en:unicorn-food']), isNull);
    });
  });
}
