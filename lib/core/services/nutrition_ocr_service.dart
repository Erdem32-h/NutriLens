import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/ocr_image_prep.dart';
import 'gemini_ai_service.dart' show NutritionOcrResult;

/// On-device nutrition-table OCR using ML Kit.
///
/// **Why ML Kit for nutrition specifically?** Nutrition tables are printed
/// in large, high-contrast digits — the exact kind of content Latin-script
/// OCR handles well. The previous Gemini-vision path was returning
/// "no text found" for valid frames, presumably because its JSON-only
/// prompt couldn't handle tables split across two columns
/// (per-100 g vs. per-serving). ML Kit returns every recognized number and
/// we pick the 100 g column ourselves with simple heuristics.
///
/// Ingredients scanning stays on Gemini vision — that job needs real text
/// understanding (cleaning, section extraction), not number harvesting.
class NutritionOcrService {
  final TextRecognizer _recognizer;

  NutritionOcrService({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  /// Scan a raw camera/gallery byte buffer and return the parsed per-100 g
  /// values. Routes through [prepareOcrImage] on a worker isolate first so
  /// ML Kit sees an EXIF-baked, ~1600 px image — that alone cuts the
  /// end-to-end time by 50–70 % on mid-range Androids and fixes a Samsung
  /// landscape-rotation accuracy bug that was feeding ML Kit sideways text.
  Future<NutritionOcrResult?> extractNutritionFromBytes(
    Uint8List rawBytes,
  ) async {
    final prepared = await prepareOcrImage(rawBytes);

    // ML Kit's InputImage.fromBytes requires raw pixel metadata; the JPEG
    // path via a file is much simpler and avoids a second decode on the
    // UI isolate.
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      p.join(
        tempDir.path,
        'nutri_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ),
    );
    try {
      await tempFile.writeAsBytes(prepared.bytes, flush: true);
      return await extractNutritionFromFile(tempFile);
    } finally {
      // Best-effort cleanup; a leftover jpeg in the OS temp dir is harmless
      // but leaving them would accumulate over hundreds of scans.
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          /* noop */
        }
      }
    }
  }

  /// Scan an image file and return the parsed per-100 g nutrition values.
  /// Returns `null` when no text was recognized or no nutrition numbers
  /// could be matched to any known label.
  ///
  /// Prefer [extractNutritionFromBytes] when the caller has raw camera
  /// bytes — that path baked orientation + downscaled, both of which
  /// matter for speed and accuracy. This method is useful when the file
  /// is already prepared (tests, gallery picks that have been resized).
  Future<NutritionOcrResult?> extractNutritionFromFile(File file) async {
    final input = InputImage.fromFile(file);
    final recognized = await _recognizer.processImage(input);
    final text = recognized.text;
    if (text.trim().isEmpty) return null;
    return parseNutritionText(text);
  }

  /// Release the ML Kit recognizer. Must be called when the owning
  /// provider disposes — the native side holds an OS handle.
  Future<void> dispose() => _recognizer.close();

  /// Parse a raw recognized-text blob into a [NutritionOcrResult].
  ///
  /// Exposed as `@visibleForTesting`-style public API so the parser can
  /// be exercised by unit tests without a real image.
  NutritionOcrResult? parseNutritionText(String rawText) {
    final cleaned = _normalize(rawText);
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    double? energy;
    double? fat;
    double? satFat;
    double? transFat;
    double? carbs;
    double? sugars;
    double? salt;
    double? sodium;
    double? fiber;
    double? protein;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final candidate = _lineWithNearbyValues(lines, i);
      final valueScope = _hasUsefulNumber(line) ? candidate : line;
      final lower = line.toLowerCase();

      // Energy — prefer the kcal column; fall back to kJ / 4.184 if only
      // the kJ figure was recognized.
      if (energy == null && _containsAny(lower, _kEnergy)) {
        energy = _findEnergyKcal(valueScope);
      }

      // Saturated/trans first so the generic "fat" branch doesn't steal
      // their numbers.
      if (_containsAny(lower, _kSatFat)) {
        satFat ??= _findFirstNumber(valueScope, preferUnit: 'g');
      } else if (_containsAny(lower, _kTransFat)) {
        transFat ??= _findFirstNumber(valueScope, preferUnit: 'g');
      } else if (_containsAny(lower, _kFat)) {
        fat ??= _findFirstNumber(valueScope, preferUnit: 'g');
      }

      // Sugars checked before carbs — "of which sugars" lines contain
      // "şeker"/"sugar" but not "karbon"/"carb".
      if (_containsAny(lower, _kSugars)) {
        sugars ??= _findFirstNumber(valueScope, preferUnit: 'g');
      } else if (_containsAny(lower, _kCarbs)) {
        carbs ??= _findFirstNumber(valueScope, preferUnit: 'g');
      }

      if (_containsAny(lower, _kFiber)) {
        fiber ??= _findFirstNumber(valueScope, preferUnit: 'g');
      }

      if (_containsAny(lower, _kProtein)) {
        protein ??= _findFirstNumber(valueScope, preferUnit: 'g');
      }

      // Salt: printed as g or (rarely) mg. We try g first; if the picked
      // value is implausibly large for salt (>50 g/100 g) we retry mg.
      if (_containsAny(lower, _kSalt)) {
        final gVal = _findFirstNumber(valueScope, preferUnit: 'g');
        if (gVal != null && gVal <= 50) {
          salt ??= gVal;
        } else {
          final mg = _findNumberWithUnit(valueScope, 'mg');
          if (mg != null) salt ??= mg / 1000.0;
        }
      }
      if (_containsAny(lower, _kSodium)) {
        final mg = _findNumberWithUnit(valueScope, 'mg');
        if (mg != null) {
          sodium ??= mg / 1000.0;
        } else {
          final g = _findFirstNumber(valueScope, preferUnit: 'g');
          if (g != null) sodium ??= g;
        }
      }
    }

    // If the label only published sodium, derive salt = sodium × 2.5
    // (EU regulation 1169/2011 Annex I). This is the same conversion
    // Open Food Facts uses when only one of the pair is present.
    if (salt == null && sodium != null) {
      salt = sodium * 2.5;
    }

    final separatedColumns = _parseSeparatedColumns(lines);
    energy ??= separatedColumns.energy;
    fat ??= separatedColumns.fat;
    satFat ??= separatedColumns.satFat;
    transFat ??= separatedColumns.transFat;
    carbs ??= separatedColumns.carbs;
    sugars ??= separatedColumns.sugars;
    salt ??= separatedColumns.salt;
    sodium ??= separatedColumns.sodium;
    fiber ??= separatedColumns.fiber;
    protein ??= separatedColumns.protein;
    if (salt == null && sodium != null) {
      salt = sodium * 2.5;
    }

    final hasAnyValue = <double?>[
      energy,
      fat,
      satFat,
      transFat,
      carbs,
      sugars,
      salt,
      fiber,
      protein,
    ].any((v) => v != null);
    if (!hasAnyValue) return null;

    return NutritionOcrResult(
      energyKcal: energy,
      fat: fat,
      saturatedFat: satFat,
      transFat: transFat,
      carbohydrates: carbs,
      sugars: sugars,
      salt: salt,
      fiber: fiber,
      protein: protein,
    );
  }

  // ── Internal helpers ────────────────────────────────────────────────

  /// Normalise whitespace & reunite numbers split across newlines.
  ///
  /// ML Kit occasionally splits "3,5 g" at the comma when the column is
  /// narrow — `"3\n,5 g"`. We glue those back together before the
  /// per-line walk.
  String _normalize(String raw) {
    var t = raw.replaceAll('\u00a0', ' ');
    t = t.replaceAllMapped(_kSplitDecimal, (m) => '${m.group(1)}${m.group(2)}');
    t = t.replaceAll(_kWhitespaceRun, ' ');
    return t;
  }

  bool _containsAny(String lowerLine, List<String> keywords) {
    for (final k in keywords) {
      if (lowerLine.contains(k)) return true;
    }
    return false;
  }

  /// ML Kit often preserves the visual table layout instead of semantic rows:
  /// label on one line, then "100 g", then the value on the next line. Join a
  /// tiny lookahead window so the existing parsers can still bind the value to
  /// its label.
  String _lineWithNearbyValues(List<String> lines, int index) {
    final end = (index + 3 < lines.length) ? index + 3 : lines.length - 1;
    return lines.sublist(index, end + 1).join(' ');
  }

  /// Fallback for ML Kit's column-wise dumps:
  ///
  ///   Energy
  ///   Fat
  ///   Saturated fat
  ///   100 g
  ///   438 kcal
  ///   16 g
  ///   6,4 g
  ///
  /// In that shape there is no local "label + value" row to parse. The
  /// nutrition table order is still preserved, so pair recognized labels with
  /// the following non-header numeric lines.
  _NutritionValues _parseSeparatedColumns(List<String> lines) {
    final labels = <_NutrientKind>[];
    final values = <String>[];

    for (final line in lines) {
      final kind = _labelKind(line);
      if (kind != null && !_hasUsefulNumber(line)) {
        labels.add(kind);
        continue;
      }
      if (_valueLine(line)) {
        values.add(line);
      }
    }

    final parsed = _NutritionValues();
    var valueIndex = 0;
    for (final kind in labels) {
      while (valueIndex < values.length) {
        final value = _valueForKind(kind, values[valueIndex]);
        valueIndex++;
        if (value == null) continue;
        parsed.setIfAbsent(kind, value);
        break;
      }
    }
    return parsed;
  }

  _NutrientKind? _labelKind(String line) {
    final lower = line.toLowerCase();
    if (_containsAny(lower, _kEnergy)) return _NutrientKind.energy;
    if (_containsAny(lower, _kSatFat)) return _NutrientKind.satFat;
    if (_containsAny(lower, _kTransFat)) return _NutrientKind.transFat;
    if (_containsAny(lower, _kFat)) return _NutrientKind.fat;
    if (_containsAny(lower, _kSugars)) return _NutrientKind.sugars;
    if (_containsAny(lower, _kCarbs)) return _NutrientKind.carbs;
    if (_containsAny(lower, _kFiber)) return _NutrientKind.fiber;
    if (_containsAny(lower, _kProtein)) return _NutrientKind.protein;
    if (_containsAny(lower, _kSalt)) return _NutrientKind.salt;
    if (_containsAny(lower, _kSodium)) return _NutrientKind.sodium;
    return null;
  }

  bool _hasUsefulNumber(String line) {
    return _kNumberWithUnit.allMatches(line).any((m) {
      final value = _parseNum(m.group(1)!);
      final unit = (m.group(2) ?? '').toLowerCase();
      return !(value == 100 && (unit == 'g' || unit == 'ml'));
    });
  }

  bool _valueLine(String line) {
    if (_labelKind(line) != null) return false;
    return _hasUsefulNumber(line);
  }

  double? _valueForKind(_NutrientKind kind, String line) {
    switch (kind) {
      case _NutrientKind.energy:
        return _findEnergyKcal(line);
      case _NutrientKind.sodium:
        final mg = _findNumberWithUnit(line, 'mg');
        if (mg != null) return mg / 1000.0;
        return _findFirstNumber(line, preferUnit: 'g');
      case _NutrientKind.salt:
      case _NutrientKind.fat:
      case _NutrientKind.satFat:
      case _NutrientKind.transFat:
      case _NutrientKind.carbs:
      case _NutrientKind.sugars:
      case _NutrientKind.fiber:
      case _NutrientKind.protein:
        return _findFirstNumber(line, preferUnit: 'g');
    }
  }

  /// Pick the first plausible nutrient number from a line.
  ///
  /// Filters two kinds of noise:
  /// - **Column headers**: "100 g" / "100 ml" are printed on the table
  ///   header row and would otherwise become the first number we see
  ///   for that row's label if the table crumbled into one line.
  /// - **% RI / RDA figures**: the daily-reference percentage column is
  ///   never a per-100 g gram value.
  double? _findFirstNumber(String line, {String? preferUnit}) {
    final matches = _kNumberWithUnit.allMatches(line).toList();
    if (matches.isEmpty) return null;

    bool isColumnHeader(RegExpMatch m) {
      final val = _parseNum(m.group(1)!);
      final unit = (m.group(2) ?? '').toLowerCase();
      return val == 100 && (unit == 'g' || unit == 'ml');
    }

    bool isPercent(RegExpMatch m) => (m.group(2) ?? '') == '%';

    final filtered = matches
        .where((m) => !isColumnHeader(m) && !isPercent(m))
        .toList();
    if (filtered.isEmpty) return null;

    if (preferUnit != null) {
      final wanted = preferUnit.toLowerCase();
      for (final m in filtered) {
        if ((m.group(2) ?? '').toLowerCase() == wanted) {
          return _parseNum(m.group(1)!);
        }
      }

      for (final m in filtered) {
        if ((m.group(2) ?? '').isEmpty) {
          return _parseNum(m.group(1)!);
        }
      }

      return null;
    }

    return _parseNum(filtered.first.group(1)!);
  }

  /// Energy deserves special handling because the line usually shows two
  /// numbers — "1565 kJ / 370 kcal". We must pick the kcal value, not
  /// the first number on the line.
  double? _findEnergyKcal(String line) {
    final m = _kKcal.firstMatch(line);
    if (m != null) return _parseNum(m.group(1)!);

    // Fallback: if only kJ was recognized, convert.
    final m2 = _kKj.firstMatch(line);
    if (m2 != null) {
      final v = _parseNum(m2.group(1)!);
      if (v != null) return v / 4.184;
    }
    return null;
  }

  double? _findNumberWithUnit(String line, String unit) {
    // `unit` here is always 'mg' in the call sites; the cached regex keeps
    // the parser hot-path allocation-free.
    final r = unit == 'mg'
        ? _kMg
        : RegExp(
            '(\\d{1,4}(?:[.,]\\d{1,3})?)\\s*$unit\\b',
            caseSensitive: false,
          );
    final m = r.firstMatch(line);
    if (m == null) return null;
    return _parseNum(m.group(1)!);
  }

  double? _parseNum(String raw) {
    return double.tryParse(raw.replaceAll(',', '.'));
  }
}

// ── Regex cache ───────────────────────────────────────────────────────
//
// Top-level finals are lazily compiled once per isolate; compiling the
// same six patterns on every scan was wasting ~2-5 ms plus allocation
// pressure we don't need on the UI path.

final RegExp _kSplitDecimal = RegExp(r'(\d)\s*\n\s*([.,]\s*\d)');
final RegExp _kWhitespaceRun = RegExp(r'[\t ]+');
final RegExp _kNumberWithUnit = RegExp(
  r'(\d{1,4}(?:[.,]\d{1,3})?)\s*(mg|g|kg|kcal|kj|ml|%)?',
  caseSensitive: false,
);
final RegExp _kKcal = RegExp(
  r'(\d{1,4}(?:[.,]\d{1,3})?)\s*kcal',
  caseSensitive: false,
);
final RegExp _kKj = RegExp(
  r'(\d{1,4}(?:[.,]\d{1,3})?)\s*kj',
  caseSensitive: false,
);
final RegExp _kMg = RegExp(
  r'(\d{1,4}(?:[.,]\d{1,3})?)\s*mg\b',
  caseSensitive: false,
);

// ── Label keyword dictionaries ────────────────────────────────────────
//
// Lowercase substrings: `line.toLowerCase().contains(keyword)`. Diacritics
// are preserved here because ML Kit renders them correctly for Turkish
// (script: latin covers İ/ı/ğ/ç/ö/ş/ü). If a misread strips them we also
// include an ASCII-folded alternative ("yag" for "yağ").

const List<String> _kEnergy = ['enerji', 'energy', 'energie'];

const List<String> _kFat = ['yağ', 'yag', 'fat', 'matières grasses'];

const List<String> _kSatFat = [
  'doymuş',
  'doymus',
  'doygun',
  'saturated',
  'saturés',
  'satures',
];

const List<String> _kTransFat = ['trans'];

const List<String> _kCarbs = ['karbonhi', 'karbohi', 'carb', 'glucides'];

const List<String> _kSugars = ['şeker', 'seker', 'sugar', 'sucre'];

const List<String> _kFiber = ['lif', 'posa', 'fibre', 'fiber'];

const List<String> _kProtein = ['protein', 'protéin'];

// Guard: avoid matching "salça" / "salam" for salt. We anchor to 'tuz'
// (Turkish), 'salt' (English — but only the 4-letter word), and 'sel'
// (French — but narrowly). 'salt' inside 'salça' does not occur. 'sel'
// inside 'seller' won't because the key is checked as substring but the
// nutrition column headers don't contain such noise.
const List<String> _kSalt = ['tuz', 'salt'];

const List<String> _kSodium = ['sodyum', 'sodium'];

enum _NutrientKind {
  energy,
  fat,
  satFat,
  transFat,
  carbs,
  sugars,
  salt,
  sodium,
  fiber,
  protein,
}

class _NutritionValues {
  double? energy;
  double? fat;
  double? satFat;
  double? transFat;
  double? carbs;
  double? sugars;
  double? salt;
  double? sodium;
  double? fiber;
  double? protein;

  void setIfAbsent(_NutrientKind kind, double value) {
    switch (kind) {
      case _NutrientKind.energy:
        energy ??= value;
      case _NutrientKind.fat:
        fat ??= value;
      case _NutrientKind.satFat:
        satFat ??= value;
      case _NutrientKind.transFat:
        transFat ??= value;
      case _NutrientKind.carbs:
        carbs ??= value;
      case _NutrientKind.sugars:
        sugars ??= value;
      case _NutrientKind.salt:
        salt ??= value;
      case _NutrientKind.sodium:
        sodium ??= value;
      case _NutrientKind.fiber:
        fiber ??= value;
      case _NutrientKind.protein:
        protein ??= value;
    }
  }
}
