import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/utils/gs1_digital_link.dart';

void main() {
  group('Gs1DigitalLink.tryParse', () {
    test('plain GTIN-14 with leading zero → 13 digits', () {
      final link =
          Gs1DigitalLink.tryParse('https://id.example.com/01/08690504000013');
      expect(link, isNotNull);
      expect(link!.gtin, '8690504000013');
      expect(link.lot, isNull);
      expect(link.expiry, isNull);
    });

    test('prefixed path, encoded lot, expiry', () {
      final link = Gs1DigitalLink.tryParse(
          'https://x.io/p/01/08690504000013/10/LOT%2042?17=271231');
      expect(link!.gtin, '8690504000013');
      expect(link.lot, 'LOT 42');
      expect(link.expiry, DateTime(2027, 12, 31));
    });

    test('13-digit GTIN kept', () {
      expect(Gs1DigitalLink.tryParse('https://x.io/01/8690504000013')!.gtin,
          '8690504000013');
    });

    test('gtin14 without leading zero', () {
      expect(Gs1DigitalLink.tryParse('https://x.io/01/18690504000010')!.gtin,
          '18690504000010');
    });

    test('dd 00 means last day of month', () {
      expect(
          Gs1DigitalLink.tryParse('https://x.io/01/8690504000013?17=271200')!
              .expiry,
          DateTime(2027, 12, 31));
      expect(
          Gs1DigitalLink.tryParse('https://x.io/01/8690504000013?17=270200')!
              .expiry,
          DateTime(2027, 2, 28));
    });

    test('extra params and trailing slash', () {
      final link = Gs1DigitalLink.tryParse(
          'HTTPS://X.IO/01/08690504000013/?utm=a&17=270101');
      expect(link!.gtin, '8690504000013');
      expect(link.expiry, DateTime(2027, 1, 1));
    });

    test('bad percent encoding → lot null', () {
      final link =
          Gs1DigitalLink.tryParse('https://x.io/01/8690504000013/10/%E0%A4%A');
      expect(link, isNotNull);
      expect(link!.lot, isNull);
    });

    test('invalid expiry → null expiry, link kept', () {
      final link =
          Gs1DigitalLink.tryParse('https://x.io/01/8690504000013?17=271340');
      expect(link!.expiry, isNull);
      expect(
          Gs1DigitalLink.tryParse('https://x.io/01/8690504000013?17=270231')!
              .expiry,
          isNull);
    });

    test('rejects non-GS1 input', () {
      for (final raw in [
        'http://x.io/01/08690504000013',
        'https://x.io/01/08690504000014',
        'https://example.com/menu',
        'https://x.io/01/abc',
        'https://x.io/01',
        '8690504000013',
        '',
      ]) {
        expect(Gs1DigitalLink.tryParse(raw), isNull, reason: raw);
      }
    });
  });
}
