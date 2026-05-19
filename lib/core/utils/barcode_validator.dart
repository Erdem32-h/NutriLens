/// Barcode validation utilities — extracted from `scanner_screen.dart`
/// so they can be unit-tested without spinning up a Flutter widget tree.
///
/// Two layers of validation:
///   • [isLikelyBarcode] — rejects obvious non-barcode payloads (URLs,
///     paths) that a QR code reader might decode but that would break
///     the `/product/<barcode>` route.
///   • [hasValidGtinCheckDigit] — GS1 mod-10 check digit validation,
///     valid for EAN-8 (8 digits), UPC-A (12), EAN-13 and ITF-14 (14).
///     Rightmost digit is the check; remaining digits weighted 3,1,3,1,…
///     from the right just before the check digit. Sum mod 10, then
///     (10 − r) mod 10 must equal the check.
///
/// Two GTIN-length numeric strings with random digit swaps still match
/// in ~10% of cases (any single-digit edit has p≈10% of producing a
/// valid check digit). So the validator cuts most pixel-level scanner
/// errors but doesn't fully prevent "this happens to be another
/// product's barcode" collisions.
class BarcodeValidator {
  const BarcodeValidator._();

  /// Combines [isLikelyBarcode] and (for GTIN-length numeric strings)
  /// [hasValidGtinCheckDigit].
  static bool isValidBarcode(String value) {
    if (!isLikelyBarcode(value)) return false;
    final isNumericOnly = RegExp(r'^\d+$').hasMatch(value);
    if (!isNumericOnly) return true;
    final len = value.length;
    if (len == 8 || len == 12 || len == 13 || len == 14) {
      return hasValidGtinCheckDigit(value);
    }
    return true;
  }

  /// Heuristic: not a URL, not a path. QR codes can carry arbitrary
  /// text and we don't want to round-trip those into product routes.
  static bool isLikelyBarcode(String value) {
    if (value.isEmpty) return false;
    if (value.contains('://') || value.contains('/')) return false;
    if (value.startsWith('http') || value.startsWith('www.')) return false;
    return true;
  }

  /// GS1 mod-10 check digit validation. See class docs for the math.
  static bool hasValidGtinCheckDigit(String value) {
    if (value.length < 2) return false;
    if (!RegExp(r'^\d+$').hasMatch(value)) return false;
    final digits = value.codeUnits;
    final check = digits.last - 0x30;
    var sum = 0;
    for (var i = 0; i < digits.length - 1; i++) {
      final d = digits[digits.length - 2 - i] - 0x30;
      sum += d * (i.isEven ? 3 : 1);
    }
    final expected = (10 - (sum % 10)) % 10;
    return expected == check;
  }
}
