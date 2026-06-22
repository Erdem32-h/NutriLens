import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/share/domain/share_caption.dart';

void main() {
  const store = 'https://store.example/app';

  group('ShareCaption.forProduct', () {
    test('joins name, hp score and store with middots', () {
      final c = ShareCaption.forProduct(
        name: 'Sütaş Süt',
        hpScoreText: 'HP Skoru 82/100',
        scannedLabel: 'NutriLens ile tarandı',
        storeUrl: store,
      );
      expect(
        c,
        'Sütaş Süt — HP Skoru 82/100 · NutriLens ile tarandı · $store',
      );
    });

    test('omits the score segment when hpScoreText is null', () {
      final c = ShareCaption.forProduct(
        name: 'Sütaş Süt',
        hpScoreText: null,
        scannedLabel: 'NutriLens ile tarandı',
        storeUrl: store,
      );
      expect(c, 'Sütaş Süt · NutriLens ile tarandı · $store');
    });
  });

  group('ShareCaption.forMeal', () {
    test('joins food name, calories and store', () {
      final c = ShareCaption.forMeal(
        foodName: 'Mercimek Çorbası',
        calories: 240,
        calculatedLabel: 'NutriLens ile hesaplandı',
        storeUrl: store,
      );
      expect(
        c,
        'Mercimek Çorbası — 240 kcal · NutriLens ile hesaplandı · $store',
      );
    });
  });

  group('ShareCaption.forComparison', () {
    test('includes the healthier winner when one is set', () {
      final c = ShareCaption.forComparison(
        nameA: 'Süt A',
        nameB: 'Süt B',
        healthierName: 'Süt A',
        healthierLabel: 'Daha sağlıklı',
        comparedLabel: 'NutriLens ile karşılaştırıldı',
        storeUrl: store,
      );
      expect(
        c,
        'Süt A vs Süt B — Daha sağlıklı: Süt A · NutriLens ile karşılaştırıldı · $store',
      );
    });

    test('omits the winner segment when there is no clear winner', () {
      final c = ShareCaption.forComparison(
        nameA: 'A',
        nameB: 'B',
        healthierName: null,
        healthierLabel: 'Daha sağlıklı',
        comparedLabel: 'cmp',
        storeUrl: store,
      );
      expect(c, 'A vs B · cmp · $store');
    });
  });
}
