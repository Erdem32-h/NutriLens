import 'barcode_validator.dart';

/// A parsed GS1 Digital Link QR (e.g. `https://brand.example/01/<GTIN>/10/<lot>?17=YYMMDD`).
///
/// Brands are replacing EAN barcodes with these URLs (GS1 "Sunrise 2027");
/// the scanner reads the GTIN out of them so the normal product route works,
/// and keeps lot / expiry / the URL for the product page's producer card.
/// Only `https` URLs with a check-digit-valid GTIN are accepted — an arbitrary
/// URL QR still falls through to the "invalid barcode" path.
class Gs1DigitalLink {
  /// GTIN in the form products are keyed by: a 14-digit GTIN with a leading
  /// zero is shortened to its EAN-13 form.
  final String gtin;
  final String? lot;
  final DateTime? expiry;
  final Uri uri;

  const Gs1DigitalLink({
    required this.gtin,
    required this.uri,
    this.lot,
    this.expiry,
  });

  static final _gtinPattern = RegExp(r'^(\d{8}|\d{12,14})$');
  static final _datePattern = RegExp(r'^\d{6}$');

  static Gs1DigitalLink? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;

    // Raw (still percent-encoded) segments: `Uri.pathSegments` decodes and
    // throws on a malformed escape anywhere in the path.
    final segments = uri.path.split('/');
    final gtinIndex = segments.indexOf('01') + 1;
    if (gtinIndex == 0 || gtinIndex >= segments.length) return null;
    final rawGtin = segments[gtinIndex];
    if (!_gtinPattern.hasMatch(rawGtin) ||
        !BarcodeValidator.hasValidGtinCheckDigit(rawGtin)) {
      return null;
    }

    return Gs1DigitalLink(
      gtin: _normaliseGtin(rawGtin),
      uri: uri,
      lot: _lot(segments, gtinIndex + 1),
      expiry: _expiry(uri.queryParameters['17']),
    );
  }

  static String _normaliseGtin(String gtin) {
    final padded = gtin.padLeft(14, '0');
    return padded.startsWith('0') ? padded.substring(1) : padded;
  }

  /// Decoding throws on malformed escapes, so a bad lot is dropped, not fatal.
  static String? _lot(List<String> segments, int from) {
    final i = segments.indexOf('10', from) + 1;
    if (i == 0 || i >= segments.length) return null;
    try {
      final lot = Uri.decodeComponent(segments[i]);
      return lot.isEmpty ? null : lot;
    } on FormatException {
      return null;
    }
  }

  /// GS1 AI 17 is YYMMDD; `DD=00` means the last day of that month.
  static DateTime? _expiry(String? value) {
    if (value == null || !_datePattern.hasMatch(value)) return null;
    final year = 2000 + int.parse(value.substring(0, 2));
    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4, 6));
    if (month < 1 || month > 12) return null;
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day > lastDay) return null;
    return DateTime(year, month, day == 0 ? lastDay : day);
  }
}
