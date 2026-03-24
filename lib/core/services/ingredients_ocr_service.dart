import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

import '../../config/drift/app_database.dart';

class IngredientsParseResult {
  final String cleanedText;
  final List<String> detectedAdditives;
  final List<String> unmatchedAdditives;
  final double confidence;

  const IngredientsParseResult({
    required this.cleanedText,
    required this.detectedAdditives,
    required this.unmatchedAdditives,
    required this.confidence,
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

  /// Parse ingredients text, extract E-codes, match against Additives DB
  Future<IngredientsParseResult> parseIngredients(String rawText) async {
    // Step 1: Clean text
    final cleaned = _cleanText(rawText);

    // Step 2: Extract E-codes via regex
    final eCodes = _extractECodes(cleaned);

    // Step 3: Match Turkish names from DB
    final turkishMatches = await _matchTurkishNames(cleaned);
    final allCodes = {...eCodes, ...turkishMatches};

    // Step 4: Match against Additives DB
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

    // Step 5: Calculate confidence
    final confidence = _calculateConfidence(
      eCodeCount: allCodes.length,
      textLength: cleaned.length,
    );

    return IngredientsParseResult(
      cleanedText: cleaned,
      detectedAdditives: detected,
      unmatchedAdditives: unmatched,
      confidence: confidence,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }

  // --- Private helpers ---

  String _cleanText(String raw) {
    var text = raw;

    // Find "İçindekiler" or "Ingredients" header and take text after it
    final headerPatterns = [
      RegExp(r'[İi]çindekiler\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]ngredients\s*:?\s*', caseSensitive: false),
    ];
    for (final pattern in headerPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        text = text.substring(match.end);
        break;
      }
    }

    // Cut at "Besin Değerleri" or "Nutrition Facts"
    final cutPatterns = [
      RegExp(r'[Bb]esin\s+[Dd]eğer', caseSensitive: false),
      RegExp(r'[Nn]utrition\s+[Ff]act', caseSensitive: false),
      RegExp(r'[Bb]esin\s+[İi]çeriği', caseSensitive: false),
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

    return text;
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
    final lowerText = text.toLowerCase();

    try {
      // Get all additives with Turkish names from DB
      final allAdditives = await _db.select(_db.additives).get();

      for (final additive in allAdditives) {
        final nameTr = additive.nameTr?.toLowerCase();
        if (nameTr != null &&
            nameTr.isNotEmpty &&
            lowerText.contains(nameTr)) {
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
