// Barcode validator boundary tests.
//
// Two angles:
//   1. Hand-picked real-world GTINs from the project history (Nutella,
//      Coca-Cola TR, the BIM Fındık İçi case that surfaced the typo
//      bug). These guard against regressions in the mod-10 algorithm.
//   2. `glados` property-based tests for invariants — empty rejected,
//      URL-shaped rejected, random non-numeric strings of QR-like
//      length accepted.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide test, expect, group, setUp, tearDown, setUpAll, tearDownAll;
import 'package:nutrilens/core/utils/barcode_validator.dart';

void main() {
  group('hasValidGtinCheckDigit', () {
    test('accepts known-good EAN-13s', () {
      expect(
        BarcodeValidator.hasValidGtinCheckDigit('8695077002334'),
        isTrue,
        reason: 'Simbat Kavrulmuş Fındık İçi (real TR product)',
      );
      expect(
        BarcodeValidator.hasValidGtinCheckDigit('8000500310427'),
        isTrue,
        reason: 'Nutella 350g (Ferrero)',
      );
      expect(
        BarcodeValidator.hasValidGtinCheckDigit('5449000000996'),
        isTrue,
        reason: 'Coca-Cola 330ml',
      );
    });

    test('accepts EAN-8 and UPC-A', () {
      expect(BarcodeValidator.hasValidGtinCheckDigit('73513537'), isTrue);
      expect(
        BarcodeValidator.hasValidGtinCheckDigit('036000291452'),
        isTrue,
        reason: 'UPC-A Kleenex tissues',
      );
    });

    test('rejects EAN-13 with wrong check digit', () {
      // Tamper with the last digit of a known-good GTIN.
      expect(BarcodeValidator.hasValidGtinCheckDigit('8695077002335'), isFalse);
      expect(BarcodeValidator.hasValidGtinCheckDigit('8000500310428'), isFalse);
    });

    test('rejects non-digit input', () {
      expect(BarcodeValidator.hasValidGtinCheckDigit('86950770ABCD4'), isFalse);
      expect(BarcodeValidator.hasValidGtinCheckDigit(''), isFalse);
      expect(BarcodeValidator.hasValidGtinCheckDigit('1'), isFalse);
    });
  });

  group('isLikelyBarcode', () {
    test('rejects URL-shaped values', () {
      expect(BarcodeValidator.isLikelyBarcode('https://example.com'), isFalse);
      expect(BarcodeValidator.isLikelyBarcode('http://x'), isFalse);
      expect(BarcodeValidator.isLikelyBarcode('www.example.com'), isFalse);
      expect(BarcodeValidator.isLikelyBarcode('path/with/slash'), isFalse);
    });

    test('rejects empty', () {
      expect(BarcodeValidator.isLikelyBarcode(''), isFalse);
    });

    test('accepts plain text payloads (QR codes carry these)', () {
      expect(BarcodeValidator.isLikelyBarcode('SOME-TEXT-123'), isTrue);
      expect(BarcodeValidator.isLikelyBarcode('8695077002334'), isTrue);
    });
  });

  group('isValidBarcode', () {
    test('rejects URLs even with valid GTIN-like digit count', () {
      expect(
        BarcodeValidator.isValidBarcode('https://8695077002334'),
        isFalse,
        reason: 'URLs are rejected before check-digit logic runs',
      );
    });

    test('accepts arbitrary text at non-GTIN lengths', () {
      expect(BarcodeValidator.isValidBarcode('ABC123XYZ'), isTrue);
      // 13 chars of mixed text — not a numeric GTIN, accepted.
      expect(BarcodeValidator.isValidBarcode('ABCDEFGHIJKLM'), isTrue);
    });

    test('the real-world TR case from session history', () {
      // The bug case: user scanned 8695077002334 (real label),
      // the wrong barcode 8525077002334 was previously stored in the
      // community DB. Both are valid GTINs (coincidence), so the
      // validator does NOT catch this specific collision — and that
      // honesty is part of the contract.
      expect(BarcodeValidator.isValidBarcode('8695077002334'), isTrue);
      expect(
        BarcodeValidator.isValidBarcode('8525077002334'),
        isTrue,
        reason:
            'documented limitation: validator only catches '
            'check-digit-invalid scrambles, not collisions',
      );
    });

    test('rejects numeric strings of GTIN length with bad check digit', () {
      expect(BarcodeValidator.isValidBarcode('8695077002335'), isFalse);
      expect(BarcodeValidator.isValidBarcode('8695077002330'), isFalse);
    });

    test('is not degenerate — both accepts and rejects fire across inputs', () {
      // Sanity that the validator isn't always-true or always-false.
      // 13-digit strings: ~10% of random ones should pass the mod-10
      // check by chance, so we just assert both buckets are non-empty.
      var accepted = 0;
      var rejected = 0;
      for (var n = 0; n < 200; n++) {
        // Pseudo-random 13 digits derived from `n` — varied enough to
        // hit both branches without depending on Random's seed.
        final digits = List.generate(
          13,
          (i) => ((n * 31 + i * 17) ~/ (i + 1)) % 10,
        );
        final s = digits.join();
        if (BarcodeValidator.isValidBarcode(s)) {
          accepted++;
        } else {
          rejected++;
        }
      }
      expect(
        accepted,
        greaterThan(0),
        reason: 'some random strings should coincide with valid checksums',
      );
      expect(
        rejected,
        greaterThan(0),
        reason: 'most random strings should fail the check digit',
      );
    });
  });

  group('property invariants', () {
    Glados(any.list(any.intInRange(0, 9))).test(
      'random numeric string of length 13 → valid iff check digit matches',
      (digitsList) {
        if (digitsList.length != 13) return; // glados shrinks lengths
        final s = digitsList.join();
        // Recompute the check digit and assert validator agrees.
        var sum = 0;
        for (var i = 0; i < 12; i++) {
          final d = digitsList[11 - i];
          sum += d * (i.isEven ? 3 : 1);
        }
        final expectedCheck = (10 - (sum % 10)) % 10;
        final actualCheck = digitsList.last;
        expect(
          BarcodeValidator.hasValidGtinCheckDigit(s),
          expectedCheck == actualCheck,
        );
      },
    );
  });
}
