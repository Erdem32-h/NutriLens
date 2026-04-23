import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'gemini_ai_service.dart';

/// ML Kit-based nutrition OCR service.
/// Falls back from Gemini when AI service is unavailable.
class NutritionMlkitService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract nutrition values from image using ML Kit OCR.
  /// Parses Turkish nutrition labels and returns structured data.
  Future<NutritionOcrResult?> extractFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) return null;

      return _parseNutritionTable(recognizedText.text);
    } catch (e) {
      debugPrint('[NutritionMlkit] extraction error: $e');
      return null;
    }
  }

  /// Parse nutrition table text and extract values.
  NutritionOcrResult? _parseNutritionTable(String text) {
    final lines = text.toLowerCase().split('\n');

    double? energyKcal;
    double? fat;
    double? saturatedFat;
    double? transFat;
    double? carbohydrates;
    double? sugars;
    double? salt;
    double? fiber;
    double? protein;

    // Patterns for Turkish nutrition labels
    // Energy: "Enerji", "kcal", "kJ" variants
    // Support both comma and period as decimal separator
    for (final line in lines) {
      final trimmedLine = line.trim();

      // Energy (kcal) - multiple patterns
      if (energyKcal == null) {
        final energyPatterns = [
          RegExp(
            r'en(?:erji|yji)?[\s:]*(\d+[.,]?\d*)\s*kcal',
            caseSensitive: false,
          ),
          RegExp(r'(\d+[.,]?\d*)\s*kcal', caseSensitive: false),
          RegExp(r'Enerji[\s:]*(\d+[.,]?\d*)', caseSensitive: false),
        ];
        for (final pattern in energyPatterns) {
          final match = pattern.firstMatch(trimmedLine);
          if (match != null) {
            energyKcal = _parseNumber(match.group(1)!);
            break;
          }
        }
      }

      // Fat - "Yağ", "Lipit"
      if (fat == null) {
        final match = RegExp(
          r'(?:ya[ğg]|lipit)[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          fat = _parseNumber(match.group(1)!);
        }
      }

      // Saturated Fat - "Doymuş", "Doymuş Yağ"
      if (saturatedFat == null) {
        final match = RegExp(
          r'(?:doymu[şs]|doymu[şs]\s*ya[ğg])[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          saturatedFat = _parseNumber(match.group(1)!);
        }
      }

      // Trans Fat - "Trans Yağ"
      if (transFat == null) {
        final match = RegExp(
          r'trans[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          transFat = _parseNumber(match.group(1)!);
        }
      }

      // Carbohydrates - "Karbonhidrat"
      if (carbohydrates == null) {
        final match = RegExp(
          r'(?:karbonhidrat|karb)[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          carbohydrates = _parseNumber(match.group(1)!);
        }
      }

      // Sugars - "Şeker", "Toplam Şeker"
      if (sugars == null) {
        final match = RegExp(
          r'(?:şeker|[\s:]*(?:toplam\s*)?şeker)[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          sugars = _parseNumber(match.group(1)!);
        }
      }

      // Salt - "Tuz"
      if (salt == null) {
        final match = RegExp(
          r'(?:tuz|sodyum)[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          salt = _parseNumber(match.group(1)!);
        }
      }

      // Fiber - "Lif", "Diyet Lif"
      if (fiber == null) {
        final match = RegExp(
          r'(?:lif|diyet\s*lif)[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          fiber = _parseNumber(match.group(1)!);
        }
      }

      // Protein - "Protein"
      if (protein == null) {
        final match = RegExp(
          r'protein[\s:]*(\d+[.,]?\d*)',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (match != null) {
          protein = _parseNumber(match.group(1)!);
        }
      }
    }

    // If we found any nutrition data, return it
    if (energyKcal != null ||
        fat != null ||
        carbohydrates != null ||
        protein != null) {
      return NutritionOcrResult(
        energyKcal: energyKcal,
        fat: fat,
        saturatedFat: saturatedFat,
        transFat: transFat,
        carbohydrates: carbohydrates,
        sugars: sugars,
        salt: salt,
        fiber: fiber,
        protein: protein,
      );
    }

    return null;
  }

  /// Parse number from string, handling both comma and period as decimal separator.
  double _parseNumber(String value) {
    // Replace comma with period for decimal handling
    final normalized = value.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
