import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/constants/score_constants.dart';

void main() {
  group('ScoreConstants', () {
    group('static weights', () {
      test('HP formula weights sum to 1.0', () {
        final sum = ScoreConstants.chemicalWeight +
            ScoreConstants.riskWeight +
            ScoreConstants.nutriWeight;

        expect(sum, closeTo(1.0, 0.001));
      });

      test('risk factor sub-weights sum to 1.0', () {
        final sum = ScoreConstants.sugarWeight +
            ScoreConstants.saltWeight +
            ScoreConstants.saturatedFatWeight;

        expect(sum, closeTo(1.0, 0.001));
      });

      test('nutri factor sub-weights sum to 1.0', () {
        final sum = ScoreConstants.fiberWeight +
            ScoreConstants.proteinWeight +
            ScoreConstants.naturalnessWeight;

        expect(sum, closeTo(1.0, 0.001));
      });
    });

    group('additivePenalties', () {
      test('has entries for risk levels 1 through 5', () {
        expect(ScoreConstants.additivePenalties.length, 5);
        for (var i = 1; i <= 5; i++) {
          expect(ScoreConstants.additivePenalties.containsKey(i), isTrue);
        }
      });

      test('penalties increase with risk level', () {
        for (var i = 1; i < 5; i++) {
          expect(
            ScoreConstants.additivePenalties[i + 1]!,
            greaterThan(ScoreConstants.additivePenalties[i]!),
          );
        }
      });

      test('safe (level 1) has zero penalty', () {
        expect(ScoreConstants.additivePenalties[1], 0.0);
      });
    });

    group('novaNaturalness', () {
      test('has entries for NOVA groups 1 through 4', () {
        expect(ScoreConstants.novaNaturalness.length, 4);
        for (var i = 1; i <= 4; i++) {
          expect(ScoreConstants.novaNaturalness.containsKey(i), isTrue);
        }
      });

      test('NOVA 1 has highest naturalness (100)', () {
        expect(ScoreConstants.novaNaturalness[1], 100.0);
      });

      test('NOVA 4 has lowest naturalness (0)', () {
        expect(ScoreConstants.novaNaturalness[4], 0.0);
      });

      test('naturalness decreases with NOVA group', () {
        for (var i = 1; i < 4; i++) {
          expect(
            ScoreConstants.novaNaturalness[i]!,
            greaterThan(ScoreConstants.novaNaturalness[i + 1]!),
          );
        }
      });
    });

    group('hpToGauge', () {
      // Thresholds: gauge1=75, gauge2=55, gauge3=35, gauge4=18
      test('returns 1 for HP >= 75', () {
        expect(ScoreConstants.hpToGauge(100), 1);
        expect(ScoreConstants.hpToGauge(75), 1);
        expect(ScoreConstants.hpToGauge(95.5), 1);
      });

      test('returns 2 for 55 <= HP < 75', () {
        expect(ScoreConstants.hpToGauge(74.9), 2);
        expect(ScoreConstants.hpToGauge(74), 2);
        expect(ScoreConstants.hpToGauge(55), 2);
        expect(ScoreConstants.hpToGauge(65.0), 2);
      });

      test('returns 3 for 35 <= HP < 55', () {
        expect(ScoreConstants.hpToGauge(54.9), 3);
        expect(ScoreConstants.hpToGauge(54), 3);
        expect(ScoreConstants.hpToGauge(35), 3);
        expect(ScoreConstants.hpToGauge(45.0), 3);
      });

      test('returns 4 for 18 <= HP < 35', () {
        expect(ScoreConstants.hpToGauge(34.9), 4);
        expect(ScoreConstants.hpToGauge(34), 4);
        expect(ScoreConstants.hpToGauge(18), 4);
        expect(ScoreConstants.hpToGauge(25.0), 4);
      });

      test('returns 5 for HP < 18', () {
        expect(ScoreConstants.hpToGauge(17.9), 5);
        expect(ScoreConstants.hpToGauge(17), 5);
        expect(ScoreConstants.hpToGauge(0), 5);
        expect(ScoreConstants.hpToGauge(10.0), 5);
      });

      test('handles exact boundary values', () {
        expect(ScoreConstants.hpToGauge(75.0), 1);
        expect(ScoreConstants.hpToGauge(55.0), 2);
        expect(ScoreConstants.hpToGauge(35.0), 3);
        expect(ScoreConstants.hpToGauge(18.0), 4);
      });

      test('handles negative values', () {
        expect(ScoreConstants.hpToGauge(-1.0), 5);
        expect(ScoreConstants.hpToGauge(-100.0), 5);
      });

      test('handles values above 100', () {
        expect(ScoreConstants.hpToGauge(150.0), 1);
      });
    });

    group('reference values', () {
      test('sugar max ref is positive', () {
        expect(ScoreConstants.sugarMaxRef, greaterThan(0));
      });

      test('salt max ref is positive', () {
        expect(ScoreConstants.saltMaxRef, greaterThan(0));
      });

      test('saturated fat max ref is positive', () {
        expect(ScoreConstants.saturatedFatMaxRef, greaterThan(0));
      });

      test('fiber excellent is positive', () {
        expect(ScoreConstants.fiberExcellent, greaterThan(0));
      });

      test('protein excellent is positive', () {
        expect(ScoreConstants.proteinExcellent, greaterThan(0));
      });
    });

    group('gauge thresholds', () {
      test('thresholds are in descending order', () {
        expect(ScoreConstants.gauge1Threshold,
            greaterThan(ScoreConstants.gauge2Threshold));
        expect(ScoreConstants.gauge2Threshold,
            greaterThan(ScoreConstants.gauge3Threshold));
        expect(ScoreConstants.gauge3Threshold,
            greaterThan(ScoreConstants.gauge4Threshold));
      });
    });
  });
}
