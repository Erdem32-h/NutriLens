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
  ///
  /// Handles three common problems on Turkish food packaging:
  ///   1. **Rotated labels** – OCR reads blocks in image-coordinate order
  ///      which may be bottom-to-top relative to reading order.  We detect
  ///      this by checking whether the "içindekiler" header lands in the
  ///      second half of the raw text, and if so reverse the block order.
  ///   2. **Multi-language labels** (e.g. TR + AZ) – ML Kit assigns a
  ///      language to each block.  We prefer Turkish-tagged blocks; only
  ///      fall back to all blocks when none are tagged Turkish.
  ///   3. **Post-ingredients noise** – handled downstream by
  ///      [_extractIngredientsSection].
  OcrProcessedResult processIngredients(RecognizedText recognizedText) {
    final allBlocks = recognizedText.blocks;
    if (allBlocks.isEmpty) {
      return const OcrProcessedResult(text: '', language: 'unknown');
    }

    // ── 1. Language filtering ─────────────────────────────────────────
    // On multi-language labels (TR + AZ, TR + EN …) prefer blocks that
    // ML Kit explicitly tagged as Turkish.  This removes the Azerbaijani /
    // English repetition that often follows the Turkish ingredients list.
    final turkishBlocks = allBlocks
        .where((b) => _containsLanguage(b.recognizedLanguages, 'tr'))
        .toList();

    final workingBlocks = turkishBlocks.isNotEmpty
        ? turkishBlocks
        : List<TextBlock>.from(allBlocks);

    // ── 2. Sort top-to-bottom, left-to-right (default reading order) ──
    workingBlocks.sort((a, b) {
      final dy = a.boundingBox.top - b.boundingBox.top;
      if (dy.abs() > 20) return dy.toInt();
      return (a.boundingBox.left - b.boundingBox.left).toInt();
    });

    var rawText = workingBlocks.map((b) => b.text).join('\n');

    // ── 3. Reversal detection ─────────────────────────────────────────
    // When a package is photographed with the label running vertically
    // (rotated 90°) and the camera captures the END of the label at the
    // top of the image, the "İçindekiler:" header ends up late in the
    // sorted text.  Re-sort bottom-to-top to correct reading order.
    final lowerCheck = rawText.toLowerCase();
    final headerIdx = lowerCheck.indexOf('içindekiler');
    if (headerIdx > 0 && headerIdx > rawText.length * 0.55) {
      workingBlocks.sort((a, b) {
        final dy = b.boundingBox.top - a.boundingBox.top; // reversed
        if (dy.abs() > 20) return dy.toInt();
        return (b.boundingBox.left - a.boundingBox.left).toInt(); // reversed
      });
      rawText = workingBlocks.map((b) => b.text).join('\n');
    }

    // ── 4. Clean OCR artifacts, then extract ingredients section ──────
    final cleaned = cleanOcrArtifacts(rawText);
    final lang = _detectLanguageHeuristic(rawText);
    final extracted = _extractIngredientsSection(cleaned);

    return OcrProcessedResult(text: extracted, language: lang);
  }

  /// Process for nutrition table specifically.
  /// Preserves newlines so each row stays on its own line for line-by-line
  /// parsing (critical for correct kJ/kcal extraction).
  OcrProcessedResult processNutrition(RecognizedText recognizedText) {
    final allBlocks = recognizedText.blocks;
    if (allBlocks.isEmpty) {
      return const OcrProcessedResult(text: '', language: 'unknown');
    }

    // Sort blocks top-to-bottom
    final sorted = List<TextBlock>.from(allBlocks)
      ..sort((a, b) {
        final dy = a.boundingBox.top - b.boundingBox.top;
        if (dy.abs() > 20) return dy.toInt();
        return (a.boundingBox.left - b.boundingBox.left).toInt();
      });

    // Join blocks with newlines — each block = one table row region
    final rawText = sorted.map((b) => b.text).join('\n');
    final lang = _detectLanguageHeuristic(rawText);

    // Apply minimal cleaning that does NOT collapse newlines
    var cleaned = rawText;
    cleaned = cleaned.replaceAll('Içindekiler', 'İçindekiler');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+),(\d{1,2})\s*(g|mg|kcal|kj|ml)', caseSensitive: false),
      (m) => '${m.group(1)}.${m.group(2)} ${m.group(3)}',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    cleaned = cleaned.trim();

    return OcrProcessedResult(text: cleaned, language: lang);
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

  /// Restore Turkish characters in common food-label words that ML Kit Latin
  /// OCR systematically converts to ASCII equivalents.
  ///
  /// Uses word-boundary patterns to avoid false positives.
  /// Covers the most frequent words seen on Turkish packaging.
  String _fixTurkishFoodWords(String text) {
    // Table of (caseInsensitivePattern → correct Turkish form).
    // Patterns use word-boundary anchors (\b) for safety.
    const fixes = <(String, String)>[
      // Section headers
      (r'\bIcindekiler\b', 'İçindekiler'),
      (r'\bicicndekiler\b', 'içindekiler'),
      (r'\bIcerik\b', 'İçerik'),
      // Nutrient names
      (r'\bEnerji\b', 'Enerji'),
      (r'\bKarbonhidrat\b', 'Karbonhidrat'),
      (r'\bDoymus\s+Yag\b', 'Doymuş Yağ'),
      (r'\bDoymus\b', 'Doymuş'),
      (r'\bTrans\s+Yag\b', 'Trans Yağ'),
      (r'\bSeker\b', 'Şeker'),
      (r'\bsekerler\b', 'şekerler'),
      // Ingredient words
      (r'\bSut\b', 'Süt'),
      (r'\bsut\b', 'süt'),
      (r'\bYag\b', 'Yağ'),       // uppercase context only — too risky alone
      (r'\byag\b', 'yağ'),
      (r'\bKakao\s+Yagi\b', 'Kakao Yağı'),
      (r'\bKakao\s+Kitlasi\b', 'Kakao Kitlesi'),
      (r'\bAyçicek\b', 'Ayçiçek'),
      (r'\bAycicek\b', 'Ayçiçek'),
      (r'\bFistik\b', 'Fıstık'),
      (r'\bfistik\b', 'fıstık'),
      (r'\bFindik\b', 'Fındık'),
      (r'\bfindik\b', 'fındık'),
      (r'\bUzum\b', 'Üzüm'),
      (r'\buzum\b', 'üzüm'),
      (r'\bPortakal\b', 'Portakal'),
      (r'\bcikolata\b', 'çikolata'),
      (r'\bCikolata\b', 'Çikolata'),
      // Common allergen/label words
      (r'\bicerebilir\b', 'içerebilir'),
      (r'\bIcerebilir\b', 'İçerebilir'),
      (r'\bicerir\b', 'içerir'),
      (r'\bIcerir\b', 'İçerir'),
    ];

    var result = text;
    for (final (pattern, replacement) in fixes) {
      result = result.replaceAllMapped(
        RegExp(pattern, caseSensitive: true),
        (_) => replacement,
      );
    }
    return result;
  }

  /// Clean common OCR artifacts from text.
  String cleanOcrArtifacts(String text) {
    var cleaned = text;

    // ── Turkish character OCR fixes ────────────────────────────────
    // ML Kit Latin script OCR frequently substitutes ASCII for Turkish
    // characters (ş→s, ğ→g, ı→i, İ→I, ü→u, ö→o, ç→c).
    // Word-boundary replacements for unambiguous food-label terms:
    cleaned = _fixTurkishFoodWords(cleaned);

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

    // Find the LAST occurrence of an "İçindekiler" header and take text after it.
    // Using the LAST occurrence handles labels where an earlier AZ/EN section
    // also contains "Ingredients"/"Tarkibi" — we want the final Turkish block.
    final headerPatterns = [
      RegExp(r'[İi]çindekiler\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]ngredients\s*:?\s*', caseSensitive: false),
      RegExp(r'[Ii]çerik\s*:?\s*', caseSensitive: false),
    ];

    // Collect all header matches and pick the LAST one
    RegExpMatch? bestMatch;
    for (final pattern in headerPatterns) {
      for (final m in pattern.allMatches(result)) {
        if (bestMatch == null || m.start > bestMatch.start) {
          bestMatch = m;
        }
      }
    }
    if (bestMatch != null) {
      result = result.substring(bestMatch.end);
    }

    // Cut at section boundaries that follow the ingredients list.
    // Patterns use ASCII equivalents of Turkish chars because OCR output
    // may not contain correct UTF-8 Turkish characters.
    // We find the EARLIEST match across ALL patterns so the cut always
    // happens as early in the text as possible.
    final cutPatterns = <RegExp>[
      // Turkish label boundaries ────────────────────────────────────
      RegExp('Tavsiye Edilen', caseSensitive: false),        // TETT best-before marker
      RegExp('Tavsiye edilen', caseSensitive: false),
      RegExp(r'\bTETT\b'),                                    // TETT abbreviation
      RegExp('Parti No', caseSensitive: false),               // Lot/batch number
      RegExp('Parti no', caseSensitive: false),
      RegExp(r'Dikkat\s*!', caseSensitive: false),            // "Dikkat!" warning block
      RegExp('Muhafaza ediniz', caseSensitive: false),        // Storage instruction
      RegExp('muhafaza ediniz', caseSensitive: false),
      RegExp(r'Saklama\s+Ko', caseSensitive: false),          // Saklama koşulu
      RegExp('Buzdolab', caseSensitive: false),               // Refrigerator mention
      RegExp('Uretici Firma', caseSensitive: false),          // Manufacturer (ASCII)
      RegExp('Uretici:', caseSensitive: false),
      RegExp('Uretilmi', caseSensitive: false),               // "üretilmiştir" (ASCII)
      RegExp("Turkiye'de Uretil", caseSensitive: false),      // Made in Turkey (ASCII)
      RegExp("Turkiye'de uretil", caseSensitive: false),
      RegExp(r'Isletme\s+Kayit', caseSensitive: false),       // Business reg. no.
      RegExp(r'TS\s+\d{3,}', caseSensitive: false),          // Turkish standard no.
      RegExp(r'\bwww\.', caseSensitive: false),               // Website URL
      RegExp(r'Sinif\s*:', caseSensitive: false),             // Sınıf: classification
      RegExp('Son Tuketim', caseSensitive: false),            // Best-before
      RegExp('son tuketim', caseSensitive: false),
      // With Turkish chars (for when ML Kit does read them correctly) ─
      RegExp('Tavsiye Edilen Tüketim', caseSensitive: false),
      RegExp(r'Üretici\s+Firma', caseSensitive: false),
      RegExp(r'Üretici\s*:', caseSensitive: false),
      RegExp(r'Üretilmi', caseSensitive: false),
      RegExp(r'Saklama\s+Ko', caseSensitive: false),
      RegExp(r'Son\s+Tüketim', caseSensitive: false),
      RegExp(r'İşletme\s+Kay', caseSensitive: false),
      RegExp(r'Sınıf\s*:', caseSensitive: false),
      // English label boundaries ────────────────────────────────────
      RegExp(r'Besin\s+De', caseSensitive: false),            // Besin Değerleri
      RegExp('Nutrition Fact', caseSensitive: false),
      RegExp(r'Besin\s+Icerik', caseSensitive: false),
      RegExp('Storage', caseSensitive: false),
      RegExp('Best Before', caseSensitive: false),
      RegExp('Manufacture', caseSensitive: false),
      // Azerbaijani label boundaries ────────────────────────────────
      // Multi-market TR+AZ packages print both language sections.
      // These markers signal the start of the AZ block.
      RegExp('Tarkibi', caseSensitive: false),                 // AZ: composition/ingredients header
      RegExp('Istehsalci', caseSensitive: false),              // AZ: manufacturer (ASCII)
      RegExp('istehsalci', caseSensitive: false),
      RegExp(r'[İI]stehsal\s+\w+\s+v', caseSensitive: false), // AZ: "İstehsalçının adı və ünvanı"
      RegExp('Saxlanma', caseSensitive: false),                // AZ: storage conditions
      RegExp('saxlanma', caseSensitive: false),
      RegExp('Istifade', caseSensitive: false),                // AZ: use/consumption
      RegExp('Son istifade', caseSensitive: false),            // AZ: best before
      RegExp(r'\bAZ\b\s+[İI]stehsal', caseSensitive: false),  // "AZ İstehsalçının..."
      RegExp(r'\bAZ\s+[A-ZƏ]', caseSensitive: false),         // AZ country marker + content
      RegExp(r'\bAzərbaycan\b', caseSensitive: false),         // Country name
      RegExp('Azerbaycan', caseSensitive: false),              // Turkish spelling
    ];

    // Find the EARLIEST cut position across all patterns
    int? cutPos;
    for (final pattern in cutPatterns) {
      final match = pattern.firstMatch(result);
      if (match != null && (cutPos == null || match.start < cutPos)) {
        cutPos = match.start;
      }
    }
    if (cutPos != null) {
      result = result.substring(0, cutPos);
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
