import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/constants/ad_constants.dart';

void main() {
  group('AdConstants.adRequest', () {
    // This is a compliance test, not a behaviour test. The App Store privacy
    // declaration answers "No" to Apple's tracking question, which is only
    // truthful while ad requests stay non-personalized. If someone flips this
    // for ad revenue, the store answer becomes false — so the flip has to be a
    // deliberate act that also updates the declaration, not a silent edit.
    test('requests non-personalized ads', () {
      expect(AdConstants.adRequest.nonPersonalizedAds, isTrue);
    });
  });
}
