import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Processes OCR results with multi-language support.
/// Prefers Turkish text, falls back to English, then any language.
/// Cleans common OCR artifacts and normalizes text.
class OcrTextProcessor {
  const OcrTextProcessor();

  /// Process recognized text and return cleaned result.
  /// Prioritizes Turkish content, then English, then all text.
  OcrProcessedResult process(RecognizedText recognizedText) {
    final allBlocks = recognizedText.blocks;
    if (allBlocks.isEmpty) {
      return const OcrProcessedResult(text: '', language: 'unknown');
    }

    // Classify blocks by detected language
    final turkishBlocks = <TextBlock>[];
    final englishBlocks = <TextBlock>[];
    final otherBlocks = <TextBlock>[];

    for (final block in allBlocks) {
      final langs = block.recognizedLanguages;
      if (_containsLanguage(langs, 'tr')) {
        turkishBlocks.add(block);
      } else if (_containsLanguage(langs, 'en')) {
        englishBlocks.add(block);
      } else {
        otherBlocks.add(block);
      }
    }

    // Also use heuristic detection on the full text
    final fullText = recognizedText.text;
    final heuristicLang = _detectLanguageHeuristic(fullText);

    // Choose best blocks based on language priority
    String rawText;
    String detectedLang;

    if (turkishBlocks.isNotEmpty) {
      // Turkish blocks found — use them preferentially
      rawText = _blocksToText(turkishBlocks);
      detectedLang = 'tr';
    } else if (heuristicLang == 'tr') {
      // ML Kit didn't tag Turkish but heuristics say it is
      rawText = fullText;
      detectedLang = 'tr';
    } else if (englishBlocks.isNotEmpty) {
      // English blocks found
      rawText = _blocksToText(englishBlocks);
      detectedLang = 'en';
    } else {
      // Fallback: use all text
      rawText = fullText;
      detectedLang = heuristicLang;
    }

    // Clean OCR artifacts
    final cleaned = cleanOcrArtifacts(rawText);

    return OcrProcessedResult(text: cleaned, language: detectedLang);
  }

  /// Process for ingredients specifically.
  /// Extracts the ingredients section from OCR text.
  OcrProcessedResult processIngredients(RecognizedText recognizedText) {
    final result = process(recognizedText);
    if (result.text.isEmpty) return result;

    final extracted = _extractIngredientsSection(result.text);
    return OcrProcessedResult(
      text: extracted,
      language: result.language,
    );
  }

  /// Process for nutrition table specifically.
  /// Returns the full cleaned text for nutrition parsing.
  OcrProcessedResult processNutrition(RecognizedText recognizedText) {
    return process(recognizedText);
  }

  // ── Language Detection ─────────────────────────────────────────────

  bool _containsLanguage(List<String> langs, String code) {
    for (final lang in langs) {
      if (lang.toLowerCase() == code) return true;
    }
    return false;
  }

  /// Heuristic language detection based on Turkish-specific characters
  /// and common Turkish food label keywords.
  String _detectLanguageHeuristic(String text) {
    final lower = text.toLowerCase();

    // Turkish-specific characters
    final turkishChars = RegExp(r'[çğıöşüÇĞİÖŞÜ]');
    final turkishCharCount = turkishChars.allMatches(text).length;

    // Turkish food label keywords
    const turkishKeywords = [
      'içindekiler',
      'besin değer',
      'enerji',
      'yağ',
      'şeker',
      'tuz',
      'lif',
      'protein',
      'karbonhidrat',
      'doymuş',
      'porsiyon',
      'miktar',
      'ağırlık',
      'alerjen',
      'içerir',
      'içerebilir',
      'üretici',
      'saklama',
      'son tüketim',
    ];

    int turkishKeywordCount = 0;
    for (final kw in turkishKeywords) {
      if (lower.contains(kw)) turkishKeywordCount++;
    }

    // English food label keywords
    const englishKeywords = [
      'ingredients',
      'nutrition facts',
      'energy',
      'sugar',
      'salt',
      'fiber',
      'protein',
      'carbohydrate',
      'saturated',
      'serving',
      'contains',
      'allergen',
      'storage',
      'best before',
    ];

    int englishKeywordCount = 0;
    for (final kw in englishKeywords) {
      if (lower.contains(kw)) englishKeywordCount++;
    }

    // Decision logic
    if (turkishCharCount >= 3 || turkishKeywordCount >= 2) return 'tr';
    if (englishKeywordCount >= 2) return 'en';
    if (turkishCharCount >= 1 && turkishKeywordCount >= 1) return 'tr';
    if (englishKeywordCount >= 1) return 'en';
    return 'unknown';
  }

  // ── Text Cleaning ──────────────────────────────────────────────────

  /// Clean common OCR artifacts from text.
  String cleanOcrArtifacts(String text) {
    var cleaned = text;

    // Fix common OCR misreads for Turkish characters
    // 'l' misread as 'I' in Turkish context (e.g., "Içindekiler" → "İçindekiler")
    cleaned = cleaned.replaceAll('Içindekiler', 'İçindekiler');
    cleaned = cleaned.replaceAll('içindeki1er', 'içindekiler');

    // Common OCR digit/letter confusions
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([0-9]+)[oO]([0-9]+)\b'),
      (m) => '${m.group(1)}0${m.group(2)}',
    );

    // Fix 'l' → '1' in numeric contexts (e.g., "l00g" → "100g")
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bl([0-9]{2,})\b'),
      (m) => '1${m.group(1)}',
    );

    // Fix comma/period confusion in numbers (preserve both as valid)
    // "3,5" and "3.5" are both valid — normalize commas to dots for consistency
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+),(\d{1,2})\s*(g|mg|kcal|kj|ml)'),
      (m) => '${m.group(1)}.${m.group(2)} ${m.group(3)}',
    );

    // Remove stray single characters that are likely noise
    cleaned = cleaned.replaceAll(RegExp(r'\s[|\\/{}\[\]]\s'), ' ');

    // Fix repeated spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Fix newlines to spaces (preserving paragraph breaks)
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');

    // Remove leading/trailing whitespace
    cleaned = cleaned.trim();

    return cleaned;
  }

  // ── Section Extraction ─────────────────────────────────────────────

  /// Extract ingredients section from full label text.
  String _extractIngredientsSection(String text) {
    var result = text;

    // Find "İçindekiler" or "Ingredients" header and take text after it
    final headerPatterns = [
      RegExp(r'[İi]çindekiler\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]ngredients\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]çerik\s*:?\s*', caseSensitive: false),
    ];

    for (final pattern in headerPatterns) {
      final match = pattern.firstMatch(result);
      if (match != null) {
        result = result.substring(match.end);
        break;
      }
    }

    // Cut at "Besin Değerleri", "Nutrition Facts", or similar section headers
    final cutPatterns = [
      RegExp(r'[Bb]esin\s+[Dd]eğer', caseSensitive: false),
      RegExp(r'[Nn]utrition\s+[Ff]act', caseSensitive: false),
      RegExp(r'[Bb]esin\s+[İi]çeriği', caseSensitive: false),
      RegExp(r'[Ss]aklama\s+[Kk]oşul', caseSensitive: false),
      RegExp(r'[Ss]torage', caseSensitive: false),
      RegExp(r'[Aa]lerjen', caseSensitive: false),
      RegExp(r'[Aa]llergen', caseSensitive: false),
      RegExp(r'[Üü]retici', caseSensitive: false),
      RegExp(r'[Ss]on\s+[Tt]üketim', caseSensitive: false),
    ];

    for (final pattern in cutPatterns) {
      final match = pattern.firstMatch(result);
      if (match != null) {
        result = result.substring(0, match.start);
        break;
      }
    }

    // Normalize whitespace
    result = result.replaceAll(RegExp(r'\n+'), ' ');
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    result = result.trim();

    // Remove trailing punctuation artifacts
    result = result.replaceAll(RegExp(r'[,;.]+$'), '').trim();

    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _blocksToText(List<TextBlock> blocks) {
    // Sort blocks top-to-bottom, left-to-right
    final sorted = List<TextBlock>.from(blocks)
      ..sort((a, b) {
        final dy = a.boundingBox.top - b.boundingBox.top;
        if (dy.abs() > 20) return dy.toInt();
        return (a.boundingBox.left - b.boundingBox.left).toInt();
      });

    return sorted.map((b) => b.text).join('\n');
  }
}

/// Result of OCR text processing.
class OcrProcessedResult {
  final String text;
  final String language;

  const OcrProcessedResult({
    required this.text,
    required this.language,
  });
}
