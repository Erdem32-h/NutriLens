import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/nutrition_ocr_service.dart';

void main() {
  group('NutritionOcrService.parseNutritionText', () {
    test('parses nutrition values when ML Kit splits labels and values', () {
      final service = NutritionOcrService();

      final result = service.parseNutritionText('''
Besin Değerleri
100 g için
Enerji
1834 kJ / 438 kcal
Yağ
16 g
Doymuş Yağ
6,4 g
Karbonhidrat
63 g
Şekerler
31 g
Protein
7,5 g
Tuz
0,42 g
''');

      expect(result, isNotNull);
      expect(result!.energyKcal, 438);
      expect(result.fat, 16);
      expect(result.saturatedFat, 6.4);
      expect(result.carbohydrates, 63);
      expect(result.sugars, 31);
      expect(result.protein, 7.5);
      expect(result.salt, 0.42);
    });

    test(
      'parses nutrition values when ML Kit emits label and value columns separately',
      () {
        final service = NutritionOcrService();

        final result = service.parseNutritionText('''
Besin Degerleri
Enerji
Yag
Doymus Yag
Karbonhidrat
Sekerler
Protein
Tuz
100 g
438 kcal
16 g
6,4 g
63 g
31 g
7,5 g
0,42 g
''');

        expect(result, isNotNull);
        expect(result!.energyKcal, 438);
        expect(result.fat, 16);
        expect(result.saturatedFat, 6.4);
        expect(result.carbohydrates, 63);
        expect(result.sugars, 31);
        expect(result.protein, 7.5);
        expect(result.salt, 0.42);
      },
    );
  });
}
