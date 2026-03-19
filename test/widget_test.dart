import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens/core/constants/score_constants.dart';

void main() {
  group('ScoreConstants', () {
    test('hpToGauge returns correct gauge for each threshold', () {
      expect(ScoreConstants.hpToGauge(100), 1);
      expect(ScoreConstants.hpToGauge(80), 1);
      expect(ScoreConstants.hpToGauge(79), 2);
      expect(ScoreConstants.hpToGauge(60), 2);
      expect(ScoreConstants.hpToGauge(59), 3);
      expect(ScoreConstants.hpToGauge(40), 3);
      expect(ScoreConstants.hpToGauge(39), 4);
      expect(ScoreConstants.hpToGauge(20), 4);
      expect(ScoreConstants.hpToGauge(19), 5);
      expect(ScoreConstants.hpToGauge(0), 5);
    });
  });
}
