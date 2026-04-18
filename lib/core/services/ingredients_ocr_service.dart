import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

import '../../config/drift/app_database.dart';

class IngredientsParseResult {
  final String cleanedText;
  final List<String> detectedAdditives;
  final List<String> unmatchedAdditives;
  final double confidence;

  /// True if an ingredients-section header ("İçindekiler", "Ingredients",
  /// "Tərkibi") was found in the OCR text. When false, the photo most likely
  /// missed the ingredients section entirely — UI should ask for re-capture
  /// rather than showing the address/advice text that was picked up instead.
  final bool headerFound;

  const IngredientsParseResult({
    required this.cleanedText,
    required this.detectedAdditives,
    required this.unmatchedAdditives,
    required this.confidence,
    required this.headerFound,
  });
}

class IngredientsOcrService {
  final AppDatabase _db;
  final _logger = Logger();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  IngredientsOcrService(this._db);

  /// Extract raw text from image using ML Kit
  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// Parse ingredients text, extract E-codes, match against Additives DB.
  ///
  /// Robustness strategy: parse BOTH raw and cleaned text and take the union
  /// of matches. The raw text might contain the ingredients header in an
  /// unexpected position; the cleaned text drops address/nutrition blocks
  /// but may also drop legitimate ingredients if the header cut was wrong.
  Future<IngredientsParseResult> parseIngredients(String rawText) async {
    final cleanResult = _cleanText(rawText);
    final cleaned = cleanResult.text;
    final headerFound = cleanResult.headerFound;

    // Extract E-codes from both — some codes might live before the header
    // (e.g. product name line) or after it was wrongly trimmed.
    final eCodes = {..._extractECodes(cleaned), ..._extractECodes(rawText)};

    // Match Turkish/Azerbaijani additive names from both sources.
    final turkishMatches = {
      ...await _matchTurkishNames(cleaned),
      ...await _matchTurkishNames(rawText),
    };
    final allCodes = {...eCodes, ...turkishMatches};

    final detected = <String>[];
    final unmatched = <String>[];
    for (final code in allCodes) {
      final found = await _existsInDb(code);
      if (found) {
        detected.add(code);
      } else {
        unmatched.add(code);
      }
    }

    // If the ingredients header was never detected AND we found no matches at
    // all, the photo almost certainly missed the ingredients section — force
    // confidence to 0 so the caller shows the "tekrar çek" dialog instead of
    // presenting the producer address as ingredients.
    final confidence = (!headerFound && allCodes.isEmpty)
        ? 0.0
        : _calculateConfidence(
            eCodeCount: allCodes.length,
            textLength: cleaned.length,
          );

    return IngredientsParseResult(
      cleanedText: cleaned,
      detectedAdditives: detected,
      unmatchedAdditives: unmatched,
      confidence: confidence,
      headerFound: headerFound,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }

  // --- Private helpers ---

  _CleanResult _cleanText(String raw) {
    var text = raw;
    var headerFound = false;

    // Find an ingredients-section header and take text after it.
    // Supports TR (İçindekiler), EN (Ingredients), AZ (Tərkibi / Terkibi / Tərkib).
    // Also tolerates common OCR misreads: "içerik", "lçindekiler", "Içindekiler".
    final headerPatterns = [
      RegExp(r'[İIiIl1]\s?[çc]indekiler\s*:?\s*', caseSensitive: false),
      RegExp(r'[İIiIl1]\s?[çc]erik(?:ler)?\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]ngredients\s*:?\s*', caseSensitive: false),
      RegExp(r'T[əeE]rkib(?:i)?\s*:?\s*', caseSensitive: false),
    ];
    for (final pattern in headerPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        text = text.substring(match.end);
        headerFound = true;
        break;
      }
    }

    // Cut at any marker that signals the end of the ingredients block:
    // nutrition tables, producer/importer address, contact info, net mass.
    final cutPatterns = [
      RegExp(r'[Bb]esin\s+[Dd]eğer', caseSensitive: false),
      RegExp(r'[Nn]utrition\s+[Ff]act', caseSensitive: false),
      RegExp(r'[Bb]esin\s+[İi]çeriği', caseSensitive: false),
      RegExp(r'[Ee]nerji\s+ve\s+[Bb]esin', caseSensitive: false),
      RegExp(r'[Üü]retici\s*:', caseSensitive: false),
      RegExp(r'[İi]dxalat[çc][ıi]\s*:', caseSensitive: false),
      RegExp(r'[İi]thalat[çc][ıi]\s*:', caseSensitive: false),
      RegExp(r'[Tt]el\s*:', caseSensitive: false),
      RegExp(r'[Ee]\s*-?\s*mail\s*:', caseSensitive: false),
      RegExp(r'[Xx]alis\s+k[üu]tl[əe]si', caseSensitive: false),
      RegExp(r'\b[Nn]et\s*:', caseSensitive: false),
      RegExp(r'[Tt]avsiye\s+[Ee]dilen', caseSensitive: false),
      RegExp(r'[Tt][əe]vsiyə\s+[Ee]dilən', caseSensitive: false),
      RegExp(r'[Ss]on\s+[Kk]ullan', caseSensitive: false),
      RegExp(r'\b[Kk]od\s+[Nn]o\s*:', caseSensitive: false),
    ];
    for (final pattern in cutPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        text = text.substring(0, match.start);
        break;
      }
    }

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\n+'), ' ');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.trim();

    return _CleanResult(text: text, headerFound: headerFound);
  }

  /// Lowercase + strip Turkish/Azerbaijani diacritics and punctuation.
  /// ML Kit frequently misreads ü/ş/ğ/ç/ı/ə — this lets us match OCR output
  /// like "Sodyum Metabisulfit" against the DB entry "Sodyum Metabisülfit".
  String _normalizeForMatch(String input) {
    const table = {
      'ı': 'i', 'İ': 'i', 'I': 'i',
      'ü': 'u', 'Ü': 'u',
      'ö': 'o', 'Ö': 'o',
      'ç': 'c', 'Ç': 'c',
      'ş': 's', 'Ş': 's',
      'ğ': 'g', 'Ğ': 'g',
      'ə': 'e', 'Ə': 'e',
    };
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(table[ch] ?? ch.toLowerCase());
    }
    // Collapse any non-letter/non-digit run into a single space
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  Set<String> _extractECodes(String text) {
    final codes = <String>{};

    // Pattern: E followed by 3-4 digits and optional letter suffix
    // Handles: E471, E160a, E 471, E-471
    final pattern = RegExp(
      r'[Ee]\s?-?\s?(\d{3,4}\s?[a-zA-Z]?)',
    );

    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0) ?? '';
      final normalized = _normalizeECode(raw);
      if (normalized != null) {
        codes.add(normalized);
      }
    }

    return codes;
  }

  String? _normalizeECode(String raw) {
    var code = raw.trim().toUpperCase();
    code = code.replaceAll(RegExp(r'[\s-]'), '');

    final match = RegExp(r'^E(\d{3,4}[A-Za-z]?)$').firstMatch(code);
    if (match == null) return null;

    return 'E${match.group(1)!.toLowerCase()}';
  }

  Future<Set<String>> _matchTurkishNames(String text) async {
    final matches = <String>{};
    final normalizedText = _normalizeForMatch(text);
    if (normalizedText.isEmpty) return matches;

    try {
      final allAdditives = await _db.select(_db.additives).get();

      for (final additive in allAdditives) {
        final nameTr = additive.nameTr;
        if (nameTr == null || nameTr.isEmpty) continue;
        // Short names like "Lif" (3 chars) cause false positives — skip.
        if (nameTr.length < 5) continue;

        final normalizedName = _normalizeForMatch(nameTr);
        if (normalizedName.isEmpty) continue;
        if (normalizedText.contains(normalizedName)) {
          matches.add(additive.eNumber);
        }
      }
    } catch (e) {
      _logger.w('Turkish name matching failed: $e');
    }

    return matches;
  }

  Future<bool> _existsInDb(String eCode) async {
    try {
      final query = _db.select(_db.additives)
        ..where((t) => t.eNumber.equals(eCode));
      final row = await query.getSingleOrNull();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  double _calculateConfidence({
    required int eCodeCount,
    required int textLength,
  }) {
    if (textLength < 10) return 0.0;
    if (eCodeCount >= 3) return min(0.8 + (eCodeCount * 0.02), 1.0);
    if (eCodeCount >= 1) return 0.5 + (eCodeCount * 0.15);
    // No E-codes but meaningful text — possibly natural product
    if (textLength > 30) return 0.3;
    return 0.1;
  }
}

class _CleanResult {
  final String text;
  final bool headerFound;
  const _CleanResult({required this.text, required this.headerFound});
}
