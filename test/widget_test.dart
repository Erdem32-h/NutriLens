import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens/core/constants/score_constants.dart';

void main() {
  group('ScoreConstants', () {
    test('hpToGauge returns correct gauge for each threshold', () {
      expect(ScoreConstants.hpToGauge(100), 1);
      expect(ScoreConstants.hpToGauge(75), 1);
      expect(ScoreConstants.hpToGauge(74), 2);
      expect(ScoreConstants.hpToGauge(55), 2);
      expect(ScoreConstants.hpToGauge(54), 3);
      expect(ScoreConstants.hpToGauge(35), 3);
      expect(ScoreConstants.hpToGauge(34), 4);
      expect(ScoreConstants.hpToGauge(18), 4);
      expect(ScoreConstants.hpToGauge(17), 5);
      expect(ScoreConstants.hpToGauge(0), 5);
    });
  });
}
